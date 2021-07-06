// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../interfaces/IBridgeContract.sol";
import "../interfaces/IXGTTokenBridge.sol";

contract XGTTokenHomeBridge is Ownable, ReentrancyGuard, Pausable {
    using SafeMath for uint256;

    address public homeToken;
    address public outpostToken;
    uint256 public outpostNetworkID;
    IBridgeContract public messageBridge;
    uint256 public crossChainCallGas = 300000;

    mapping(uint256 => bool) public incomingTransferExecuted;
    uint256 public outgoingTransferNonce;

    event BridgeAddressChanged(
        address newMessageBridgeAddress,
        address performer
    );
    event IncomingTransfer(
        address indexed recipient,
        uint256 amount,
        uint256 nonce
    );
    event OutgoingTransfer(
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        uint256 nonce
    );

    constructor(
        address _homeToken,
        address _outpostToken,
        uint256 _outpostNetworkID,
        address _messageBridge,
        address _multiSig
    ) {
        require(_homeToken != address(0), "XGT-INVALID-HOME-TOKEN-ADDRESS");
        require(
            _outpostToken != address(0),
            "XGT-INVALID-OUTPOST-TOKEN-ADDRESS"
        );
        require(
            _messageBridge != address(0),
            "XGT-INVALID-MESSAGE-BRIDGE-ADDRESS"
        );
        homeToken = _homeToken;
        outpostToken = _outpostToken;
        outpostNetworkID = _outpostNetworkID;
        messageBridge = IBridgeContract(_messageBridge);
        emit BridgeAddressChanged(_messageBridge, msg.sender);
        transferOwnership(_multiSig);
    }

    function changeMessageBridge(address _newMessageBridge) external onlyOwner {
        messageBridge = IBridgeContract(_newMessageBridge);
        emit BridgeAddressChanged(_newMessageBridge, msg.sender);
    }

    function setCrossChainGas(uint256 _gasAmount) external onlyOwner {
        crossChainCallGas = _gasAmount;
    }

    function incomingTransfer(
        address _user,
        uint256 _amount,
        uint256 _nonce
    ) external nonReentrant {
        require(msg.sender == address(messageBridge), "XGT-NOT-BRIDGE");
        require(
            messageBridge.messageSender() == homeToken,
            "XGT-NOT-HOME-TOKEN"
        );
        require(!incomingTransferExecuted[_nonce], "XGT-ALREADY-EXECUTED");
        incomingTransferExecuted[_nonce] = true;
        IERC20(homeToken).transfer(_user, _amount);
        emit IncomingTransfer(_user, _amount, _nonce);
    }

    function outgoingTransfer(uint256 _amount)
        external
        nonReentrant
        whenNotPaused
    {
        outgoingTransfer(_amount, msg.sender);
    }

    function outgoingTransfer(uint256 _amount, address _recipient)
        public
        nonReentrant
        whenNotPaused
    {
        IERC20(homeToken).transferFrom(msg.sender, address(this), _amount);
        bytes4 _methodSelector =
            IXGTTokenBridge(address(0)).incomingTransfer.selector;
        bytes memory data =
            abi.encodeWithSelector(
                _methodSelector,
                _recipient,
                _amount,
                outgoingTransferNonce++
            );
        messageBridge.requireToPassMessage(
            outpostToken,
            data,
            crossChainCallGas
        );
        emit OutgoingTransfer(
            msg.sender,
            _recipient,
            _amount,
            outgoingTransferNonce
        );
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
