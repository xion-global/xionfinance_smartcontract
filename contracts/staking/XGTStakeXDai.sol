pragma solidity ^0.5.16;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/upgrades/contracts/ownership/Ownable.sol";
import "../interfaces/IBridgeContract.sol";
import "../interfaces/IXGTToken.sol";

contract XGTStakeXDai is Initializable, OpenZeppelinUpgradesOwnable {
    using SafeMath for uint256;

    IBridgeContract public bridge;
    IXGTToken public xgt;

    address public stakingContractMainnet;

    uint256 public xgtGenerationRate;

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
        uint256 _initialXGTGenerationRate
    ) public initializer {
        bridge = IBridgeContract(_bridge);
        xgt = IXGTToken(_xgt);
        stakingContractMainnet = _stakingContractMainnet;
        xgtGenerationRate = _initialXGTGenerationRate;
    }

    function pauseContracts(bool _pause) public onlyOwner {
        paused = _pause;
    }

    function updateXGTGenerationRate(uint256 _newXGTGenerationRate)
        public
        onlyOwner
    {
        xgtGenerationRate = _newXGTGenerationRate;
    }

    function tokensDeposited(uint256 _amount, address _user)
        external
        notPaused
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
            xgtGenerationRate
        ) {
            specificUserDeposits[_user].deposits[lastItem]
                .amount = specificUserDeposits[_user].deposits[lastItem]
                .amount
                .add(_amount);
        } else {
            specificUserDeposits[_user].deposits.push(
                DepositPerRate(_amount, xgtGenerationRate)
            );
        }
    }

    function tokensWithdrawn(uint256 _amount, address _user)
        external
        notPaused
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

    function claimXGT(address _user) public notPaused {
        specificUserDeposits[_user].lastTimeClaimed = now;

        uint256 xgtToClaim = GetUnclaimedXGT(_user);

        require(xgt.mint(_user, xgtToClaim), "XGTSTAKE-MINT-FAILED");
    }

    function GetUnclaimedXGT(address _user) public view returns (uint256) {
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

    modifier notPaused() {
        require(!paused, "XGTSTAKE-Paused");
        _;
    }
}
