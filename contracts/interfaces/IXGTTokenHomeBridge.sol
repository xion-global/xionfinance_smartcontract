// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.7.6;

interface IXGTTokenHomeBridge {
    function outgoingTransfer(uint256 _amount) external;

    function outgoingTransfer(uint256 _amount, address _recipient) external;
}
