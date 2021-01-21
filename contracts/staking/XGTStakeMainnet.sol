pragma solidity ^0.5.16;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/upgrades/contracts/ownership/Ownable.sol";
import "../interfaces/ICToken.sol";
import "../interfaces/IBridgeContract.sol";
import "../interfaces/IXGTStakeXDai.sol";
import "../interfaces/IPERC20.sol";
import "../interfaces/IChainlinkOracle.sol";

contract XGTStakeMainnet is Initializable, OpenZeppelinUpgradesOwnable {
    using SafeMath for uint256;

    IPERC20 public stakeToken;
    ICToken public cToken;
    IBridgeContract public bridge;
    IChainlinkOracle public gasOracle;
    IChainlinkOracle public ethDaiOracle;

    address public stakingContractXdai;

    bool public paused = false;
    uint256 public averageGasPerDeposit = 150000;
    uint256 public averageGasPerWithdraw = 150000;
    mapping(address => bool) public metaTransactors;

    uint256 public interestCut = 250; // Interest Cut in Basis Points (250 = 2.5%)
    address public interestCutReceiver;

    mapping(address => uint256) public userDepositsDai;
    mapping(address => uint256) public userDepositsCDai;
    uint256 public totalDeposits;

    event Test(uint256 indexed diff, uint256 indexed cut, uint256 rest);

    function initialize(
        address _stakeToken,
        address _cToken,
        address _bridge,
        address _stakingContractXdai
    ) public initializer {
        stakeToken = IPERC20(_stakeToken);
        cToken = ICToken(_cToken);
        bridge = IBridgeContract(_bridge);
        gasOracle = IChainlinkOracle(
            0x169E633A2D1E6c10dD91238Ba11c4A708dfEF37C
        );
        ethDaiOracle = IChainlinkOracle(
            0x773616E4d11A78F511299002da57A0a94577F1f4
        );
        stakingContractXdai = _stakingContractXdai;
        interestCutReceiver = 0xdE8DcD65042db880006421dD3ECA5D94117642d1;
    }

    function changeMetaTxAuth(address _user, bool _allowedToExecute)
        external
        onlyOwner
    {
        metaTransactors[_user] = _allowedToExecute;
    }

    function pauseContracts(bool _pause) external onlyOwner {
        paused = _pause;
    }

    function depositTokens(uint256 _amount) external notPaused {
        _depositTokens(_amount, msg.sender);
    }

    function depositTokensForUser(uint256 _amount, address _user)
        external
        notPaused
    {
        require(metaTransactors[msg.sender], "XGTSTAKE-NOT-ALLOWED");
        //uint256 remainder = refundGas(_amount, _user, averageGasPerDeposit);
        uint256 remainder = _amount;
        _depositTokens(remainder, _user);
    }

    function _depositTokens(uint256 _amount, address _user) internal {
        require(
            stakeToken.transferFrom(_user, address(this), _amount),
            "XGTSTAKE-DAI-TRANSFER-FAILED"
        );
        require(
            stakeToken.approve(address(cToken), _amount),
            "XGTSTAKE-DAI-APPROVE-FAILED"
        );

        uint256 balanceBefore = cToken.balanceOf(address(this));
        require(cToken.mint(_amount) == 0, "XGTSTAKE-COMPOUND-DEPOSIT-FAILED");
        uint256 cDai = cToken.balanceOf(address(this)).sub(balanceBefore);

        userDepositsDai[_user] = userDepositsDai[_user].add(_amount);
        userDepositsCDai[_user] = userDepositsCDai[_user].add(cDai);
        totalDeposits = totalDeposits.add(_amount);

        // bytes4 _methodSelector = IXGTStakeXDai(address(0)).tokensDeposited.selector;
        // bytes memory data = abi.encodeWithSelector(_methodSelector, _amount, _user);
        // bridge.requireToPassMessage(stakingContractXdai,data,300000);
    }

    function withdrawTokensForUser(uint256 _amount, address _user)
        external
        notPaused
    {
        require(metaTransactors[msg.sender], "XGTSTAKE-NOT-ALLOWED");
        // uint256 remainder = refundGas(_amount, _user, averageGasPerWithdraw);
        uint256 remainder = _amount;
        _depositTokens(remainder, _user);
    }

    function withdrawTokens(uint256 _amount) external notPaused {
        _withdrawTokens(_amount, msg.sender);
    }

    function _withdrawTokens(uint256 _amount, address _user) internal {
        uint256 userDepositDai = userDepositsDai[_user];
        uint256 userDepositCDai = userDepositsCDai[_user];
        require(userDepositDai > 0, "XGTSTAKE-NO-DEPOSIT");

        // If user puts in MAX_UINT256, skip this calcualtion
        // and set it to the maximum possible
        uint256 cDaiToRedeem = uint256(2**256 - 1);
        uint256 amount = _amount;
        if (amount != cDaiToRedeem) {
            cDaiToRedeem = userDepositCDai.mul(amount).div(userDepositDai);
        }

        // If the calculation for some reason came up with too much
        // or if the user set to withdraw everything: set max
        if (cDaiToRedeem > userDepositCDai) {
            cDaiToRedeem = userDepositCDai;
            amount = userDepositDai;
        }

        totalDeposits = totalDeposits.sub(amount);
        userDepositsDai[_user] = userDepositDai.sub(amount);
        userDepositsCDai[_user] = userDepositCDai.sub(cDaiToRedeem);

        uint256 before = stakeToken.balanceOf(address(this));
        require(
            cToken.redeem(cDaiToRedeem) == 0,
            "XGTSTAKE-COMPOUND-WITHDRAW-FAILED"
        );
        uint256 diff = (stakeToken.balanceOf(address(this))).sub(before);
        require(diff >= amount, "XGTSTAKE-COMPOUND-AMOUNT-MISMATCH");

        // Deduct the interest cut
        uint256 interest = diff.sub(amount);
        uint256 cut = 0;
        if (interest != 0) {
            cut = (interest.mul(interestCut)).div(10000);
            require(
                stakeToken.transfer(interestCutReceiver, cut),
                "XGTSTAKE-INTEREST-CUT-TRANSFER-FAILED"
            );
        }

        // Transfer the rest to the user
        require(
            stakeToken.transfer(_user, diff.sub(cut)),
            "XGTSTAKE-USER-TRANSFER-FAILED"
        );

        // bytes4 _methodSelector = IXGTStakeXDai(address(0)).tokensWithdrawn.selector;
        // bytes memory data = abi.encodeWithSelector(_methodSelector, _amount, _user);
        // bridge.requireToPassMessage(stakingContractXdai,data,300000);
    }

    function refundGas(
        uint256 _amount,
        address _user,
        uint256 _gasAmount
    ) internal returns (uint256) {
        int256 latestGasPrice = gasOracle.latestAnswer();
        uint256 latestEthPrice =
            uint256(1 ether).div(uint256(ethDaiOracle.latestAnswer()));
        uint256 amount = _amount;
        if (latestGasPrice >= 0 && latestEthPrice >= 0) {
            uint256 refund =
                uint256(latestGasPrice).mul(_gasAmount).mul(latestEthPrice);
            require(refund < _amount, "XGTSTAKE-DEPOSIT-TOO-SMALL");
            amount = _amount.sub(refund);
            require(
                stakeToken.transferFrom(_user, msg.sender, refund),
                "XGTSTAKE-DAI-REFUND-TRANSFER-FAILED"
            );
        }
        return amount;
    }

    modifier notPaused() {
        require(!paused, "XGTSTAKE-Paused");
        _;
    }
}
