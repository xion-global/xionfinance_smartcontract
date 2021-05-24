pragma solidity ^0.5.16;

import "@openzeppelin/openzeppelin-contracts-upgradeable/contracts/math/SafeMath.sol";
import "@openzeppelin/openzeppelin-contracts-upgradeable/contracts/ownership/Ownable.sol";
import "../interfaces/IBridgeContract.sol";
import "../interfaces/IXGTToken.sol";
import "../interfaces/IUniswapV2Pair.sol";

contract XGTGenerator is Initializable, Ownable {
    using SafeMath for uint256;

    IBridgeContract public bridge;
    IXGTToken public xgt;
    IUniswapV2Pair public xgtpair;

    mapping(address => bool) public stakingContractsMainnet;
    address public poolRouterContract;

    uint256 public xgtGenerationRateStake;
    uint256 public xgtGenerationRatePool;

    uint256 public xgtGenerationFunds;

    bool public paused;

    mapping(address => UserDeposits) public specificUserDeposits;
    mapping(address => uint256) public totalUserDeposit;
    mapping(address => uint256) internal userPoolTokens;
    mapping(address => uint256) internal userDAITokens;
    uint256 public totalDeposits;

    mapping(address => bool) public authorizedAddress;

    struct UserDeposits {
        uint256 lastTimeClaimed;
        DepositPerRate[] deposits;
    }

    struct DepositPerRate {
        uint256 amount;
        uint256 generationRate;
    }

    function initializeGenerator(
        address _bridge,
        address _stakingContractMainnet,
        address _xgt,
        address _poolRouter,
        address _xgtPair,
        uint256 _initialxgtGenerationRateStake,
        uint256 _initialxgtGenerationRatePool,
        uint256 _generationFunds
    ) public {
        require(
            poolRouterContract == address(0),
            "XGTGENERATOR-ALREADY-INITIALIZED"
        );
        bridge = IBridgeContract(_bridge);
        xgt = IXGTToken(_xgt);
        poolRouterContract = _poolRouter;
        xgtpair = IUniswapV2Pair(_xgtPair);
        stakingContractsMainnet[_stakingContractMainnet] = true;
        xgtGenerationRateStake = _initialxgtGenerationRateStake;
        xgtGenerationRatePool = _initialxgtGenerationRatePool;
        xgtGenerationFunds = _generationFunds;
        require(
            xgt.balanceOf(address(this)) == xgtGenerationFunds,
            "XGTGEN-FUNDS-MISMATCH"
        );
    }

    function toggleAuthorizedAddress(address _address, bool _authorized)
        external
        onlyOwner
    {
        authorizedAddress[_address] = _authorized;
    }

    function togglePauseContract(bool _pause) external onlyOwner {
        paused = _pause;
    }

    function updateMainnetContracts(
        address _stakingContractMainnet,
        bool _active
    ) external onlyOwner {
        stakingContractsMainnet[_stakingContractMainnet] = _active;
    }

    function updatexgtGenerationRateStake(uint256 _newxgtGenerationRateStake)
        external
        onlyOwner
    {
        xgtGenerationRateStake = _newxgtGenerationRateStake;
    }

    function updatexgtGenerationRatePool(uint256 _newxgtGenerationRatePool)
        external
        onlyOwner
    {
        xgtGenerationRatePool = _newxgtGenerationRatePool;
    }

    function addGenerationFunds(uint256 _amount) external onlyOwner {
        require(
            xgt.transferFrom(msg.sender, address(this), _amount),
            "XGTGEN-FAILED-TRANSFER"
        );
        xgtGenerationFunds = xgtGenerationFunds.add(_amount);
    }

    function updateXGTPair(address _newXGTPair) external onlyOwner {
        xgtpair = IUniswapV2Pair(_newXGTPair);
    }

    function tokensStaked(uint256 _amount, address _user)
        external
        onlyIfNotPaused
    {
        require(msg.sender == address(bridge), "XGTGEN-NOT-BRIDGE");
        require(
            stakingContractsMainnet[bridge.messageSender()],
            "XGTGEN-NOT-MAINNET-CONTRACT"
        );
        userDAITokens[_user] = userDAITokens[_user].add(_amount);
        _startGeneration(_amount, _user, xgtGenerationRateStake);
    }

    function _startGeneration(
        uint256 _amount,
        address _user,
        uint256 _rate
    ) internal {
        if (_amount > 0) {
            claimXGT(_user);

            totalUserDeposit[_user] = totalUserDeposit[_user].add(_amount);
            totalDeposits = totalDeposits.add(_amount);

            if (specificUserDeposits[_user].deposits.length != 0) {
                uint256 lastItem =
                    specificUserDeposits[_user].deposits.length.sub(1);

                if (
                    specificUserDeposits[_user].deposits[lastItem]
                        .generationRate == _rate
                ) {
                    specificUserDeposits[_user].deposits[lastItem]
                        .amount = specificUserDeposits[_user].deposits[lastItem]
                        .amount
                        .add(_amount);
                    return;
                }
            }
            // In case the user doesn't have any deposits yet this will not be
            // set by claimXGT()
            specificUserDeposits[_user].lastTimeClaimed = now;

            specificUserDeposits[_user].deposits.push(
                DepositPerRate(_amount, _rate)
            );
        }
    }

    function tokensUnstaked(uint256 _amount, address _user)
        external
        onlyIfNotPaused
    {
        require(msg.sender == address(bridge), "XGTGEN-NOT-BRIDGE");
        require(
            stakingContractsMainnet[bridge.messageSender()],
            "XGTGEN-NOT-MAINNET-CONTRACT"
        );

        userDAITokens[_user] = userDAITokens[_user].sub(_amount);
        _stopGeneration(_amount, _user);
    }

    function _stopGeneration(uint256 _amount, address _user) internal {
        if (_amount > 0) {
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
                    remainingAmount = remainingAmount.sub(
                        specificUserDeposits[_user].deposits[i].amount
                    );
                    specificUserDeposits[_user].deposits[i].amount = 0;
                }

                // If this entry doesn't have anything left, delete the array entry
                if (specificUserDeposits[_user].deposits[i].amount == 0) {
                    delete specificUserDeposits[_user].deposits[i];
                    specificUserDeposits[_user]
                        .deposits
                        .length = specificUserDeposits[_user]
                        .deposits
                        .length
                        .sub(1);
                }

                // If we are finished, break the loop
                if (remainingAmount == 0) {
                    break;
                }
            }

            // Just in case, remaining amount should be zero now
            require(
                remainingAmount == 0,
                "XGTGEN-WITHDRAW-NOT-EXECUTED-CORRECTLY"
            );
        }
    }

    // Provides the generator contract with the amount of Normalized-LP-Tokens
    // 1 Normalized LP Token = $1 of value in the LP
    function updatePoolBalanceOfUser(
        address _user,
        uint256 _nlp,
        bool _reset
    ) external {
        require(authorizedAddress[msg.sender], "XGTGEN-NOT-AUTHORIZED");

        if (_reset) {
            resetPoolBalanceOfUser(_user);
        }

        // If the value has changed since last time
        if (userPoolTokens[_user] != _nlp) {
            // If new amount is less than the current one
            if (userPoolTokens[_user] > _nlp || _nlp == 0) {
                _stopGeneration(
                    (totalUserDeposit[_user].sub(userDAITokens[_user])).sub(
                        _nlp
                    ),
                    _user
                );
            } else {
                // If the new amount is bigger than the current one
                uint256 diff =
                    _nlp.sub(totalUserDeposit[_user].sub(userDAITokens[_user]));
                _startGeneration(diff, _user, xgtGenerationRatePool);
            }
            userPoolTokens[_user] = _nlp;
        }
    }

    // Due to an earlier bug we had some leftover issues in our data, which we
    // fix through calling this function to clean any wrong values before
    // setting the correct one.
    function resetPoolBalanceOfUser(address _user) internal {
        if (specificUserDeposits[_user].deposits.length > 0) {
            claimXGT(_user);

            // Get all of the users tokens
            uint256 totalTokens =
                userPoolTokens[_user].add(userDAITokens[_user]);

            // Remove them from the general counters
            totalDeposits = totalDeposits.sub(totalTokens);
            totalUserDeposit[_user] = 0;
            userPoolTokens[_user] = 0;

            // Clean array by setting the length to zero,
            // essentially resetting it
            specificUserDeposits[_user].deposits.length = 0;

            // If user has dai tokens staked, restart generation for these
            // Note: Pool token generation will restart anyways through the
            // calling function
            if (userDAITokens[_user] > 0) {
                _startGeneration(
                    userDAITokens[_user],
                    _user,
                    xgtGenerationRateStake
                );
            }
        }
    }

    // In case the bridge was not working/malfunctioned, anyone can call a function
    // on mainnet to correct this in a trustless way
    function manualCorrectDeposit(uint256 _daiBalance, address _user) external {
        require(msg.sender == address(bridge), "XGTGEN-NOT-BRIDGE");
        require(
            stakingContractsMainnet[bridge.messageSender()],
            "XGTGEN-NOT-MAINNET-CONTRACT"
        );
        if (userDAITokens[_user] != _daiBalance) {
            if (userDAITokens[_user] > _daiBalance) {
                uint256 diff = userDAITokens[_user].sub(_daiBalance);
                _stopGeneration(diff, _user);
            } else {
                uint256 diff = _daiBalance.sub(userDAITokens[_user]);
                _startGeneration(diff, _user, xgtGenerationRatePool);
            }
            userDAITokens[_user] = _daiBalance;
        }
    }

    function claimXGT(address _user) public onlyIfNotPaused {
        if (specificUserDeposits[_user].deposits.length != 0) {
            uint256 xgtToClaim = getUnclaimedXGT(_user);
            if (xgtToClaim > 0 && xgtGenerationFunds >= xgtToClaim) {
                require(
                    xgt.transfer(_user, xgtToClaim),
                    "XGTGEN-TRANSFER-FAILED"
                );
                specificUserDeposits[_user].lastTimeClaimed = now;
            }
        }
    }

    function getUnclaimedXGT(address _user) public view returns (uint256) {
        require(
            specificUserDeposits[_user].lastTimeClaimed > 0,
            "XGTGEN-INVALID-CLAIM-TIME"
        );

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
                    .mul(diffTime)
                    .div(10**18)
            );
        }

        return unclaimedXGT;
    }

    function getUserPoolTokens(address _user) public view returns (uint256) {
        return userPoolTokens[_user];
    }

    function getUserStakeTokens(address _user) public view returns (uint256) {
        return userDAITokens[_user];
    }

    modifier onlyIfNotPaused() {
        if (!paused) {
            _;
        }
    }
}
