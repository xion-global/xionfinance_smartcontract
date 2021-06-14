// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/IVestingSpawner.sol";

contract XGTToken is ERC20 {
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
        address _vestingSpawner,
        address _rewardChest,
        address _marketMakingMultiSig
    ) ERC20("Xion Global Token", "XGT") {
        require(_vestingSpawner != address(0), "XGT-INVALID-VESTING-ADDRESS");
        require(_rewardChest != address(0), "XGT-INVALID-REWARD-CHEST-ADDRESS");
        require(
            _marketMakingMultiSig != address(0),
            "XGT-INVALID-MARKET-MAKING-MULTISIG-ADDRESS"
        );
        IVestingSpawner vestingSpawner = IVestingSpawner(_vestingSpawner);

        // General token utility allocations
        _mint(_rewardChest, ISSUE_RESERVE);

        _mint(address(this), XION_RESERVE);
        _approve(address(this), _vestingSpawner, XION_RESERVE);
        vestingSpawner.fundSpawner(0, XION_RESERVE);

        _mint(address(this), FOUNDERS_RESERVE);
        _approve(address(this), _vestingSpawner, FOUNDERS_RESERVE);
        vestingSpawner.fundSpawner(1, FOUNDERS_RESERVE);

        _mint(address(this), TEAM_AND_ADVISORS);
        _approve(address(this), _vestingSpawner, TEAM_AND_ADVISORS);
        vestingSpawner.fundSpawner(2, TEAM_AND_ADVISORS);

        _mint(address(this), COMMUNITY_AND_AIRDROPS);
        _approve(address(this), _vestingSpawner, COMMUNITY_AND_AIRDROPS);
        vestingSpawner.fundSpawner(3, COMMUNITY_AND_AIRDROPS);

        _mint(_marketMakingMultiSig, MARKET_MAKING);

        require(totalSupply() == MAX_SUPPLY, "XGT-INVALID-SUPPLY");
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
