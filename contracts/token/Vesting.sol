pragma solidity ^0.5.16;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/upgrades/contracts/ownership/Ownable.sol";
import "../interfaces/IXGTToken.sol";

contract Vesting is Initializable, OpenZeppelinUpgradesOwnable {
    using SafeMath for uint256;
    IXGTToken public xgtToken;

    struct Beneficiary {
        uint256 totalTokens;
        uint256 tokensLeft;
        uint256 claimedTokens;
        uint256 intervalNumber;
    }

    mapping(address => Beneficiary) internal beneficiary;
    address[] internal beneficiaries;

    uint256 public deployment; // Time of deployment of this contract
    uint256 public constant trancheIntervals = (365 * 24 * 60 * 60) / 12; // 1 Month in Seconds
    uint256 public constant totalIntervals = 24; // Spread over 24 months
    uint256 public totalVestedTokens;

    bool internal tokensReceived = false;

    function initialize(
        address _tokenContract,
        address[] memory _beneficiaries,
        uint256[] memory _amounts
    ) public initializer {
        require(
            _beneficiaries.length == _amounts.length,
            "VESTING-ARRAY-LENGTH-MISMATCH"
        );
        xgtToken = IXGTToken(_tokenContract);
        deployment = now;
        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            beneficiary[_beneficiaries[i]] = Beneficiary(_amounts[i], 0, 0, 0);
            beneficiaries.push(_beneficiaries[i]);
            totalVestedTokens = totalVestedTokens.add(_amounts[i]);
        }
    }

    function addTokens() external {
        require(!tokensReceived, "VESTING-TOKENS-ALREADY-RECEIVED");
        require(
            xgtToken.transferFrom(msg.sender, address(this), totalVestedTokens),
            "VESTING-TRANSFER-FAILED"
        );
        require(
            xgtToken.balanceOf(address(this)) == totalVestedTokens,
            "VESTING-INIT-FAILED"
        );
        tokensReceived = true;
    }

    function addBeneficiary(address _newBeneficiary, uint256 _amount) external {
        require(_amount > 0, "VESTING-CANT-VEST-ZERO-AMOUNT");
        require(
            xgtToken.transferFrom(msg.sender, address(this), _amount),
            "VESTING-TRANSFER-FAILED"
        );

        totalVestedTokens = totalVestedTokens.add(_amount);
        beneficiary[_newBeneficiary] = Beneficiary(_amount, 0, 0, 0);
        beneficiaries.push(_newBeneficiary);
        claim(_newBeneficiary);
    }

    function claim(address _beneficiary) public {
        require(
            beneficiary[_beneficiary].totalTokens > 0,
            "VESTING-BENEFICIARY-DOESNT-EXIST"
        );

        uint256 currentInterval = (now.sub(deployment)).div(trancheIntervals);

        if (currentInterval <= beneficiary[_beneficiary].intervalNumber) {
            return;
        }

        uint256 claimedAmount = 0;
        if (currentInterval == totalIntervals) {
            claimedAmount = beneficiary[_beneficiary].tokensLeft;
            beneficiary[_beneficiary].intervalNumber = totalIntervals;
            beneficiary[_beneficiary].claimedTokens = beneficiary[_beneficiary]
                .claimedTokens
                .add(beneficiary[_beneficiary].tokensLeft);
            beneficiary[_beneficiary].tokensLeft = 0;
            require(
                beneficiary[_beneficiary].totalTokens ==
                    beneficiary[_beneficiary].claimedTokens.add(
                        beneficiary[_beneficiary].tokensLeft
                    ),
                "VESTING-SUM-MISMATCH"
            );
        } else {
            uint256 intervalDiff =
                currentInterval.sub(beneficiary[_beneficiary].intervalNumber);
            beneficiary[_beneficiary].intervalNumber = currentInterval;
            uint256 amountPerInterval =
                beneficiary[_beneficiary].totalTokens.div(totalIntervals);
            claimedAmount = amountPerInterval.mul(intervalDiff);
            beneficiary[_beneficiary].claimedTokens = beneficiary[_beneficiary]
                .claimedTokens
                .add(claimedAmount);
            beneficiary[_beneficiary].tokensLeft = beneficiary[_beneficiary]
                .tokensLeft
                .sub(claimedAmount);
            xgtToken.transfer(_beneficiary, claimedAmount);
        }
        require(
            xgtToken.transfer(_beneficiary, claimedAmount),
            "VESTING-TRANSFER-FAILED"
        );
    }

    function claimAll() external {
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            claim(beneficiaries[i]);
        }
    }

    function updateAddress(address _old, address _new) external {
        require(
            beneficiary[_old].totalTokens > 0,
            "VESTING-BENEFICIARY-DOESNT-EXIST"
        );
        beneficiary[_new] = Beneficiary(
            beneficiary[_old].totalTokens,
            beneficiary[_old].tokensLeft,
            beneficiary[_old].claimedTokens,
            beneficiary[_old].intervalNumber
        );
        beneficiary[_old] = Beneficiary(0, 0, 0, 0);

        for (uint256 i = 0; i < beneficiaries.length; i++) {
            if (beneficiaries[i] == _old) {
                beneficiaries[i] = _new;
                break;
            }
        }
    }
}
