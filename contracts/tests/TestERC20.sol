pragma solidity ^0.5.16;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Mintable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/upgrades/contracts/ownership/Ownable.sol";
import "../interfaces/IVesting.sol";

contract TestERC20 is
    Initializable,
    OpenZeppelinUpgradesOwnable,
    ERC20Detailed,
    ERC20Mintable
{
    using SafeMath for uint256;

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

    function initializeToken(
        address _vestingContract,
        address[] memory _reserveAddresses,
        address[] memory _vestedAddressesFounders,
        uint256[] memory _vestedAmountsFounders,
        address[] memory _vestedAddressesTeam,
        uint256[] memory _vestedAmountsTeam,
        address[] memory _vestedAddressesCommunity,
        uint256[] memory _vestedAmountsCommunity
    ) public initializer {
        ERC20Detailed.initialize("XionGlobal Token", "XGT", 18);

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
}
