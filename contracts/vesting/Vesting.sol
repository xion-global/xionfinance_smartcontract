// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/IUniswapFactory.sol";

contract Vesting is ReentrancyGuard {
    using SafeMath for uint256;

    address public recipient;

    uint256 public startTime;
    uint256 public epochDuration;
    uint256 public epochsCliff;
    uint256 public epochsVesting;

    IERC20 public xgt;
    address public listingFactory;

    uint256 public lastClaimedEpoch;
    uint256 public totalDistributedBalance;
    bool public frontHalf;

    function initialize(
        address _recipient,
        address _xgtTokenAddress,
        uint256 _startTime,
        uint256 _epochDuration,
        uint256 _epochsCliff,
        uint256 _epochsVesting,
        uint256 _totalBalance,
        bool _frontHalf
    ) external {
        require(address(xgt) == address(0), "VESTING-ALREADY-INITIALIZED");
        recipient = _recipient;
        xgt = IERC20(_xgtTokenAddress);
        startTime = _startTime;
        epochDuration = _epochDuration;
        epochsCliff = _epochsCliff;
        epochsVesting = _epochsVesting;
        totalDistributedBalance = _totalBalance;
        frontHalf = _frontHalf;
        require(
            totalDistributedBalance == xgt.balanceOf(address(this)),
            "VESTING-INVALID-BALANCE"
        );
    }

    function claim() public nonReentrant {
        // For IDO investors this is set to true because of their unique vesting schedule
        if (frontHalf) {
            require(block.timestamp >= startTime, "VESTING-NOT-STARTED-YET");
            require(
                tokenHasBeenListed(),
                "VESTING-INITIAL-PAIR-NOT-DEPLOYED-YET"
            );
            uint256 halfBalance = totalDistributedBalance.div(2);
            require(
                xgt.transfer(recipient, halfBalance),
                "VESTING-TRANSFER-FAILED"
            );
            totalDistributedBalance = totalDistributedBalance.sub(halfBalance);
            frontHalf = false;
            return;
        }

        uint256 claimBalance;
        uint256 currentEpoch = getCurrentEpoch();

        require(currentEpoch > epochsCliff, "VESTING-CLIFF-NOT-OVER-YET");
        currentEpoch = currentEpoch.sub(epochsCliff);

        if (currentEpoch >= epochsVesting) {
            lastClaimedEpoch = epochsVesting;
            require(
                xgt.transfer(recipient, xgt.balanceOf(address(this))),
                "VESTING-TRANSFER-FAILED"
            );
            return;
        }

        if (currentEpoch > lastClaimedEpoch) {
            claimBalance =
                ((currentEpoch - lastClaimedEpoch) * totalDistributedBalance) /
                epochsVesting;
        }
        lastClaimedEpoch = currentEpoch;
        if (claimBalance > 0) {
            require(
                xgt.transfer(recipient, claimBalance),
                "VESTING-TRASNFER-FAILED"
            );
        }
    }

    function balance() external view returns (uint256) {
        return xgt.balanceOf(address(this));
    }

    function getCurrentEpoch() public view returns (uint256) {
        if (block.timestamp < startTime) return 0;
        return (block.timestamp - startTime) / epochDuration + 1;
    }

    function hasClaim() external view returns (bool) {
        // For IDO investors this is set to true because of their unique vesting schedule
        if (frontHalf) {
            if (block.timestamp < startTime || !tokenHasBeenListed()) {
                return false;
            }
            return true;
        }

        uint256 currentEpoch = getCurrentEpoch();
        if (currentEpoch <= epochsCliff) {
            return false;
        }
        currentEpoch = currentEpoch.sub(epochsCliff);

        if (currentEpoch >= epochsVesting) {
            return true;
        }

        if (currentEpoch > lastClaimedEpoch) {
            uint256 claimBalance =
                ((currentEpoch - lastClaimedEpoch) * totalDistributedBalance) /
                    epochsVesting;
            if (claimBalance > 0) {
                return true;
            }
        }

        return false;
    }

    // function which determines whether a certain pair has been listed
    // and funded on a uniswap-v2-based dex. This is to ensure for the
    // public sale distribution to only happen after this is the case
    function tokenHasBeenListed() public view returns (bool) {
        IUniswapV2Factory exchangeFactory =
            IUniswapV2Factory(0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73);
        address wBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
        address pair = exchangeFactory.getPair(address(xgt), wBNB);
        // if the factory returns the 0-address, it hasn't been created
        if (pair == address(0)) {
            return false;
        }
        // if it was created, only return true if the xgt balance is
        // greater than zero == has been funded
        if (xgt.balanceOf(pair) > 0) {
            return true;
        }
        return false;
    }
}
