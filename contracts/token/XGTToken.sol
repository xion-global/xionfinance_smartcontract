// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract XGTToken is ERC20 {
    using SafeMath for uint256;

    // Total Token Supply
    uint256 private constant MAX_SUPPLY = 1000000000 * 10**18; // 1 billion

    // Specific supplies
    uint256 private constant ISSUE_RESERVE = 450000000 * 10**18; // 450 million
    uint256 private constant XION_RESERVE = 200000000 * 10**18; // 200 million
    uint256 private constant FOUNDERS_RESERVE = 150000000 * 10**18; // 150 million
    uint256 private constant TEAM_AND_ADVISORS = 150000000 * 10**18; // 100 million
    uint256 private constant MARKET_MAKING = 50000000 * 10**18; // 50 million

    constructor() ERC20("Xion Global Token", "XGT") {}

    function initialize(
        address _vestingReceiver,
        address _rewardChest,
        address _marketMakingAddress,
        uint256 _marketMakingAmount
    ) external {
        require(totalSupply() == 0, "XGT-ALREADY-INITIALIZED");
        require(_vestingReceiver != address(0), "XGT-INVALID-VESTING-ADDRESS");
        require(_rewardChest != address(0), "XGT-INVALID-REWARD-CHEST-ADDRESS");
        require(
            _marketMakingAddress != address(0),
            "XGT-INVALID-MARKET-MAKING-MULTISIG-ADDRESS"
        );
        uint256 amountInVesting = 0;

        // General token utility allocations
        _mint(_rewardChest, ISSUE_RESERVE);

        _mint(_vestingReceiver, XION_RESERVE);
        amountInVesting = amountInVesting.add(XION_RESERVE);

        _mint(_vestingReceiver, FOUNDERS_RESERVE);
        amountInVesting = amountInVesting.add(FOUNDERS_RESERVE);

        _mint(_vestingReceiver, TEAM_AND_ADVISORS);
        amountInVesting = amountInVesting.add(TEAM_AND_ADVISORS);

        uint256 marketMakingAmountVested =
            MARKET_MAKING.sub(_marketMakingAmount);
        _mint(_marketMakingAddress, _marketMakingAmount);

        _mint(_vestingReceiver, marketMakingAmountVested);
        amountInVesting = amountInVesting.add(marketMakingAmountVested);

        require(totalSupply() == MAX_SUPPLY, "XGT-INVALID-SUPPLY");
        require(
            balanceOf(_vestingReceiver) == amountInVesting,
            "XGT-UNSUCCESSFUL-VESTING"
        );
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
