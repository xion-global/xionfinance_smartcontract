// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.7.6;

interface IXGTTokenBridge {
    function incomingTransfer(
        address _user,
        uint256 _amount,
        uint256 _nonce
    ) external;

    function outgoingTransfer(uint256 _amount) external;

    function outgoingTransfer(uint256 _amount, address _recipient) external;
}
