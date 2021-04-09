pragma solidity ^0.5.16;

import "@openzeppelin/openzeppelin-contracts-upgradeable/contracts/math/SafeMath.sol";
import "@openzeppelin/openzeppelin-contracts-upgradeable/contracts/ownership/Ownable.sol";
import "../interfaces/IXGTToken.sol";

contract Vesting is Initializable, Ownable {
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
    uint256 public constant TRANCHE_INTERVAL = (365 * 24 * 60 * 60) / 12; // 1 Month in Seconds
    uint256 public constant TOTAL_INTERVALS = 24; // Spread over 24 months

    uint256 public totalVestedTokens;

    uint256 public undistributedTokenInterval;

    uint256 public totalUndistributedCommunityTokens;
    uint256 public totalUnlockedCommunityTokens;
    uint256 public distributedCommunityTokens;

    uint256 public totalUndistributedTeamTokens;
    uint256 public totalUnlockedTeamTokens;
    uint256 public distributedTeamTokens;

    function initializeVesting(
        address _tokenContract,
        address[] memory _beneficiaries,
        uint256 _reserveAmount,
        uint256[] memory _amountsFounders,
        uint256[] memory _amountsTeam,
        uint256[] memory _amountsCommunity,
        uint256 _undistributedTeamTokens,
        uint256 _undistributedCommunityTokens,
        address _owner
    ) public returns (bool) {
        require(deployment == 0, "VESTING-ALREADY-INITIALIZED");
        require(
            _beneficiaries.length ==
                _amountsFounders
                    .length
                    .add(_amountsTeam.length)
                    .add(_amountsCommunity.length)
                    .add(1),
            "VESTING-ARRAY-LENGTH-MISMATCH"
        );
        _transferOwnership(_owner);
        xgtToken = IXGTToken(_tokenContract);
        deployment = now;

        uint256 index = 0;
        beneficiary[_beneficiaries[index]] = Beneficiary(
            _reserveAmount,
            _reserveAmount,
            0,
            0
        );
        totalVestedTokens = totalVestedTokens.add(_reserveAmount);
        index = index.add(1);

        for (uint256 i = 0; i < _amountsFounders.length; i++) {
            beneficiary[_beneficiaries[index + i]] = Beneficiary(
                _amountsFounders[i],
                _amountsFounders[i],
                0,
                0
            );
            beneficiaries.push(_beneficiaries[index + i]);
            totalVestedTokens = totalVestedTokens.add(_amountsFounders[i]);
        }
        index = index.add(_amountsFounders.length);

        for (uint256 i = 0; i < _amountsTeam.length; i++) {
            beneficiary[_beneficiaries[index + i]] = Beneficiary(
                _amountsTeam[i],
                _amountsTeam[i],
                0,
                0
            );
            beneficiaries.push(_beneficiaries[index + i]);
            totalVestedTokens = totalVestedTokens.add(_amountsTeam[i]);
        }
        index = index.add(_amountsTeam.length);

        for (uint256 i = 0; i < _amountsCommunity.length; i++) {
            beneficiary[_beneficiaries[index + i]] = Beneficiary(
                _amountsCommunity[i],
                _amountsCommunity[i],
                0,
                0
            );
            beneficiaries.push(_beneficiaries[index + i]);
            totalVestedTokens = totalVestedTokens.add(_amountsCommunity[i]);
        }

        totalVestedTokens = totalVestedTokens
            .add(_undistributedCommunityTokens)
            .add(_undistributedTeamTokens);

        totalUndistributedCommunityTokens = _undistributedCommunityTokens;
        totalUndistributedTeamTokens = _undistributedTeamTokens;

        require(
            xgtToken.balanceOf(address(this)) == totalVestedTokens,
            "VESTING-TOKENS-MISMATCH"
        );
        claimAll();
        return true;
    }

    function distributeTeamTokens(address _receiver, uint256 _amount)
        external
        onlyOwner
    {
        require(_amount > 0, "VESTING-CANT-VEST-ZERO-AMOUNT");
        require(
            freeTeamTokens() >= _amount,
            "VESTING-NOT-ENOUGH-TEAM-TOKENS-UNLOCKED"
        );

        distributedTeamTokens = distributedTeamTokens.add(_amount);
        require(
            xgtToken.transfer(_receiver, _amount),
            "VESTING-TRANSFER-FAILED"
        );
    }

    function distributeCommunityTokens(address _receiver, uint256 _amount)
        external
        onlyOwner
    {
        require(_amount > 0, "VESTING-CANT-VEST-ZERO-AMOUNT");
        require(
            freeCommunityTokens() >= _amount,
            "VESTING-NOT-ENOUGH-COMMUNITY-TOKENS-UNLOCKED"
        );

        distributedCommunityTokens = distributedCommunityTokens.add(_amount);
        require(
            xgtToken.transfer(_receiver, _amount),
            "VESTING-TRANSFER-FAILED"
        );
    }

    function claim(address _beneficiary) public {
        require(
            _beneficiary == msg.sender || msg.sender == owner(),
            "VESTING-NOT-AUTHORIZED"
        );
        require(
            beneficiary[_beneficiary].totalTokens > 0,
            "VESTING-BENEFICIARY-DOESNT-EXIST"
        );

        uint256 currentInterval =
            ((now.sub(deployment)).div(TRANCHE_INTERVAL)).add(1);

        if (currentInterval <= beneficiary[_beneficiary].intervalNumber) {
            return;
        }

        uint256 claimedAmount = getUnclaimedTokens(_beneficiary);
        beneficiary[_beneficiary].claimedTokens = beneficiary[_beneficiary]
            .claimedTokens
            .add(claimedAmount);
        beneficiary[_beneficiary].intervalNumber = currentInterval;
        beneficiary[_beneficiary].tokensLeft = beneficiary[_beneficiary]
            .tokensLeft
            .sub(claimedAmount);
        require(
            beneficiary[_beneficiary].totalTokens ==
                beneficiary[_beneficiary].tokensLeft.add(
                    beneficiary[_beneficiary].claimedTokens
                ),
            "VESTING-MISMATCH"
        );
        require(
            xgtToken.transfer(_beneficiary, claimedAmount),
            "VESTING-TRANSFER-FAILED"
        );
    }

    function claimAll() public onlyOwner {
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            claim(beneficiaries[i]);
        }
        unlockTokens();
    }

    function unlockTokens() public {
        uint256 currentInterval =
            ((now.sub(deployment)).div(TRANCHE_INTERVAL)).add(1);

        if (currentInterval <= undistributedTokenInterval) {
            return;
        }

        uint256 unlockedAmountTeam = 0;
        uint256 unlockedAmountCommunity = 0;
        if (currentInterval >= TOTAL_INTERVALS) {
            unlockedAmountTeam = totalUndistributedTeamTokens.sub(
                totalUnlockedTeamTokens
            );
            unlockedAmountCommunity = totalUndistributedCommunityTokens.sub(
                totalUnlockedCommunityTokens
            );
            totalUnlockedTeamTokens = totalUndistributedTeamTokens;
            totalUnlockedCommunityTokens = totalUndistributedCommunityTokens;
            undistributedTokenInterval = TOTAL_INTERVALS;
        } else {
            uint256 intervalDiff =
                currentInterval.sub(undistributedTokenInterval);
            undistributedTokenInterval = currentInterval;
            uint256 amountTeam =
                (totalUndistributedTeamTokens.mul(intervalDiff)).div(
                    TOTAL_INTERVALS
                );
            uint256 amountCommunity =
                (totalUndistributedCommunityTokens.mul(intervalDiff)).div(
                    TOTAL_INTERVALS
                );
            totalUnlockedCommunityTokens = totalUnlockedCommunityTokens.add(
                amountCommunity
            );
            totalUnlockedTeamTokens = totalUnlockedTeamTokens.add(amountTeam);
        }
    }

    function updateAddress(address _old, address _new) external onlyOwner {
        require(
            beneficiary[_old].totalTokens > 0,
            "VESTING-BENEFICIARY-DOESNT-EXIST"
        );
        require(
            beneficiary[_new].totalTokens == 0,
            "VESTING-BENEFICIARY-ALREADY-EXISTS"
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

    function increaseVestedAmount(
        address _address,
        uint256 _amount,
        bool _team,
        bool _community
    ) external onlyOwner {
        require(
            _amount > beneficiary[_address].totalTokens,
            "VESTING-AMOUNT-NOT-CHANGED"
        );
        require(_team || _community, "VESTING-INCORRECT-INPUT");

        uint256 diff = _amount.sub(beneficiary[_address].totalTokens);

        if (_team) {
            require(diff <= freeTeamTokens(), "VESTING-NOT-ENOUGH-TOKENS-FREE");
            distributedTeamTokens = distributedTeamTokens.add(diff);
        } else if (_community) {
            require(
                diff <= freeCommunityTokens(),
                "VESTING-NOT-ENOUGH-TOKENS-FREE"
            );
            distributedCommunityTokens = distributedCommunityTokens.add(diff);
        }

        beneficiary[_address].totalTokens = _amount;
        uint256 amountNow =
            diff.mul(beneficiary[_address].intervalNumber).div(TOTAL_INTERVALS);
        beneficiary[_address].claimedTokens = beneficiary[_address]
            .claimedTokens
            .add(amountNow);
        beneficiary[_address].tokensLeft = beneficiary[_address]
            .totalTokens
            .sub(beneficiary[_address].claimedTokens);
        require(
            xgtToken.transfer(_address, amountNow),
            "VESTING-TRANSFER-FAILED"
        );
    }

    function getUnclaimedTokens(address _address)
        public
        view
        returns (uint256)
    {
        uint256 currentInterval =
            ((now.sub(deployment)).div(TRANCHE_INTERVAL)).add(1);

        if (
            currentInterval <= beneficiary[_address].intervalNumber ||
            beneficiary[_address].tokensLeft == 0
        ) {
            return 0;
        }

        uint256 claimableAmount = 0;
        if (currentInterval >= TOTAL_INTERVALS) {
            claimableAmount = beneficiary[_address].tokensLeft;
        } else {
            uint256 intervalDiff =
                currentInterval.sub(beneficiary[_address].intervalNumber);
            uint256 amountPerInterval =
                beneficiary[_address].totalTokens.div(TOTAL_INTERVALS);
            claimableAmount = amountPerInterval.mul(intervalDiff);
        }

        if (claimableAmount > beneficiary[_address].tokensLeft) {
            claimableAmount = beneficiary[_address].tokensLeft;
        }

        return claimableAmount;
    }

    function getTotalTokens(address _address) external view returns (uint256) {
        return beneficiary[_address].totalTokens;
    }

    function getClaimedTokens(address _address)
        external
        view
        returns (uint256)
    {
        return beneficiary[_address].claimedTokens;
    }

    function getTimeTilNextIteration() external view returns (uint256) {
        uint256 timeDiff = now.sub(deployment);
        uint256 nextInterval = undistributedTokenInterval.mul(TRANCHE_INTERVAL);
        if (timeDiff < nextInterval) {
            return nextInterval.sub(timeDiff);
        }
        return 0;
    }

    function freeTeamTokens() public view returns (uint256) {
        return totalUnlockedTeamTokens.sub(distributedTeamTokens);
    }

    function freeCommunityTokens() public view returns (uint256) {
        return totalUnlockedCommunityTokens.sub(distributedCommunityTokens);
    }

    function getBeneficiaryByIndex(uint256 _index)
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
            beneficiary[beneficiaries[_index]].totalTokens,
            beneficiary[beneficiaries[_index]].tokensLeft,
            beneficiary[beneficiaries[_index]].claimedTokens,
            beneficiary[beneficiaries[_index]].intervalNumber
        );
    }

    function getBeneficiaryByAddress(address _address)
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
            beneficiary[_address].totalTokens,
            beneficiary[_address].tokensLeft,
            beneficiary[_address].claimedTokens,
            beneficiary[_address].intervalNumber
        );
    }
}
