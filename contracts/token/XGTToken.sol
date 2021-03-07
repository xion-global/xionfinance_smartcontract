pragma solidity ^0.5.16;

import "@openzeppelin/openzeppelin-contracts-upgradeable/contracts/math/SafeMath.sol";
import "@openzeppelin/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Mintable.sol";
import "@openzeppelin/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/openzeppelin-contracts-upgradeable/contracts/ownership/Ownable.sol";
import "../interfaces/IBridgeContract.sol";
import "../interfaces/IXGTTokenMainnet.sol";
import "../interfaces/IVesting.sol";

contract XGTToken is Initializable, Ownable, ERC20Detailed, ERC20Mintable {
    using SafeMath for uint256;

    address public subscriptionContract;
    address public mainnetContract;
    IBridgeContract public bridge;
    IVesting public vesting;

    // Total Token Supply
    uint256 public constant MAX_SUPPLY = 3000000000 * 10**18; // 3 billion

    // Specific supplies
    uint256 public constant ISSUE_RESERVE = 1200000000 * 10**18; // 1.2 billion
    uint256 public constant LIQUIDITY_POOL = 300000000 * 10**18; // 0.3 billion
    uint256 public constant XION_RESERVE = 600000000 * 10**18; // 0.6 billion
    uint256 public constant FOUNDERS_RESERVE = 450000000 * 10**18; // 0.45 billion
    uint256 public constant COMMUNITY_AND_AIRDROPS = 300000000 * 10**18; // 0.3 billion
    uint256 public constant TEAM_AND_ADVISORS = 150000000 * 10**18; // 0.15 billion

    mapping(uint256 => bool) public incomingTransferExecuted;
    uint256 public outgoingTransferNonce;

    function initializeToken(
        address _subscriptionContract,
        address _vestingContract,
        address[] memory _reserveAddresses,
        address[] memory _vestedAddressesFounders,
        uint256[] memory _vestedAmountsFounders,
        address[] memory _vestedAddressesTeam,
        uint256[] memory _vestedAmountsTeam,
        address[] memory _vestedAddressesCommunity,
        uint256[] memory _vestedAmountsCommunity
    ) public {
        require(subscriptionContract == address(0), "XGT-ALREADY-INITIALIZED");
        _transferOwnership(msg.sender);
        subscriptionContract = _subscriptionContract;

        // General token utility allocations
        _mint(_reserveAddresses[0], ISSUE_RESERVE);
        _mint(_reserveAddresses[1], LIQUIDITY_POOL);

        // Specific allocations subject to vesting
        // of 24 months, where 1/24th becomes available each month
        vesting = IVesting(_vestingContract);
        _mint(address(vesting), XION_RESERVE);
        _mint(address(vesting), FOUNDERS_RESERVE);
        _mint(address(vesting), COMMUNITY_AND_AIRDROPS);
        _mint(address(vesting), TEAM_AND_ADVISORS);

        uint256 index = 4;
        address[] memory beneficiaries =
            new address[](
                _vestedAddressesFounders
                    .length
                    .add(_vestedAddressesTeam.length)
                    .add(_vestedAddressesCommunity.length)
                    .add(1)
            );

        beneficiaries[0] = _reserveAddresses[2];
        beneficiaries[1] = _vestedAddressesFounders[0];
        beneficiaries[2] = _vestedAddressesFounders[1];
        beneficiaries[3] = _vestedAddressesFounders[2];

        uint256 undistributedTeam = TEAM_AND_ADVISORS;
        for (uint256 i = 0; i < _vestedAddressesTeam.length; i++) {
            undistributedTeam = undistributedTeam.sub(_vestedAmountsTeam[i]);
            beneficiaries[index + i] = _vestedAddressesTeam[i];
        }
        index = index + _vestedAddressesTeam.length;

        uint256 undistributedCommunity = COMMUNITY_AND_AIRDROPS;
        for (uint256 i = 0; i < _vestedAddressesCommunity.length; i++) {
            undistributedCommunity = undistributedCommunity.sub(
                _vestedAmountsCommunity[i]
            );
            beneficiaries[index + i] = _vestedAddressesCommunity[i];
        }
        index = index + _vestedAddressesCommunity.length;

        require(
            vesting.initializeVesting(
                address(this),
                beneficiaries,
                XION_RESERVE,
                _vestedAmountsFounders,
                _vestedAmountsTeam,
                _vestedAmountsCommunity,
                undistributedTeam,
                undistributedCommunity,
                msg.sender
            ),
            "XGT-FAILED-TO-INIT-VESTING-CONTRACT"
        );
    }

    function setMainnetContract(address _mainnetContract) external onlyOwner {
        mainnetContract = _mainnetContract;
    }

    function setBridge(address _address) external onlyOwner {
        bridge = IBridgeContract(_address);
    }

    function transferredToXDai(
        address _user,
        uint256 _amount,
        uint256 _nonce
    ) external {
        require(msg.sender == address(bridge), "XGT-NOT-BRIDGE");
        require(
            bridge.messageSender() == mainnetContract,
            "XGT-NOT-XDAI-CONTRACT"
        );
        require(!incomingTransferExecuted[_nonce], "XGT-ALREADY-EXECUTED");
        incomingTransferExecuted[_nonce] = true;
        _transfer(address(this), _user, _amount);
    }

    function transferToMainnet(uint256 _amount) external {
        _transfer(msg.sender, address(this), _amount);
        bytes4 _methodSelector =
            IXGTTokenMainnet(address(0)).transferredToMainnet.selector;
        bytes memory data =
            abi.encodeWithSelector(
                _methodSelector,
                msg.sender,
                _amount,
                outgoingTransferNonce++
            );
        bridge.requireToPassMessage(mainnetContract, data, 500000);
    }

    // Safety override
    function transfer(address recipient, uint256 amount) public returns (bool) {
        require(recipient != address(this), "XGT-CANT-TRANSFER-TO-CONTRACT");
        return super.transfer(recipient, amount);
    }

    // Safety override
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public returns (bool) {
        require(recipient != address(this), "XGT-CANT-TRANSFER-TO-CONTRACT");
        return super.transferFrom(sender, recipient, amount);
    }
}
