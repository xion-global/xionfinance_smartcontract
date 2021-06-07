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

    uint256 public currentPoolID = 0;
    uint256 public baseAPYPools;
    mapping(uint256 => Pool) public pools;

    mapping(address => mapping(uint256 => uint256)) public userPoolTokens;
    mapping(address => uint256) public userLastClaimedPool;

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
        PriceEntry[] storage prices;
        pools[currentPoolID] = Pool(
            _address,
            _networkID,
            _bonusAPY,
            prices,
            true
        );
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

    function getLatestPoolPrice(uint256 _id) external view returns (uint256) {
        return pools[_id].prices[0].xgtPerLPToken;
    }

    function claimModule(address _user) external onlyRewardChest {
        userLastClaimedPool[_user] = block.timestamp;
        require(
            rewardChest.addToBalance(_user, getClaimable(_user)),
            "XGT-REWARD-MODULE-FAILED-TO-ADD-TO-BALANCE"
        );
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
            total = total.add(
                (thisPoolTotal.mul(2))
                    .mul(baseAPYPools.add(pools[i].bonusAPY))
                    .div(10000)
            );
        }
        return total;
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
