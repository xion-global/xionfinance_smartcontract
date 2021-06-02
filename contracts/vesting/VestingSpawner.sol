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
    mapping(address => address) public vestingContracts;

    uint256 public reserveTokensLeft;
    uint256 public foundersTokensLeft;
    uint256 public teamTokensLeft;
    uint256 public communityTokensLeft;

    event VestingContractSpawned(
        address indexed recipient,
        uint256 amount,
        uint256 startDate,
        uint256 epochsCliff,
        uint256 epochsVesting
    );

    constructor(address xgtToken, address vestingImplementation) {
        xgt = IERC20(xgtToken);
        implementation = vestingImplementation;
    }

    function fundSpawner(uint256 _allocation, uint256 _amount) external {
        require(
            _allocation >= 1 && _allocation <= 4,
            "VESTING-SPAWNER-INVALID-ALLOCATION"
        );
        require(
            xgt.transferFrom(msg.sender, address(this), _amount),
            "VESTING-SPAWNER-TRANSFER-FAILED"
        );
        if (_allocation == 1) {
            reserveTokensLeft = reserveTokensLeft.add(_amount);
        } else if (_allocation == 2) {
            foundersTokensLeft = foundersTokensLeft.add(_amount);
        } else if (_allocation == 3) {
            teamTokensLeft = teamTokensLeft.add(_amount);
        } else if (_allocation == 4) {
            communityTokensLeft = communityTokensLeft.add(_amount);
        }
    }

    function spawnVestingContract(
        address _recipient,
        uint256 _amount,
        uint256 _startTime,
        uint256 _epochsCliff,
        uint256 _epochsVesting,
        uint256 _allocation
    ) external onlyOwner {
        require(
            vestingContracts[_recipient] == address(0),
            "VESTING-SPAWNER-RECIPIENT-ALREADY-EXISTS"
        );

        require(
            _allocation >= 1 && _allocation <= 4,
            "VESTING-SPAWNER-INVALID-ALLOCATION"
        );

        require(
            _startTime >= 1623974400,
            "VESTING-SPAWNER-START-TIME-TOO-EARLY"
        );

        if (_allocation == 1) {
            require(
                _epochsVesting >= 24,
                "VESTING-SPAWNER-VESTING-DURATION-TOO-SHORT"
            );
            reserveTokensLeft = reserveTokensLeft.sub(_amount);
        } else if (_allocation == 2) {
            require(
                _epochsVesting >= 48 && _epochsCliff >= 6,
                "VESTING-SPAWNER-VESTING-DURATION-TOO-SHORT"
            );
            foundersTokensLeft = foundersTokensLeft.sub(_amount);
        } else if (_allocation == 3) {
            require(
                _epochsVesting >= 48 && _epochsCliff >= 6,
                "VESTING-SPAWNER-VESTING-DURATION-TOO-SHORT"
            );
            teamTokensLeft = teamTokensLeft.sub(_amount);
        } else if (_allocation == 4) {
            require(
                _epochsVesting >= 48 && _epochsCliff >= 6,
                "VESTING-SPAWNER-VESTING-DURATION-TOO-SHORT"
            );
            communityTokensLeft = communityTokensLeft.sub(_amount);
        }

        address newVestingContract = Clones.clone(implementation);
        vestingContracts[_recipient] = newVestingContract;
        xgt.transfer(newVestingContract, _amount);
        Vesting(newVestingContract).initialize(
            _recipient,
            address(xgt),
            _startTime,
            _epochsCliff,
            _epochsVesting,
            _amount
        );
        emit VestingContractSpawned(
            _recipient,
            _amount,
            _startTime,
            _epochsCliff,
            _epochsVesting
        );
    }
}
