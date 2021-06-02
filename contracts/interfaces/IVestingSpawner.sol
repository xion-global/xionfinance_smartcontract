// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.7.6;

interface IVestingSpawner {
    function fundSpawner(uint256 _allocation, uint256 _amount) external;
}
