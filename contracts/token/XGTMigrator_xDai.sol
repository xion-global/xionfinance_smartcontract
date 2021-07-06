// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "../interfaces/IRewardChest.sol";
import "../interfaces/IUniswapFactory.sol";

contract XGTMigratorXDai {
    using SafeMath for uint256;

    mapping(address => bool) public controllers;

    ERC20Burnable public oldToken;
    IERC20 public newToken;
    IRewardChest public rewardChest;

    uint256 public exchangeRate = 650;
    uint256 public lastPriceV1 = 130000000000000000;
    uint256 public startTime = 1625673600;

    bool public bscWithdrawOnce = false;

    constructor(
        address _oldToken,
        address _newToken,
        address _rewardChest,
        address _controller
    ) {
        oldToken = ERC20Burnable(_oldToken);
        newToken = IERC20(_newToken);
        rewardChest = IRewardChest(_rewardChest);
        controllers[_controller] = true;
    }

    function toggleControllers(address _controller, bool _state)
        external
        onlyController
    {
        controllers[_controller] = _state;
    }

    // if any base currency gets stuck we can free it
    function sweepBase(uint256 _amount) external onlyController {
        msg.sender.transfer(_amount);
    }

    fallback() external payable {}

    receive() external payable {}

    function migrate() external {
        _migrateOnlyXGT(msg.sender, msg.sender);
    }

    function migrateTo(address _receiver) external {
        _migrateOnlyXGT(msg.sender, _receiver);
    }

    function migrateFor(address _from) external onlyController {
        _migrateOnlyXGT(_from, _from);
    }

    function _migrateOnlyXGT(address _from, address _to) internal {
        require(
            block.timestamp >= startTime && tokenHasBeenListed(),
            "MIGRATOR-NOT-OPENED-YET"
        );
        uint256 finalReturnXGT = 0;

        // XGT TOKEN
        // Check whether user has XGT v1
        uint256 migrationAmountXGT = oldToken.balanceOf(msg.sender);

        // If user has v1, transfer them here
        if (migrationAmountXGT > 0) {
            require(
                oldToken.transferFrom(_from, address(this), migrationAmountXGT),
                "MIGRATOR-TRANSFER-OLD-TOKEN-FAILED"
            );
        } else {
            return;
        }

        oldToken.burn(migrationAmountXGT);
        finalReturnXGT = (migrationAmountXGT.mul(exchangeRate)).div(1000);

        rewardChest.sendInstantClaim(_to, finalReturnXGT);
    }

    function setLastPriceV1(uint256 _lastPriceV1) external onlyController {
        // for the input
        // e.g. $0.13 per XGT would be 130000000000000000 (0.13 * 10^18)
        lastPriceV1 = _lastPriceV1;
    }

    function withdrawBSCAmount(uint256 _amount) external onlyController {
        require(!bscWithdrawOnce, "MIGRATOR-ALREADY-WITHDREW-BSC-AMOUNT");
        bscWithdrawOnce = true;
        rewardChest.sendInstantClaim(msg.sender, _amount);
    }

    function updateExchangeRate(uint256 _currentPriceV2, bool _addBonus)
        external
        onlyController
    {
        // for the input
        // e.g. $0.20 per XGT would be 200000000000000000 (0.2 * 10^18)
        exchangeRate = (lastPriceV1.mul(1000)).div(_currentPriceV2);
        if (_addBonus) {
            exchangeRate = exchangeRate.mul(105).div(100);
        }
    }

    modifier onlyController() {
        require(controllers[msg.sender], "not controller");
        _;
    }

    // function which determines whether a certain pair has been listed
    // and funded on a uniswap-v2-based dex. This is to ensure for the
    // public sale distribution to only happen after this is the case
    function tokenHasBeenListed() public view returns (bool) {
        IUniswapV2Factory exchangeFactory =
            IUniswapV2Factory(0xA818b4F111Ccac7AA31D0BCc0806d64F2E0737D7);
        address wXDAI = 0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d;
        address pair = exchangeFactory.getPair(address(newToken), wXDAI);
        // if the factory returns the 0-address, it hasn't been created
        if (pair == address(0)) {
            return false;
        }
        // if it was created, only return true if the xgt balance is
        // greater than zero == has been funded
        if (newToken.balanceOf(pair) > 0) {
            return true;
        }
        return false;
    }
}
