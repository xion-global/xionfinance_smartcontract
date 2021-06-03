// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.7.6;

interface IRewardChest {
    function addToBalance(address _user, uint256 _amount)
        external
        returns (bool);

    function owner() external view returns (address);
}
