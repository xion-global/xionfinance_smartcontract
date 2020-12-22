pragma solidity ^0.5.16;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Mintable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/upgrades/contracts/ownership/Ownable.sol";
import "../interfaces/IBridgeContract.sol";
import "../interfaces/IXGTTokenMainnet.sol";

contract XGTToken is Initializable, OpenZeppelinUpgradesOwnable, ERC20Detailed, ERC20Mintable {
    using SafeMath for uint256;

    address public subscriptionContract;
    address public mainnetContract;
    IBridgeContract public bridge;

    function initialize(address _subscriptionContract) public initializer {
        ERC20Detailed.initialize("XionGlobal Token", "XGT", 18);
        subscriptionContract = _subscriptionContract;
    }

    function setMainnetContract(address _mainnetContract) external onlyOwner {
        mainnetContract = _mainnetContract;
    }
    function addMinter(address _address) public onlyOwner {
        _addMinter(_address);
    }

    function removeMinter(address _address) public onlyOwner {
        _removeMinter(_address);
    }

    function usedXGT(address _user, uint256 _amount) external returns (bool){
        require(msg.sender == subscriptionContract, "XGT-NOT-SUBSCRIPTION-CONTRACT");
        _burn(_user, _amount);
    }

    function transferredToXDai(address _user, uint256 _amount) external {
        require(msg.sender == address(bridge), "XGT-NOT-BRIDGE");
        require(bridge.messageSender() == mainnetContract, "XGT-NOT-XDAI-CONTRACT");
        _transfer(address(this), _user, _amount);
    }

    function transferToMainnet(uint256 _amount) external {
        _transfer(msg.sender, address(this), _amount);
        bytes4 _methodSelector = IXGTTokenMainnet(address(0)).transferredToMainnet.selector;
        bytes memory data = abi.encodeWithSelector(_methodSelector, msg.sender, _amount);
        bridge.requireToPassMessage(mainnetContract,data,300000);
    }

}