// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IBridgeContract.sol";
import "../interfaces/IXGTToken.sol";

contract XGTTokenMainnet is Ownable, ERC20Burnable {
    using SafeMath for uint256;

    address public mainContract;
    IBridgeContract public bridge;

    mapping(uint256 => bool) public incomingTransferExecuted;
    uint256 public outgoingTransferNonce;

    constructor(address _mainContract, address _bridge) {
        require(
            _mainContract != address(0),
            "XGT-INVALID-MAIN-CONTRACT-ADDRESS"
        );
        require(_bridge != address(0), "XGT-INVALID-BRIDGE-ADDRESS");
        mainContract = _bridge;
        bridge = IBridgeContract(_bridge);
    }

    function setBridge(address _address) external onlyOwner {
        bridge = IBridgeContract(_address);
    }

    function incomingTransfer(
        address _user,
        uint256 _amount,
        uint256 _nonce
    ) external {
        require(msg.sender == address(bridge), "XGT-NOT-BRIDGE");
        require(
            bridge.messageSender() == mainContract,
            "XGT-NOT-XDAI-CONTRACT"
        );
        require(!incomingTransferExecuted[_nonce], "XGT-ALREADY-EXECUTED");
        incomingTransferExecuted[_nonce] = true;
        _mint(_user, _amount);
    }

    function transferBackToXDai(uint256 _amount) external {
        _burn(msg.sender, _amount);
        bytes4 _methodSelector =
            IXGTToken(address(0)).transferredToXDai.selector;
        bytes memory data =
            abi.encodeWithSelector(
                _methodSelector,
                msg.sender,
                _amount,
                outgoingTransferNonce++
            );
        bridge.requireToPassMessage(xDaiContract, data, 300000);
    }

    // Safety override
    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        require(recipient != address(this), "XGT-CANT-TRANSFER-TO-CONTRACT");
        return super.transfer(recipient, amount);
    }

    // Safety override
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        require(recipient != address(this), "XGT-CANT-TRANSFER-TO-CONTRACT");
        return super.transferFrom(sender, recipient, amount);
    }
}
