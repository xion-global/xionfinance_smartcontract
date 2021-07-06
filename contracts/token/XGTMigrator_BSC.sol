// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "../interfaces/IUniswapFactory.sol";

contract XGTMigratorBSC {
    using SafeMath for uint256;

    mapping(address => bool) public controllers;

    ERC20Burnable public oldToken;
    IERC20 public newToken;

    uint256 public exchangeRate = 650;
    uint256 public lastPriceV1 = 130000000000000000;
    uint256 public startTime = 1625673600;

    constructor(
        address _oldToken,
        address _newToken,
        address _controller
    ) {
        oldToken = ERC20Burnable(_oldToken);
        newToken = IERC20(_newToken);
        controllers[_controller] = true;
    }

    function toggleControllers(address _controller, bool _state)
        external
        onlyController
    {
        controllers[_controller] = _state;
    }

    // if any xgt is left we can free it
    function sweepXGT() external onlyController {
        newToken.transfer(msg.sender, newToken.balanceOf(address(this)));
    }

    function migrate() external {
        _migrateOnlyXGT(msg.sender, msg.sender);
    }

    function migrateTo(address _receiver) external {
        _migrateOnlyXGT(msg.sender, _receiver);
    }

    function _migrateOnlyXGT(address _from, address _to) internal {
        require(
            block.timestamp >= startTime && tokenHasBeenListed(),
            "MIGRATOR-NOT-OPENED-YET"
        );
        uint256 finalReturnXGT = 0;

        // XGT TOKEN
        // Check whether user has XGT v1
        uint256 migrationAmountXGT =
            oldToken.allowance(msg.sender, address(this));
        uint256 balanceXGT = oldToken.balanceOf(msg.sender);
        if (balanceXGT < migrationAmountXGT) {
            migrationAmountXGT = balanceXGT;
        }

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

        require(
            newToken.transfer(_to, finalReturnXGT),
            "MIGRATOR-TRANSFER-NEW-TOKEN-FAILED"
        );
    }

    function setLastPriceV1(uint256 _lastPriceV1) external onlyController {
        // for the input
        // e.g. $0.13 per XGT would be 130000000000000000 (0.13 * 10^18)
        lastPriceV1 = _lastPriceV1;
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
            IUniswapV2Factory(0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73);
        address wBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
        address pair = exchangeFactory.getPair(address(newToken), wBNB);
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
