// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.7.6;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract XGTRewardChest is Initializable, OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;

    IERC20 public xgt;
    uint256 constant YEAR_IN_SECONDS = 31536000;

    ////////////////////////////////////////////
    // Farming
    ////////////////////////////////////////////
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

    uint256 public currentPoolID = 0;
    uint256 public baseAPYPools;
    mapping(uint256 => Pool) public pools;

    mapping(address => mapping(uint256 => uint256)) public userPoolTokens;
    mapping(address => uint256) public userLastClaimedPool;
    mapping(address => uint256) public userWithdrawable;
    ////////////////////////////////////////////

    ////////////////////////////////////////////
    // Airdrops
    ////////////////////////////////////////////
    struct Airdrop {
        uint256 amount;
        uint256 vestingEnd;
        bool claimed;
    }
    mapping(address => Airdrop[]) public airdrops;
    ////////////////////////////////////////////

    ////////////////////////////////////////////
    // Security
    ////////////////////////////////////////////
    bool public paused;
    ////////////////////////////////////////////

    mapping(address => bool) public indexerAddress;

    event PauseStateChanged(address performer, bool paused);
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

    function initializeGenerator() public {}

    function setIndexerAddress(address _address, bool _authorized)
        external
        onlyOwner
    {
        indexerAddress[_address] = _authorized;
    }

    function setPauseContract(bool _pause) external onlyOwner {
        paused = _pause;
        emit PauseStateChanged(msg.sender, _pause);
    }

    function addPool(
        address _address,
        uint256 _networkID,
        uint256 _bonusAPY
    ) external onlyOwner {
        currentPoolID++;
        PriceEntry[] storage prices;
        Pool memory newPool =
            Pool(_address, _networkID, _bonusAPY, prices, true);
        pools[currentPoolID] = newPool;
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
        }
    }

    function addAirdrops(
        address[] calldata _users,
        uint256 _amount,
        uint256 _vestingDuration
    ) external onlyOwner {
        require(
            _users.length >= 1,
            "XGT-REWARD-CHEST-NEED-AT-LEAST-ONE-ADDRESS"
        );
        uint256 vestingEnd = block.timestamp.add(_vestingDuration);
        for (uint256 i = 0; i < _users.length; i++) {
            airdrops[_users[i]].push(Airdrop(_amount, vestingEnd, false));
        }
    }

    function getLatestPoolPrice(uint256 _id) external view returns (uint256) {
        return pools[_id].prices[0].xgtPerLPToken;
    }

    function claim() external onlyIfNotPaused returns (uint256 withdrawAmount) {
        claimPool(msg.sender);
        claimAirdrops(msg.sender);

        withdrawAmount = userWithdrawable[msg.sender];
        userWithdrawable[msg.sender] = 0;

        require(
            xgt.transfer(msg.sender, withdrawAmount),
            "XGT-REWARD-CHEST-WITHDRAW-TRANSFER-FAILED"
        );

        return withdrawAmount;
    }

    function getClaimable(address _user) external view returns (uint256) {
        // withdrawable balance
        uint256 total = userWithdrawable[_user];

        // add unclaimed pool rewards
        total = total.add(getUserUnclaimedRewardsPool(_user));

        // add any matured airdrops
        if (airdrops[_user].length >= 1) {
            for (uint256 i = 0; i < airdrops[_user].length; i++) {
                if (
                    !airdrops[_user][i].claimed &&
                    airdrops[_user][i].vestingEnd >= block.timestamp
                ) {
                    total = total.add(airdrops[_user][i].amount);
                }
            }
        }
        return total;
    }

    function claimPool(address _user) internal {
        uint256 totalOutstanding = getUserUnclaimedRewardsPool(_user);
        userLastClaimedPool[_user] = block.timestamp;
        userWithdrawable[_user] = userWithdrawable[_user].add(totalOutstanding);
    }

    function claimAirdrops(address _user) internal {
        if (airdrops[_user].length >= 1) {
            for (uint256 i = 0; i < airdrops[_user].length; i++) {
                if (
                    !airdrops[_user][i].claimed &&
                    airdrops[_user][i].vestingEnd >= block.timestamp
                ) {
                    airdrops[_user][i].claimed = true;
                    userWithdrawable[_user] = userWithdrawable[_user].add(
                        airdrops[_user][i].amount
                    );
                }
            }
        }
    }

    function getUserUnclaimedRewardsPool(address _user)
        internal
        view
        returns (uint256)
    {
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
            total = total.add(
                (thisPoolTotal.mul(2))
                    .mul(baseAPYPools.add(pools[i].bonusAPY))
                    .div(10000)
            );
        }
        return total;
    }

    modifier onlyIfNotPaused() {
        if (!paused) {
            _;
        }
    }

    modifier onlyIndexer() {
        require(
            indexerAddress[msg.sender],
            "XGT-REWARD-CHEST-NOT-AUTHORIZED-INDEXER"
        );
        _;
    }
}
