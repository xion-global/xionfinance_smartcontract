// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "../interfaces/IUniswapV2Router02.sol";

contract XGTMigrator {
    using SafeMath for uint256;

    mapping(address => bool) public controllers;

    ERC20Burnable public oldToken;
    IERC20 public newToken;

    IUniswapV2Pair[] public pools;
    mapping(address => IUniswapV2Router02) public routers;

    IUniswapV2Router02 public newRouter;
    address public newPool;

    uint256 exchangeRate = 200;
    uint256 startTime = 0; // TODO set time correctly after it's known

    constructor(
        address _oldToken,
        address _newToken,
        address[] memory _pools,
        address[] memory _routers,
        address _newRouter,
        address _newPool,
        address _controller
    ) {
        oldToken = ERC20Burnable(_oldToken);
        newToken = IERC20(_newToken);
        require(
            _pools.length == _routers.length,
            "MIGRATOR-INVALID-ARRAY-LENGTH"
        );
        for (uint256 i = 0; i < _pools.length; i++) {
            pools.push(IUniswapV2Pair(_pools[i]));
            routers[_pools[i]] = IUniswapV2Router02(_routers[i]);
            IERC20(_pools[i]).approve(_routers[i], 2**256 - 1);
        }
        newRouter = IUniswapV2Router02(_newRouter);
        newPool = _newPool;
        controllers[_controller] = true;
    }

    function toggleControllers(address _controller, bool _state)
        external
        onlyController
    {
        controllers[_controller] = _state;
    }

    function fundContract(uint256 _amount) external {
        require(
            newToken.transferFrom(msg.sender, address(this), _amount),
            "MIGRATOR-TRANSFER-FAILED"
        );
    }

    // function any left overv2 token after migration to get it back
    // into the vesting contract
    function defundContract(uint256 _amount) external onlyController {
        require(
            newToken.transfer(msg.sender, _amount),
            "MIGRATOR-TRANSFER-FAILED"
        );
    }

    // if any base currency gets stuck we can free it
    function sweepBase(uint256 _amount) external onlyController {
        msg.sender.transfer(_amount);
    }

    fallback() external payable {}

    receive() external payable {}

    function migrate(bool _migrateLP) external {
        if (_migrateLP) {
            _migrateWithLP();
        } else {
            _migrateOnlyXGT(msg.sender, msg.sender);
        }
    }

    function migrateTo(address _receiver) external {
        _migrateOnlyXGT(msg.sender, _receiver);
    }

    function migrateFor(address _from) external onlyController {}

    function _migrateWithLP() internal {
        require(block.timestamp >= startTime, "MIGRATOR-NOT-OPENED-YET");
        uint256 finalReturnXGT = 0;
        uint256 finalReturnBase = 0;

        // LIQUIDITY POOLS
        uint256 XGTFromLPs = 0;
        uint256 baseFromLPs = 0;
        for (uint256 i = 0; i < pools.length; i++) {
            // check if there are lp tokens with allowance for this contract
            uint256 lpTokens = pools[i].allowance(msg.sender, address(this));
            if (lpTokens > 0) {
                // check the balance (take balance if lower)
                uint256 lpBalance = pools[i].balanceOf(msg.sender);
                if (lpBalance > lpTokens) {
                    lpTokens = lpBalance;
                }
                // transfer the lp tokens here
                require(
                    pools[i].transferFrom(msg.sender, address(this), lpTokens),
                    "MIGRATOR-LP-TOKEN-TRANSFER-FAILED"
                );
                // remove liquidity from the pool
                (uint256 oldXGT, uint256 baseToken) =
                    routers[address(pools[i])].removeLiquidityETH(
                        address(oldToken),
                        lpTokens,
                        0,
                        0,
                        address(this),
                        1704063599
                    );
                // store resulting xgt + base token
                XGTFromLPs = XGTFromLPs.add(oldXGT);
                baseFromLPs = baseFromLPs.add(baseToken);
            }
        }

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
                oldToken.transferFrom(
                    msg.sender,
                    address(this),
                    migrationAmountXGT
                ),
                "MIGRATOR-TRANSFER-OLD-TOKEN-FAILED"
            );
        }

        // Add XGT from LPs to the calculation
        migrationAmountXGT = migrationAmountXGT.add(XGTFromLPs);

        // burn and migrate all of their XGT v1 to v2
        if (migrationAmountXGT > 0) {
            oldToken.burn(migrationAmountXGT);
            finalReturnXGT = (migrationAmountXGT.mul(exchangeRate)).div(1000);
        }

        // if there were funds from the lp
        if (baseFromLPs > 0) {
            // calc
            uint256 reserveA = newToken.balanceOf(newPool);
            uint256 reserveB =
                IERC20(address(newRouter.WETH())).balanceOf(newPool);
            uint256 tokenAmount = (baseFromLPs.mul(reserveA)).div(reserveB);
            uint256 thisBase = baseFromLPs;
            if (tokenAmount > finalReturnXGT) {
                thisBase = (baseFromLPs.mul(finalReturnXGT)).div(tokenAmount);
            }
            newToken.approve(address(newRouter), finalReturnXGT);

            // add to the new lp based on the base token amount
            (uint256 xgtUsed, uint256 baseUsed, ) =
                newRouter.addLiquidityETH{value: thisBase}(
                    address(newToken),
                    finalReturnXGT,
                    1,
                    1,
                    msg.sender,
                    1704063599
                );
            // capture the returned xgt and base token amounts
            finalReturnBase = baseFromLPs.sub(baseUsed);
            finalReturnXGT = finalReturnXGT.sub(xgtUsed);
        }

        // if any XGT is left
        if (finalReturnXGT > 0) {
            require(
                newToken.transfer(msg.sender, finalReturnXGT),
                "MIGRATOR-TRANSFER-NEW-TOKEN-FAILED"
            );
        }
        if (finalReturnBase > 0) {
            msg.sender.transfer(finalReturnBase);
        }
    }

    function _migrateOnlyXGT(address _from, address _to) internal {
        require(block.timestamp >= startTime, "MIGRATOR-NOT-OPENED-YET");
        uint256 finalReturnXGT = 0;

        // XGT TOKEN
        // Check whether user has XGT v1
        uint256 migrationAmountXGT = oldToken.balanceOf(_from);

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

    modifier onlyController() {
        require(controllers[msg.sender], "not controller");
        _;
    }
}
