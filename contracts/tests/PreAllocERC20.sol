pragma solidity ^0.5.16;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Mintable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/upgrades/contracts/ownership/Ownable.sol";

contract PreAllocERC20 is
    Initializable,
    OpenZeppelinUpgradesOwnable,
    ERC20Detailed,
    ERC20Mintable
{
    using SafeMath for uint256;

    function initializeToken(address _address) public initializer {
        ERC20Detailed.initialize("XionGlobal Test Token", "XGTest", 18);
        _mint(_address, 1000000 * 1000000000000000000);
    }
}
