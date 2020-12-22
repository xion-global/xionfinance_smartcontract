pragma solidity ^0.5.16;

interface IXGTStakeXDai {
    function tokensDeposited(uint256 _amount, address _user) external;
    function tokensWithdrawn(uint256 _amount, address _user) external;
    function claimXGT(address _user) external;
}