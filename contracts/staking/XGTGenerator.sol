pragma solidity ^0.5.16;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/upgrades/contracts/ownership/Ownable.sol";
import "../interfaces/IBridgeContract.sol";
import "../interfaces/IXGTToken.sol";
import "../liquiditypool/interfaces/IUniswapV2Pair.sol";

contract XGTGenerator is Initializable, OpenZeppelinUpgradesOwnable {
    using SafeMath for uint256;

    IBridgeContract public bridge;
    IXGTToken public xgt;
    IUniswapV2Pair public xgtpair;

    address public stakingContractMainnet;
    address public poolRouterContract;

    uint256 public xgtGenerationRateStake;
    uint256 public xgtGenerationRatePool;

    bool public paused = false;

    mapping(address => UserDeposits) public specificUserDeposits;
    mapping(address => uint256) public totalUserDeposit;
    mapping(address => uint256) internal userPoolTokens;
    mapping(address => uint256) internal userDAITokens;
    uint256 public totalDeposits;

    struct UserDeposits {
        uint256 lastTimeClaimed;
        DepositPerRate[] deposits;
    }

    struct DepositPerRate {
        uint256 amount;
        uint256 generationRate;
    }

    function initialize(
        address _bridge,
        address _stakingContractMainnet,
        address _xgt,
        address _poolRouter,
        address _xgtPair,
        uint256 _initialxgtGenerationRateStake,
        uint256 _initialxgtGenerationRatePool
    ) public initializer {
        bridge = IBridgeContract(_bridge);
        xgt = IXGTToken(_xgt);
        poolRouterContract = _poolRouter;
        xgtpair = IUniswapV2Pair(_xgtPair);
        stakingContractMainnet = _stakingContractMainnet;
        xgtGenerationRateStake = _initialxgtGenerationRateStake;
        xgtGenerationRatePool = _initialxgtGenerationRatePool;
    }

    function togglePauseContract(bool _pause) public onlyOwner {
        paused = _pause;
    }

    function updatexgtGenerationRateStake(uint256 _newxgtGenerationRateStake)
        public
        onlyOwner
    {
        xgtGenerationRateStake = _newxgtGenerationRateStake;
    }

    function updatexgtGenerationRatePool(uint256 _newxgtGenerationRatePool)
        public
        onlyOwner
    {
        xgtGenerationRatePool = _newxgtGenerationRatePool;
    }

    function updatePoolRouter(address _newPoolRouter) public onlyOwner {
        poolRouterContract = _newPoolRouter;
    }

    function tokensStaked(uint256 _amount, address _user)
        external
        onlyIfNotPaused
    {
        require(msg.sender == address(bridge), "XGTSTAKE-NOT-BRIDGE");
        require(
            bridge.messageSender() == stakingContractMainnet,
            "XGTSTAKE-NOT-MAINNET-CONTRACT"
        );
        userDAITokens[_user] = userDAITokens[_user].add(_amount);
        _startGeneration(_amount, _user, xgtGenerationRateStake);
    }

    function tokensPooled(uint256 _amount, address _user)
        external
        onlyIfNotPaused
    {
        require(msg.sender == poolRouterContract, "XGTSTAKE-NOT-POOL-ROUTER");
        userPoolTokens[_user] = userPoolTokens[_user].add(_amount);
        _startGeneration(_amount, _user, xgtGenerationRatePool);
    }

    function _startGeneration(
        uint256 _amount,
        address _user,
        uint256 _rate
    ) internal {
        claimXGT(_user);

        totalUserDeposit[_user] = totalUserDeposit[_user].add(_amount);
        totalDeposits = totalDeposits.add(_amount);

        if (specificUserDeposits[_user].deposits.length != 0) {
            uint256 lastItem =
                specificUserDeposits[_user].deposits.length.sub(1);

            if (
                specificUserDeposits[_user].deposits[lastItem].generationRate ==
                _rate
            ) {
                specificUserDeposits[_user].deposits[lastItem]
                    .amount = specificUserDeposits[_user].deposits[lastItem]
                    .amount
                    .add(_amount);
                return;
            }
        }
        specificUserDeposits[_user].deposits.push(
            DepositPerRate(_amount, _rate)
        );
    }

    function tokensUnstaked(uint256 _amount, address _user)
        external
        onlyIfNotPaused
    {
        require(msg.sender == address(bridge), "XGTSTAKE-NOT-BRIDGE");
        require(
            bridge.messageSender() == stakingContractMainnet,
            "XGTSTAKE-NOT-MAINNET-CONTRACT"
        );

        userDAITokens[_user] = userDAITokens[_user].sub(_amount);
        _stopGeneration(_amount, _user);
    }

    function tokensUnpooled(uint256 _amount, address _user)
        external
        onlyIfNotPaused
    {
        require(msg.sender == poolRouterContract, "XGTSTAKE-NOT-POOL-ROUTER");
        userPoolTokens[_user] = userPoolTokens[_user].sub(_amount);
        _stopGeneration(_amount, _user);
    }

    function _stopGeneration(uint256 _amount, address _user) internal {
        // Claim XGT so nothing get's lost
        claimXGT(_user);

        totalUserDeposit[_user] = totalUserDeposit[_user].sub(_amount);
        totalDeposits = totalDeposits.sub(_amount);

        uint256 remainingAmount = _amount;
        for (
            uint256 i = specificUserDeposits[_user].deposits.length - 1;
            i >= 0;
            i--
        ) {
            // If the amount in this entry is enough, subtract as much as needed and set remainder to zero
            if (
                specificUserDeposits[_user].deposits[i].amount >=
                remainingAmount
            ) {
                specificUserDeposits[_user].deposits[i]
                    .amount = specificUserDeposits[_user].deposits[i]
                    .amount
                    .sub(remainingAmount);
                remainingAmount = 0;
                // If the amount is not enough, take the amount and continue
            } else {
                specificUserDeposits[_user].deposits[i].amount = 0;
                remainingAmount = remainingAmount.sub(
                    specificUserDeposits[_user].deposits[i].amount
                );
            }

            // If this entry doesn't have anything left, delete the array entry
            if (specificUserDeposits[_user].deposits[i].amount == 0) {
                delete specificUserDeposits[_user].deposits[i];
                specificUserDeposits[_user]
                    .deposits
                    .length = specificUserDeposits[_user].deposits.length.sub(
                    1
                );
            }

            // If we are finished, break the loop
            if (remainingAmount == 0) {
                break;
            }
        }

        // Just in case, remaining amount should be zero now
        require(
            remainingAmount == 0,
            "XGTSTAKE-WITHDRAW-NOT-EXECUTED-CORRECTLY"
        );
    }

    // In case there was a malfunction in contract communication, this
    // function does a correction based on the users current pool tokens
    function manualCorrectPool(address _user) external {
        uint256 currentTokens = xgtpair.balanceOf(_user);
        if (userPoolTokens[_user] != currentTokens) {
            if (userPoolTokens[_user] > currentTokens) {
                uint256 diff = userPoolTokens[_user].sub(currentTokens);
                _stopGeneration(diff, _user);
            } else {
                uint256 diff = currentTokens.sub(userPoolTokens[_user]);
                _startGeneration(diff, _user, xgtGenerationRatePool);
            }
        }
    }

    // In case the bridge was not working/malfunctioned, anyone can call a function
    // on mainnet to correct this in a trustless way
    function manualCorrectDeposit(uint256 _daiBalance, address _user) external {
        require(msg.sender == address(bridge), "XGTSTAKE-NOT-BRIDGE");
        require(
            bridge.messageSender() == stakingContractMainnet,
            "XGTSTAKE-NOT-MAINNET-CONTRACT"
        );
        if (userDAITokens[_user] != _daiBalance) {
            if (userDAITokens[_user] > _daiBalance) {
                uint256 diff = userDAITokens[_user].sub(_daiBalance);
                _stopGeneration(diff, _user);
            } else {
                uint256 diff = _daiBalance.sub(userDAITokens[_user]);
                _startGeneration(diff, _user, xgtGenerationRatePool);
            }
        }
    }

    function claimXGT(address _user) public onlyIfNotPaused {
        uint256 xgtToClaim = getUnclaimedXGT(_user);
        if (xgtToClaim > 0) {
            require(xgt.mint(_user, xgtToClaim), "XGTSTAKE-MINT-FAILED");
        }

        specificUserDeposits[_user].lastTimeClaimed = now;
    }

    function getUnclaimedXGT(address _user) public view returns (uint256) {
        uint256 diffTime = now.sub(specificUserDeposits[_user].lastTimeClaimed);

        uint256 unclaimedXGT = 0;
        for (
            uint256 i = 0;
            i < specificUserDeposits[_user].deposits.length;
            i++
        ) {
            unclaimedXGT = unclaimedXGT.add(
                specificUserDeposits[_user].deposits[i]
                    .amount
                    .mul(specificUserDeposits[_user].deposits[i].generationRate)
                    .div(10**18)
                    .mul(diffTime)
            );
        }

        return unclaimedXGT;
    }

    modifier onlyIfNotPaused() {
        if (!paused) {
            _;
        }
    }
}
