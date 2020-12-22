pragma solidity >=0.5.13;

import '../XGTLPERC20.sol';

contract ERC20 is XGTLPERC20 {
    constructor(uint _totalSupply) public {
        _mint(msg.sender, _totalSupply);
    }
}
