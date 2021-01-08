pragma solidity ^0.5.16;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Mintable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/upgrades/contracts/ownership/Ownable.sol";
import "../interfaces/IBridgeContract.sol";
import "../interfaces/IXGTTokenMainnet.sol";
import "../interfaces/IVesting.sol";

contract XGTToken is
    Initializable,
    OpenZeppelinUpgradesOwnable,
    ERC20Detailed,
    ERC20Mintable
{
    using SafeMath for uint256;

    address public subscriptionContract;
    address public mainnetContract;
    IBridgeContract public bridge;
    IVesting public vesting;

    // Total Token Supply
    uint256 public constant MAX_SUPPLY = 3000000000; // 3 billion

    // Specific supplies
    uint256 public constant ISSUE_RESERVE = 1200000000; // 1.2 billion
    uint256 public constant LIQUIDITY_POOL = 300000000; // 0.3 billion
    uint256 public constant XION_RESERVE = 600000000; // 0.6 billion
    uint256 public constant FOUNDERS_RESERVE = 450000000; // 0.45 billion
    uint256 public constant COMMUNITY_AND_AIRDROPS = 300000000; // 0.3 billion
    uint256 public constant TEAM_AND_ADVISORS = 150000000; // 0.15 billion

    function initialize(
        address _subscriptionContract,
        address _vestingContract,
        address[] memory _reserveAddresses,
        address[] memory _teamAddresses,
        uint256[] memory _teamAmounts
    ) public initializer {
        ERC20Detailed.initialize("XionGlobal Token", "XGT", 18);
        subscriptionContract = _subscriptionContract;
        vesting = IVesting(_vestingContract);

        // General allocations
        _mint(_reserveAddresses[0], ISSUE_RESERVE);
        _mint(_reserveAddresses[1], LIQUIDITY_POOL);
        _mint(_reserveAddresses[2], XION_RESERVE);
        _mint(_reserveAddresses[3], FOUNDERS_RESERVE);
        _mint(_reserveAddresses[4], COMMUNITY_AND_AIRDROPS);

        // Mint & transfer vested team and advisor tokens
        require(
            _teamAddresses.length == _teamAmounts.length,
            "XGT-ARRAY-LENGTH-DONT-MATCH"
        );

        uint256 teamSum = 0;
        for (uint256 i = 0; i < _teamAddresses.length; i++) {
            teamSum = teamSum.add(_teamAmounts[i]);
        }
        require(teamSum == TEAM_AND_ADVISORS, "XGT-TEAM-SUM-DOESNT-MATCH");

        _mint(address(vesting), TEAM_AND_ADVISORS);

        require(
            vesting.initialize(address(this), _teamAddresses, _teamAmounts),
            "XGT-FAILED-TO-INIT-VESTING-CONTRACT"
        );
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

    function usedXGT(address _user, uint256 _amount) external returns (bool) {
        require(
            msg.sender == subscriptionContract,
            "XGT-NOT-SUBSCRIPTION-CONTRACT"
        );
        _burn(_user, _amount);
    }

    function transferredToXDai(address _user, uint256 _amount) external {
        require(msg.sender == address(bridge), "XGT-NOT-BRIDGE");
        require(
            bridge.messageSender() == mainnetContract,
            "XGT-NOT-XDAI-CONTRACT"
        );
        _transfer(address(this), _user, _amount);
    }

    function transferToMainnet(uint256 _amount) external {
        _transfer(msg.sender, address(this), _amount);
        bytes4 _methodSelector =
            IXGTTokenMainnet(address(0)).transferredToMainnet.selector;
        bytes memory data =
            abi.encodeWithSelector(_methodSelector, msg.sender, _amount);
        bridge.requireToPassMessage(mainnetContract, data, 300000);
    }
}
