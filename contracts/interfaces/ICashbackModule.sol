// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.7.6;

interface ICashbackModule {
    function addCashbacks(address[] calldata _recipients, uint256 _amount)
        external;
}
