pragma solidity ^0.5.16;

interface IVesting {
    function initialize(
        address _tokenContract,
        address[] calldata _beneficiaries,
        uint256[] calldata _amounts
    ) external returns (bool);
}
