// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./Vesting.sol";

contract VestingSpawner is Ownable {
    using SafeMath for uint256;

    IERC20 public xgt;
    address public implementation;
    mapping(address => address) public vestingContractOfRecipient;
    address[] public vestingContracts;

    uint256 public constant EPOCH_DURATION_WEEK = 24 * 60 * 60 * 7;
    uint256 public constant EPOCH_DURATION_MONTH = (365 * 24 * 60 * 60) / 12;

    uint256 public constant MINIMUM_CLIFF_EPOCHS_TEAM =
        EPOCH_DURATION_MONTH * 6;
    uint256 public constant MINIMUM_VESTING_EPOCHS_TEAM =
        EPOCH_DURATION_MONTH * 48;

    enum Allocation {Reserve, Founders, Team, Community, MarketMaking}

    uint256 public reserveTokensLeft;
    uint256 public foundersTokensLeft;
    uint256 public teamTokensLeft;
    uint256 public communityTokensLeft;
    uint256 public marketMakingTokensLeft;

    event VestingContractSpawned(
        address indexed recipient,
        uint256 amount,
        uint256 startDate,
        uint256 epochDuration,
        uint256 epochsCliff,
        uint256 epochsVesting
    );

    constructor(
        address _vestingImplementation,
        address _token,
        address _multiSig
    ) {
        implementation = _vestingImplementation;
        xgt = IERC20(_token);
        transferOwnership(_multiSig);
    }

    function fundSpawner(uint256 _allocation, uint256 _amount) external {
        require(
            _allocation >= 0 && _allocation <= 4,
            "VESTING-SPAWNER-INVALID-ALLOCATION"
        );

        require(
            xgt.transferFrom(msg.sender, address(this), _amount),
            "VESTING-SPAWNER-TRANSFER-FAILED"
        );

        if (Allocation(_allocation) == Allocation.Reserve) {
            reserveTokensLeft = reserveTokensLeft.add(_amount);
        } else if (Allocation(_allocation) == Allocation.Founders) {
            foundersTokensLeft = foundersTokensLeft.add(_amount);
        } else if (Allocation(_allocation) == Allocation.Team) {
            teamTokensLeft = teamTokensLeft.add(_amount);
        } else if (Allocation(_allocation) == Allocation.Community) {
            communityTokensLeft = communityTokensLeft.add(_amount);
        } else if (Allocation(_allocation) == Allocation.MarketMaking) {
            marketMakingTokensLeft = marketMakingTokensLeft.add(_amount);
        }
    }

    function spawnVestingContract(
        address _recipient,
        uint256 _amount,
        uint256 _startTime,
        uint256 _epochDuration,
        uint256 _epochsCliff,
        uint256 _epochsVesting,
        uint256 _allocation
    ) external onlyOwner {
        require(
            vestingContractOfRecipient[_recipient] == address(0),
            "VESTING-SPAWNER-RECIPIENT-ALREADY-EXISTS"
        );

        require(
            _epochDuration == EPOCH_DURATION_WEEK ||
                _epochDuration == EPOCH_DURATION_MONTH,
            "VESTING-SPAWNER-INVALID-EPOCH-DURATION"
        );

        require(
            _allocation >= 0 && _allocation <= 3,
            "VESTING-SPAWNER-INVALID-ALLOCATION"
        );

        require(
            _startTime >= 1623974400,
            "VESTING-SPAWNER-START-TIME-TOO-EARLY"
        );

        if (Allocation(_allocation) == Allocation.Reserve) {
            reserveTokensLeft = reserveTokensLeft.sub(_amount);
        } else if (Allocation(_allocation) == Allocation.Founders) {
            require(
                _epochsVesting.mul(_epochDuration) >=
                    MINIMUM_VESTING_EPOCHS_TEAM &&
                    _epochsCliff.mul(_epochDuration) >=
                    MINIMUM_CLIFF_EPOCHS_TEAM,
                "VESTING-SPAWNER-VESTING-DURATION-TOO-SHORT"
            );
            foundersTokensLeft = foundersTokensLeft.sub(_amount);
        } else if (Allocation(_allocation) == Allocation.Team) {
            require(
                _epochsVesting.mul(_epochDuration) >=
                    MINIMUM_VESTING_EPOCHS_TEAM &&
                    _epochsCliff.mul(_epochDuration) >=
                    MINIMUM_CLIFF_EPOCHS_TEAM,
                "VESTING-SPAWNER-VESTING-DURATION-TOO-SHORT"
            );
            teamTokensLeft = teamTokensLeft.sub(_amount);
        } else if (Allocation(_allocation) == Allocation.Community) {
            communityTokensLeft = communityTokensLeft.sub(_amount);
        } else if (Allocation(_allocation) == Allocation.MarketMaking) {
            marketMakingTokensLeft = marketMakingTokensLeft.sub(_amount);
        }

        address newVestingContract = Clones.clone(implementation);
        vestingContractOfRecipient[_recipient] = newVestingContract;
        vestingContracts.push(newVestingContract);

        // Special Case for IDO where 50% is paid out instantly
        // and the rest is vested for 2 weeks
        bool frontHalf = false;
        if (
            _allocation == 0 &&
            _epochDuration == EPOCH_DURATION_WEEK &&
            _epochsVesting == 2 &&
            _epochsCliff == 1
        ) {
            frontHalf = true;
        }

        require(
            xgt.transfer(newVestingContract, _amount),
            "VESTING-SPAWNER-TRANSFER-FAILED"
        );
        Vesting(newVestingContract).initialize(
            _recipient,
            address(xgt),
            _startTime,
            _epochDuration,
            _epochsCliff,
            _epochsVesting,
            _amount,
            frontHalf
        );
        emit VestingContractSpawned(
            _recipient,
            _amount,
            _startTime,
            _epochDuration,
            _epochsCliff,
            _epochsVesting
        );
    }

    function multiClaim(uint256 _from, uint256 _to) external {
        if (_to == 0) {
            _to = vestingContracts.length - 1;
        }
        for (uint256 i = _from; i <= _to; i++) {
            if (Vesting(vestingContracts[i]).hasClaim()) {
                Vesting(vestingContracts[i]).claim();
            }
        }
    }

    function checkForClaims(uint256 _from, uint256 _to)
        external
        view
        returns (bool)
    {
        if (_to == 0) {
            _to = vestingContracts.length - 1;
        }
        for (uint256 i = _from; i <= _to; i++) {
            if (Vesting(vestingContracts[i]).hasClaim()) {
                return true;
            }
        }
        return false;
    }
}
