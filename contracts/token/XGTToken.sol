// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";

contract XGTToken is ERC20Burnable {
    using SafeMath for uint256;

    // Total Token Supply
    uint256 public constant MAX_SUPPLY = 1000000000 * 10**18; // 1 billion

    // Specific supplies
    uint256 public constant ISSUE_RESERVE = 450000000 * 10**18; // 450 million
    uint256 public constant XION_RESERVE = 200000000 * 10**18; // 200 million
    uint256 public constant FOUNDERS_RESERVE = 150000000 * 10**18; // 150 million
    uint256 public constant COMMUNITY_AND_AIRDROPS = 100000000 * 10**18; // 100 million
    uint256 public constant TEAM_AND_ADVISORS = 50000000 * 10**18; // 50 million
    uint256 public constant MARKET_MAKING = 50000000 * 10**18; // 50 million

    constructor(
        address _vestingContract,
        address[] memory _reserveAddresses,
        address[] memory _vestedAddressesFounders,
        // uint256[] memory _vestedAmountsFounders,
        address[] memory _vestedAddressesTeam,
        uint256[] memory _vestedAmountsTeam,
        address[] memory _vestedAddressesCommunity,
        uint256[] memory _vestedAmountsCommunity
    ) ERC20("Xion Global Token", "XGT") {
        require(_vestingContract != address(0), "XGT-INVALID-VESTING-ADDRESS");

        // General token utility allocations
        _mint(_reserveAddresses[0], ISSUE_RESERVE);
        _mint(_reserveAddresses[1], MARKET_MAKING);

        // Specific allocations subject to vesting
        // of 24 months, where 1/24th becomes available each month
        // vesting = IVesting(_vestingContract);
        _mint(_vestingContract, XION_RESERVE);
        _mint(_vestingContract, FOUNDERS_RESERVE);
        _mint(_vestingContract, COMMUNITY_AND_AIRDROPS);
        _mint(_vestingContract, TEAM_AND_ADVISORS);

        require(totalSupply() == MAX_SUPPLY, "XGT-INVALID-SUPPLY");

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

        // require(
        //     vesting.initializeVesting(
        //         address(this),
        //         beneficiaries,
        //         XION_RESERVE,
        //         _vestedAmountsFounders,
        //         _vestedAmountsTeam,
        //         _vestedAmountsCommunity,
        //         undistributedTeam,
        //         undistributedCommunity,
        //         msg.sender
        //     ),
        //     "XGT-FAILED-TO-INIT-VESTING-CONTRACT"
        // );
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
