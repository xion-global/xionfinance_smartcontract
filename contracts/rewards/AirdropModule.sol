// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.7.6;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IRewardChest.sol";

contract AirdropModule is Initializable, OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;

    IERC20 public xgt;
    IRewardChest public rewardChest;

    struct Airdrop {
        uint256 amount;
        uint256 vestingEnd;
        bool claimed;
    }

    mapping(address => Airdrop[]) public airdrops;

    event AirdropAdded(
        address indexed recipient,
        uint256 amount,
        uint256 vestingEnd
    );
    event AirdropClaimed(address indexed recipient, uint256 amount);

    function initialize(address _xgt, address _rewardChest) public initializer {
        xgt = IERC20(_xgt);
        rewardChest = IRewardChest(_rewardChest);

        OwnableUpgradeable.__Ownable_init();
        transferOwnership(rewardChest.owner());
    }

    function addAirdrops(
        address[] calldata _recipients,
        uint256 _amount,
        uint256 _vestingDuration
    ) external onlyOwner {
        require(
            _recipients.length >= 1,
            "XGT-REWARD-CHEST-NEED-AT-LEAST-ONE-ADDRESS"
        );
        uint256 vestingEnd = block.timestamp.add(_vestingDuration);
        for (uint256 i = 0; i < _recipients.length; i++) {
            airdrops[_recipients[i]].push(Airdrop(_amount, vestingEnd, false));
            emit AirdropAdded(_recipients[i], _amount, vestingEnd);
        }
    }

    function getClaimable(address _recipient) external view returns (uint256) {
        uint256 total = 0;

        if (airdrops[_recipient].length >= 1) {
            for (uint256 i = 0; i < airdrops[_recipient].length; i++) {
                if (
                    !airdrops[_recipient][i].claimed &&
                    airdrops[_recipient][i].vestingEnd >= block.timestamp
                ) {
                    total = total.add(airdrops[_recipient][i].amount);
                }
            }
        }
        return total;
    }

    function claimModule(address _recipient) external {
        if (airdrops[_recipient].length >= 1) {
            for (uint256 i = 0; i < airdrops[_recipient].length; i++) {
                if (
                    !airdrops[_recipient][i].claimed &&
                    airdrops[_recipient][i].vestingEnd >= block.timestamp
                ) {
                    airdrops[_recipient][i].claimed = true;
                    require(
                        rewardChest.addToBalance(
                            _recipient,
                            airdrops[_recipient][i].amount
                        ),
                        "XGT-REWARD-MODULE-FAILED-TO-ADD-TO-BALANCE"
                    );
                    emit AirdropClaimed(
                        _recipient,
                        airdrops[_recipient][i].amount
                    );
                }
            }
        }
    }

    modifier onlyRewardChest() {
        require(
            msg.sender == address(rewardChest),
            "XGT-REWARD-CHEST-NOT-AUTHORIZED"
        );
        _;
    }
}
