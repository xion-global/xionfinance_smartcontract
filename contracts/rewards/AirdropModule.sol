// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.7.6;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IRewardChest.sol";

contract AirdropModule is Initializable, OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;

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

    function initialize(address _rewardChest, address _multiSig)
        public
        initializer
    {
        rewardChest = IRewardChest(_rewardChest);
        OwnableUpgradeable.__Ownable_init();
        transferOwnership(_multiSig);
    }

    function addVestedAirdrops(
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

    function addInstantAirdrops(address[] calldata _recipients, uint256 _amount)
        external
        onlyOwner
    {
        require(
            _recipients.length >= 1,
            "XGT-REWARD-CHEST-NEED-AT-LEAST-ONE-ADDRESS"
        );
        for (uint256 i = 0; i < _recipients.length; i++) {
            airdrops[_recipients[i]].push(
                Airdrop(_amount, block.timestamp, true)
            );
            emit AirdropAdded(_recipients[i], _amount, block.timestamp);
            require(
                rewardChest.sendInstantClaim(_recipients[i], _amount),
                "XGT-REWARD-CHEST-INSTANT-CLAIM-FAILED"
            );
            emit AirdropClaimed(_recipients[i], _amount);
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

    function claimModule(address _recipient) external onlyRewardChest {
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
