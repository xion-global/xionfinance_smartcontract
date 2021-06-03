// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.7.6;

interface IRewardModule {
    function claimModule(address _user) external;

    function getClaimable(address _user) external view returns (uint256);
}
