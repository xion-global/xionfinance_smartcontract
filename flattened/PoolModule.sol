// File: @openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol

// MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMathUpgradeable {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

// File: @openzeppelin/contracts-upgradeable/proxy/Initializable.sol

// MIT

// solhint-disable-next-line compiler-version
pragma solidity >=0.4.24 <0.8.0;

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since a proxied contract can't have a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {UpgradeableProxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Modifier to protect an initializer function from being invoked twice.
     */
    modifier initializer() {
        require(
            _initializing || _isConstructor() || !_initialized,
            "Initializable: contract is already initialized"
        );

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }

    /// @dev Returns true if and only if the function is running in the constructor
    function _isConstructor() private view returns (bool) {
        // extcodesize checks the size of the code stored in an address, and
        // address returns the current address. Since the code is still not
        // deployed when running a constructor, any checks on its code size will
        // yield zero, making it an effective way to detect if a contract is
        // under construction or not.
        address self = address(this);
        uint256 cs;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            cs := extcodesize(self)
        }
        return cs == 0;
    }
}

// File: @openzeppelin/contracts-upgradeable/GSN/ContextUpgradeable.sol

// MIT

pragma solidity >=0.6.0 <0.8.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal initializer {
        __Context_init_unchained();
    }

    function __Context_init_unchained() internal initializer {}

    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }

    uint256[50] private __gap;
}

// File: @openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol

// MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal initializer {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    uint256[49] private __gap;
}

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol

// MIT

pragma solidity ^0.7.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

// File: contracts/interfaces/IRewardChest.sol

// AGPL-3.0
pragma solidity 0.7.6;

interface IRewardChest {
    function addToBalance(address _user, uint256 _amount)
        external
        returns (bool);

    function sendInstantClaim(address _user, uint256 _amount)
        external
        returns (bool);

    function owner() external view returns (address);
}

// File: contracts/rewards/PoolModule.sol

// AGPL-3.0
pragma solidity 0.7.6;

contract PoolModule is Initializable, OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;

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
        uint256 timestamp;
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

    uint256 public currentPoolID;
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

    function initialize(
        address _rewardChest,
        address _multiSig,
        uint256 _currentPoolId
    ) public initializer {
        rewardChest = IRewardChest(_rewardChest);
        OwnableUpgradeable.__Ownable_init();
        transferOwnership(_multiSig);
        currentPoolID = _currentPoolId;
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

    function togglePool(uint256 _id, bool _active)
        external
        onlyOwner
        validPool(_id)
    {
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
        validPool(_id)
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
        uint256 _timestamp
    ) external onlyIndexer validPool(_id) {
        require(
            pools[_id].prices.length == 0 ||
                _timestamp >
                pools[_id].prices[pools[_id].prices.length - 1].timestamp,
            "XGT-REWARD-CHEST-INVALID-BLOCKNUMBER"
        );
        // append latest entry to array
        pools[_id].prices.push(PriceEntry(_xgtPerLP, _timestamp));

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
        require(
            rewardChest.addToBalance(_user, getClaimable(_user)),
            "XGT-REWARD-MODULE-FAILED-TO-ADD-TO-BALANCE"
        );
        userLastClaimedPool[_user] = block.timestamp;

        require(
            _ids.length == _amount.length,
            "XGT-REWARD-CHEST-ARRAY-LENGTHS-DONT-MATCH"
        );
        for (uint256 i = 0; i < _ids.length; i++) {
            userPoolTokens[_user][_ids[i]] = _amount[i];
            for (uint256 j = 0; j < promotionBoosts.length; j++) {
                if (
                    promotionBoosts[j].active &&
                    promotionBoosts[j].id == _ids[i] &&
                    promotionBoosts[j].cutoff >= block.timestamp &&
                    promotionBoosts[j].users < promotionBoosts[j].maxUsers &&
                    !userUsedPromotionBoost[_user][j]
                ) {
                    userBoosts[_user].push(
                        Boost(
                            _ids[i],
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
    ) external onlyOwner validPool(_id) {
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
    ) external onlyOwner validPool(_id) {
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
    ) external onlyOwner validPool(_id) {
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
        return pools[_id].prices[pools[_id].prices.length - 1].xgtPerLPToken;
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
        for (uint256 i = 1; i <= currentPoolID; i++) {
            if (pools[i].active && userPoolTokens[_user][i] > 0) {
                uint256 last = userLastClaimedPool[_user];
                uint256 thisPoolTotal = 0;
                uint256 lenPrices = pools[i].prices.length;
                // if: there has been no new price after the users last claim
                // we claim from last claiming time til now
                if (pools[i].prices[lenPrices - 1].timestamp <= last) {
                    thisPoolTotal = thisPoolTotal.add(
                        _poolTokenCalculation(
                            _user,
                            i,
                            lenPrices - 1,
                            last,
                            block.timestamp
                        )
                    );
                } else {
                    // else: if there have been new prices after the last claim of the user
                    for (uint256 j = 0; j < lenPrices; j++) {
                        uint256 safeLastJ = j == 0 ? 0 : j - 1;
                        // if this price is the last one in the array
                        if (j == lenPrices - 1) {
                            // add the time between this last price and the last claim
                            // with the old price of the time before this one AND
                            // add the time since this price til now with the new price
                            thisPoolTotal = thisPoolTotal
                                .add(
                                _poolTokenCalculation(
                                    _user,
                                    i,
                                    safeLastJ,
                                    last,
                                    pools[i].prices[j].timestamp
                                )
                            )
                                .add(
                                _poolTokenCalculation(
                                    _user,
                                    i,
                                    j,
                                    pools[i].prices[j].timestamp,
                                    block.timestamp
                                )
                            );
                        } else {
                            // if the price is not the most current one, but the user
                            // hasn't claimed since then:
                            // take the time between last claim and this price
                            // with the price at that time and update the last claim time
                            if (last < pools[i].prices[j].timestamp) {
                                if (j == 0) {}
                                thisPoolTotal = thisPoolTotal.add(
                                    _poolTokenCalculation(
                                        _user,
                                        i,
                                        safeLastJ,
                                        last,
                                        pools[i].prices[j].timestamp
                                    )
                                );
                                last = pools[i].prices[j].timestamp;
                            }
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
        }
        return total;
    }

    function _poolTokenCalculation(
        address _user,
        uint256 _pool,
        uint256 _priceIndex,
        uint256 _from,
        uint256 _to
    ) internal view returns (uint256) {
        return
            (
                (
                    (
                        userPoolTokens[_user][_pool].mul(
                            pools[_pool].prices[_priceIndex].xgtPerLPToken
                        )
                    )
                        .mul((_to.sub(_from)))
                )
                    .div(YEAR_IN_SECONDS)
            )
                .div(10**18);
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
                    userBoosts[_user][j].id == _id) &&
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

    modifier validPool(uint256 _id) {
        require(
            pools[_id].addr != address(0),
            "XGT-REWARD-CHEST-POOL-DOES-NOT-EXIST"
        );
        _;
    }
}
