// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.7.6;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IRewardChest.sol";

contract PoolModule is Initializable, OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;

    IERC20 public xgt;
    IRewardChest public rewardChest;

    uint256 constant YEAR_IN_SECONDS = 31536000;

    struct Pool {
        address addr;
        uint256 networkID;
        uint256 bonusAPY;
        PriceEntry[] prices;
        bool active;
    }

    struct PriceEntry {
        uint256 xgtPerLPToken;
        uint256 blocknumber;
    }

    struct Boost {
        uint256 id;
        uint256 start;
        uint256 end;
        uint256 boost;
    }

    struct PromotionBoost {
        uint256 id;
        uint256 cutoff;
        uint256 duration;
        uint256 boost;
        uint256 maxUsers;
        uint256 users;
        bool active;
    }

    uint256 public currentPoolID = 0;
    uint256 public baseAPYPools;
    mapping(uint256 => Pool) public pools;

    Boost[] public poolBoosts;
    mapping(address => Boost[]) public userBoosts;
    PromotionBoost[] public promotionBoosts;

    mapping(address => mapping(uint256 => uint256)) public userPoolTokens;
    mapping(address => uint256) public userLastClaimedPool;
    mapping(address => mapping(uint256 => bool)) public userUsedPromotionBoost;

    mapping(address => bool) public indexerAddress;

    event PoolAdded(address poolAddress, uint256 networkID, uint256 bonusAPY);
    event PoolActiveStateToggled(
        address poolAddress,
        uint256 networkID,
        bool active
    );
    event PoolBonusAPYChanged(
        address poolAddress,
        uint256 networkID,
        uint256 bonusAPY
    );
    event PoolBaseAPYChanged(uint256 bonusAPY);

    function initialize(address _xgt, address _rewardChest) public initializer {
        xgt = IERC20(_xgt);
        rewardChest = IRewardChest(_rewardChest);

        OwnableUpgradeable.__Ownable_init();
        transferOwnership(rewardChest.owner());
    }

    function setIndexerAddress(address _address, bool _authorized)
        external
        onlyOwner
    {
        indexerAddress[_address] = _authorized;
    }

    function addPool(
        address _address,
        uint256 _networkID,
        uint256 _bonusAPY
    ) external onlyOwner {
        currentPoolID++;
        pools[currentPoolID].addr = _address;
        pools[currentPoolID].networkID = _networkID;
        pools[currentPoolID].bonusAPY = _bonusAPY;
        pools[currentPoolID].active = true;
        emit PoolAdded(_address, _networkID, _bonusAPY);
    }

    function togglePool(uint256 _id, bool _active) external onlyOwner {
        pools[_id].active = _active;
        emit PoolActiveStateToggled(
            pools[_id].addr,
            pools[_id].networkID,
            _active
        );
    }

    function changePoolBonusAPY(uint256 _id, uint256 _bonusAPY)
        external
        onlyOwner
    {
        pools[_id].bonusAPY = _bonusAPY;
        emit PoolBonusAPYChanged(
            pools[_id].addr,
            pools[_id].networkID,
            _bonusAPY
        );
    }

    function changePoolBaseAPY(uint256 _baseAPY) external onlyOwner {
        baseAPYPools = _baseAPY;
        emit PoolBaseAPYChanged(_baseAPY);
    }

    function setCurrentPoolPrice(
        uint256 _id,
        uint256 _xgtPerLP,
        uint256 _blocknumber
    ) external onlyIndexer {
        // append latest entry to array
        pools[_id].prices.push(PriceEntry(_xgtPerLP, _blocknumber));

        // max length is 10, so if it's 11 then remove the last
        if (pools[_id].prices.length == 11) {
            // reorder array so all elements move one step to the left
            // e.g. element 11 is then element 10
            for (uint256 i = 0; i < pools[_id].prices.length - 1; i++) {
                pools[_id].prices[i] = pools[_id].prices[i + 1];
            }
            // remove last element 11
            pools[_id].prices.pop();
        }
    }

    function setUserPoolTokens(
        address _user,
        uint256[] calldata _ids,
        uint256[] calldata _amount
    ) external onlyIndexer {
        // claim for user
        require(
            _ids.length == _amount.length,
            "XGT-REWARD-CHEST-ARRAY-LENGTHS-DONT-MATCH"
        );
        for (uint256 i = 0; i < _ids.length; i++) {
            userPoolTokens[_user][i] = _amount[i];
            for (uint256 j = 0; j < promotionBoosts.length; j++) {
                if (
                    promotionBoosts[j].active &&
                    promotionBoosts[j].id == i &&
                    promotionBoosts[j].cutoff >= block.timestamp &&
                    promotionBoosts[j].users < promotionBoosts[j].maxUsers &&
                    !userUsedPromotionBoost[_user][j]
                ) {
                    userBoosts[_user].push(
                        Boost(
                            i,
                            block.timestamp,
                            block.timestamp.add(promotionBoosts[j].duration),
                            promotionBoosts[j].boost
                        )
                    );
                    promotionBoosts[j].users++;
                    userUsedPromotionBoost[_user][j] = true;
                }
            }
        }
        // remove old boosts
        for (uint256 k = 0; k < userBoosts[_user].length; k++) {
            if (userBoosts[_user][k].end <= userLastClaimedPool[_user]) {
                _removeUserBoost(_user, k);
            }
        }
    }

    function addPromotionBoost(
        uint256 _id,
        uint256 _cutOffTime,
        uint256 _duration,
        uint256 _boost,
        uint256 _validForUsers
    ) external onlyOwner {
        uint256 maxUsers = _validForUsers;
        if (_validForUsers == 0) {
            maxUsers = 2**256 - 1;
        }
        promotionBoosts.push(
            PromotionBoost(
                _id,
                _cutOffTime,
                _duration,
                _boost,
                maxUsers,
                0,
                true
            )
        );
    }

    function disablePromotionBoost(uint256 _index) external onlyOwner {
        promotionBoosts[_index].active = false;
    }

    function getPromotionBoost(uint256 _index)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            bool
        )
    {
        return (
            promotionBoosts[_index].id,
            promotionBoosts[_index].cutoff,
            promotionBoosts[_index].duration,
            promotionBoosts[_index].boost,
            promotionBoosts[_index].maxUsers,
            promotionBoosts[_index].users,
            promotionBoosts[_index].active
        );
    }

    function addUserBoost(
        address[] calldata _users,
        uint256 _id,
        uint256 _start,
        uint256 _end,
        uint256 _boost
    ) external onlyOwner {
        for (uint256 i = 0; i < _users.length; i++) {
            userBoosts[_users[i]].push(Boost(_id, _start, _end, _boost));
        }
    }

    function removeUserBoost(address _user, uint256 _index) external onlyOwner {
        _removeUserBoost(_user, _index);
    }

    function _removeUserBoost(address _user, uint256 _index) internal {
        if (userBoosts[_user].length != 1) {
            userBoosts[_user][_index] = userBoosts[_user][
                userBoosts[_user].length - 1
            ];
        }
        userBoosts[_user].pop();
    }

    function getUserBoost(address _user, uint256 _index)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return (
            userBoosts[_user][_index].id,
            userBoosts[_user][_index].start,
            userBoosts[_user][_index].end,
            userBoosts[_user][_index].boost
        );
    }

    function addPoolBoost(
        uint256 _id,
        uint256 _start,
        uint256 _end,
        uint256 _boost
    ) external onlyOwner {
        poolBoosts.push(Boost(_id, _start, _end, _boost));
    }

    function removePoolBoost(uint256 _index) external onlyOwner {
        if (poolBoosts.length != 1) {
            poolBoosts[_index] = poolBoosts[poolBoosts.length - 1];
        }
        poolBoosts.pop();
    }

    function getPoolBoost(uint256 _index)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return (
            poolBoosts[_index].id,
            poolBoosts[_index].start,
            poolBoosts[_index].end,
            poolBoosts[_index].boost
        );
    }

    function getLatestPoolPrice(uint256 _id) external view returns (uint256) {
        return pools[_id].prices[0].xgtPerLPToken;
    }

    function claimModule(address _user) external onlyRewardChest {
        require(
            rewardChest.addToBalance(_user, getClaimable(_user)),
            "XGT-REWARD-MODULE-FAILED-TO-ADD-TO-BALANCE"
        );
        userLastClaimedPool[_user] = block.timestamp;
    }

    function getClaimable(address _user) public view returns (uint256) {
        uint256 total = 0;
        uint256 last = userLastClaimedPool[_user];
        for (uint256 i = 1; i <= currentPoolID; i++) {
            uint256 thisPoolTotal = 0;
            uint256 poolTokens = userPoolTokens[_user][i];
            uint256 lenPrices = pools[i].prices.length;
            if (pools[i].prices[lenPrices - 1].blocknumber <= last) {
                thisPoolTotal = thisPoolTotal.add(
                    (
                        (
                            (
                                poolTokens.mul(
                                    pools[i].prices[lenPrices - 1].xgtPerLPToken
                                )
                            )
                                .mul((block.timestamp.sub(last)))
                        )
                            .div(YEAR_IN_SECONDS)
                    )
                        .div(10**18)
                );
            } else {
                for (uint256 j = 0; j < lenPrices; j++) {
                    if (j == lenPrices - 1) {
                        uint256 diff = pools[i].prices[j].blocknumber.sub(last);
                        thisPoolTotal = thisPoolTotal.add(
                            (
                                (
                                    (
                                        poolTokens.mul(
                                            pools[i].prices[j].xgtPerLPToken
                                        )
                                    )
                                        .mul(diff)
                                )
                                    .div(YEAR_IN_SECONDS)
                            )
                                .div(10**18)
                        );
                        last = last.add(diff);
                    } else {
                        thisPoolTotal = thisPoolTotal.add(
                            (
                                (
                                    (
                                        poolTokens.mul(
                                            pools[i].prices[lenPrices - 1]
                                                .xgtPerLPToken
                                        )
                                    )
                                        .mul((block.timestamp.sub(last)))
                                )
                                    .div(YEAR_IN_SECONDS)
                            )
                                .div(10**18)
                        );
                    }
                }
            }
            uint256 boosts = _calculateBoosts(i, _user);
            total = total.add(
                (thisPoolTotal.mul(2))
                    .mul(baseAPYPools.add(pools[i].bonusAPY).add(boosts))
                    .div(10000)
            );
        }
        return total;
    }

    function _calculateBoosts(uint256 _id, address _user)
        internal
        view
        returns (uint256)
    {
        uint256 last = userLastClaimedPool[_user];
        uint256 boosts = 0;
        for (uint256 i = 0; i < poolBoosts.length; i++) {
            // id == 0 means every pool, otherwise pool ids start from 1
            if (
                (poolBoosts[i].id == 0 || poolBoosts[i].id == _id) &&
                poolBoosts[i].end > last
            ) {
                // default: apply bonus from last time claimed until now
                uint256 from = last;
                uint256 to = block.timestamp;
                // if the bonus started after the last claim time
                // set it to the starting time of the bonus
                if (poolBoosts[i].start > last) {
                    from = poolBoosts[i].start;
                }
                // if the bonus ended already
                // set the ending time of the bonus to
                // the correct time
                if (poolBoosts[i].end < to) {
                    to = poolBoosts[i].end;
                }
                boosts = boosts.add(
                    (poolBoosts[i].boost.mul(to.sub(from))).div(
                        block.timestamp.sub(last)
                    )
                );
            }
        }
        for (uint256 j = 0; j < userBoosts[_user].length; j++) {
            if (
                (userBoosts[_user][j].id == 0 ||
                    userBoosts[_user][j].id == j) &&
                userBoosts[_user][j].end > last
            ) {
                // default: apply bonus from last time claimed until now
                uint256 from = last;
                uint256 to = block.timestamp;

                // if the bonus started after the last claim time
                // set it to the starting time of the bonus
                if (userBoosts[_user][j].start > last) {
                    from = userBoosts[_user][j].start;
                }
                // if the bonus ended already
                // set the ending time of the bonus to
                // the correct time
                if (userBoosts[_user][j].end < to) {
                    to = userBoosts[_user][j].end;
                }
                boosts = boosts.add(
                    (userBoosts[_user][j].boost.mul(to.sub(from))).div(
                        block.timestamp.sub(last)
                    )
                );
            }
        }
        return boosts;
    }

    modifier onlyIndexer() {
        require(
            indexerAddress[msg.sender],
            "XGT-REWARD-CHEST-NOT-AUTHORIZED-INDEXER"
        );
        _;
    }

    modifier onlyRewardChest() {
        require(
            msg.sender == address(rewardChest),
            "XGT-REWARD-CHEST-NOT-AUTHORIZED"
        );
        _;
    }
}
