pragma solidity ^0.5.16;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/upgrades/contracts/ownership/Ownable.sol";
import "../interfaces/IBridgeContract.sol";
import "../interfaces/IXGTToken.sol";

contract XGTGenerator is Initializable, OpenZeppelinUpgradesOwnable {
    using SafeMath for uint256;

    IBridgeContract public bridge;
    IXGTToken public xgt;

    address public stakingContractMainnet;
    address public poolRouterContract;

    uint256 public xgtGenerationRateStake;
    uint256 public xgtGenerationRatePool;

    bool public paused = false;

    mapping(address => UserDeposits) public specificUserDeposits;
    mapping(address => uint256) public totalUserDeposit;
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
        uint256 _initialxgtGenerationRateStake,
        uint256 _initialxgtGenerationRatePool
    ) public initializer {
        bridge = IBridgeContract(_bridge);
        xgt = IXGTToken(_xgt);
        poolRouterContract = _poolRouter;
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

        // Claim XGT so the user is not generating more than allowed
        claimXGT(_user);

        totalUserDeposit[_user] = totalUserDeposit[_user].add(_amount);
        totalDeposits = totalDeposits.add(_amount);

        uint256 lastItem = specificUserDeposits[_user].deposits.length.sub(1);
        if (
            specificUserDeposits[_user].deposits[lastItem].generationRate ==
            xgtGenerationRateStake
        ) {
            specificUserDeposits[_user].deposits[lastItem]
                .amount = specificUserDeposits[_user].deposits[lastItem]
                .amount
                .add(_amount);
        } else {
            specificUserDeposits[_user].deposits.push(
                DepositPerRate(_amount, xgtGenerationRateStake)
            );
        }
    }

    function tokensPooled(uint256 _amount, address _user)
        external
        onlyIfNotPaused
    {
        require(msg.sender == poolRouterContract, "XGTSTAKE-NOT-POOL-ROUTER");

        // Claim XGT so the user is not generating more than allowed
        claimXGT(_user);

        totalUserDeposit[_user] = totalUserDeposit[_user].add(_amount);
        totalDeposits = totalDeposits.add(_amount);

        uint256 lastItem = specificUserDeposits[_user].deposits.length.sub(1);
        if (
            specificUserDeposits[_user].deposits[lastItem].generationRate ==
            xgtGenerationRatePool
        ) {
            specificUserDeposits[_user].deposits[lastItem]
                .amount = specificUserDeposits[_user].deposits[lastItem]
                .amount
                .add(_amount);
        } else {
            specificUserDeposits[_user].deposits.push(
                DepositPerRate(_amount, xgtGenerationRatePool)
            );
        }
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

    function tokensUnpooled(uint256 _amount, address _user)
        external
        onlyIfNotPaused
    {
        require(msg.sender == poolRouterContract, "XGTSTAKE-NOT-POOL-ROUTER");

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

    function claimXGT(address _user) public onlyIfNotPaused {
        specificUserDeposits[_user].lastTimeClaimed = now;

        uint256 xgtToClaim = getUnclaimedXGT(_user);

        require(xgt.mint(_user, xgtToClaim), "XGTSTAKE-MINT-FAILED");
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
