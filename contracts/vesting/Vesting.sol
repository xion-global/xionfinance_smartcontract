// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Vesting is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    uint256 public startTime;
    uint256 public epochDuration;
    uint256 public epochsCliff;
    uint256 public epochsVesting;

    IERC20 private xgt;

    uint256 public lastClaimedEpoch;
    uint256 public totalDistributedBalance;

    function initialize(
        address _recipient,
        address _xgtTokenAddress,
        uint256 _startTime,
        uint256 _epochDuration,
        uint256 _epochsCliff,
        uint256 _epochsVesting,
        uint256 _totalBalance
    ) external {
        require(address(xgt) == address(0), "VESTING-ALREADY-INITIALIZED");
        transferOwnership(_recipient);
        xgt = IERC20(_xgtTokenAddress);
        startTime = _startTime;
        epochDuration = _epochDuration;
        epochsCliff = _epochsCliff;
        epochsVesting = _epochsVesting;
        totalDistributedBalance = _totalBalance;
        require(
            totalDistributedBalance == xgt.balanceOf(address(this)),
            "VESTING-INVALID-BALANCE"
        );
    }

    function claim() public nonReentrant {
        uint256 claimBalance;
        uint256 currentEpoch = getCurrentEpoch();

        // this triggers a revert if we are not past the cliff and prohibits claims until then
        currentEpoch = currentEpoch.sub(epochsCliff);

        if (currentEpoch > epochsCliff + epochsVesting + 1) {
            lastClaimedEpoch = epochsCliff + epochsVesting;
            require(
                xgt.transfer(owner(), xgt.balanceOf(address(this))),
                "VESTING-TRANSFER-FAILED"
            );
            return;
        }

        if (currentEpoch > lastClaimedEpoch) {
            claimBalance =
                ((currentEpoch - 1 - lastClaimedEpoch) *
                    totalDistributedBalance) /
                epochsVesting;
        }
        lastClaimedEpoch = currentEpoch - 1;
        if (claimBalance > 0) {
            require(
                xgt.transfer(owner(), claimBalance),
                "VESTING-TRASNFER-FAILED"
            );
        }
    }

    function balance() public view returns (uint256) {
        return xgt.balanceOf(address(this));
    }

    function getCurrentEpoch() public view returns (uint256) {
        if (block.timestamp < startTime) return 0;
        return (block.timestamp - startTime) / epochDuration + 1;
    }
}
