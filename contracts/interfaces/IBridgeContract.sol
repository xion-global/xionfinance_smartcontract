// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.7.6;

interface IBridgeContract {
    function requireToPassMessage(
        address,
        bytes calldata,
        uint256
    ) external;

    function messageSender() external returns (address);
}
