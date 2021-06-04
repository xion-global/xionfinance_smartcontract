// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.7.6;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IRewardChest.sol";

contract CashbackModule is Initializable, OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;

    IERC20 public xgt;
    IRewardChest public rewardChest;

    address public subscriptionContract;
    uint256 public lockupTime;

    struct Cashback {
        uint256 amount;
        uint256 vestingEnd;
        bool claimed;
    }
    mapping(address => Cashback[]) public cashbacks;

    event CashbackAdded(
        address indexed recipient,
        uint256 amount,
        uint256 vestingEnd
    );
    event CashbackClaimed(address indexed recipient, uint256 amount);

    function initialize(
        address _xgt,
        address _rewardChest,
        address _subscriptionContract,
        uint256 _lockupTime
    ) public initializer {
        xgt = IERC20(_xgt);
        rewardChest = IRewardChest(_rewardChest);
        subscriptionContract = _subscriptionContract;
        lockupTime = _lockupTime;

        OwnableUpgradeable.__Ownable_init();
        transferOwnership(rewardChest.owner());
    }

    function changeSubscriptionContract(address _newSubscriptionContract)
        external
        onlyOwner
    {
        subscriptionContract = _newSubscriptionContract;
    }

    function addCashbacks(address[] calldata _recipients, uint256 _amount)
        external
        onlySubscriptionContract
    {
        require(
            _recipients.length >= 1,
            "XGT-REWARD-CHEST-NEED-AT-LEAST-ONE-ADDRESS"
        );
        uint256 vestingEnd = block.timestamp.add(lockupTime);
        for (uint256 i = 0; i < _recipients.length; i++) {
            cashbacks[_recipients[i]].push(
                Cashback(_amount, vestingEnd, false)
            );
            emit CashbackAdded(_recipients[i], _amount, vestingEnd);
        }
    }

    function getClaimable(address _recipient) external view returns (uint256) {
        uint256 total = 0;

        if (cashbacks[_recipient].length >= 1) {
            for (uint256 i = 0; i < cashbacks[_recipient].length; i++) {
                if (
                    !cashbacks[_recipient][i].claimed &&
                    cashbacks[_recipient][i].vestingEnd >= block.timestamp
                ) {
                    total = total.add(cashbacks[_recipient][i].amount);
                }
            }
        }
        return total;
    }

    function claimModule(address _recipient) external {
        if (cashbacks[_recipient].length >= 1) {
            for (uint256 i = 0; i < cashbacks[_recipient].length; i++) {
                if (
                    !cashbacks[_recipient][i].claimed &&
                    cashbacks[_recipient][i].vestingEnd >= block.timestamp
                ) {
                    cashbacks[_recipient][i].claimed = true;
                    require(
                        rewardChest.addToBalance(
                            _recipient,
                            cashbacks[_recipient][i].amount
                        ),
                        "XGT-REWARD-MODULE-FAILED-TO-ADD-TO-BALANCE"
                    );
                    emit CashbackClaimed(
                        _recipient,
                        cashbacks[_recipient][i].amount
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

    modifier onlySubscriptionContract() {
        require(
            msg.sender == address(subscriptionContract),
            "XGT-REWARD-CHEST-NOT-AUTHORIZED"
        );
        _;
    }
}
