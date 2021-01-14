const timeMachine = require('ganache-time-traveler');
const erc20 = artifacts.require("XGTToken");
const Vesting = artifacts.require("Vesting");
const UniswapV2Factory = artifacts.require("UniswapV2Factory");
const UniswapV2Pair = artifacts.require("UniswapV2Pair");
const UniswapV2Router02 = artifacts.require("UniswapV2Router02");
const WETH = artifacts.require("WETH");

const addrController = "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1";

contract('XGT Liquidity Pool', async (accounts) =>  {

    beforeEach(async() => {
        let snapshot = await timeMachine.takeSnapshot();
        snapshotId = snapshot['result'];
    });
  
    afterEach(async() => {
        await timeMachine.revertToSnapshot(snapshotId);
    });
        
    it("Provide Liquidity and do a Trade with XGT", async () => {
        let token = await erc20.deployed();
        let weth = await WETH.deployed();
        let tokenBalance = await token.balanceOf.call(addrController);
        assert.equal(
            tokenBalance.valueOf().toString(),
            "1200000000000000000000000000",
            "correct amounts wasn't in the account"
        );

        let router = await UniswapV2Router02.deployed();
        await token.approve(router.address, tokenBalance.valueOf(), {from: accounts[0]})

        await router.addLiquidityETH(token.address, "5000000000000000000", "5000000000000000000", "1000000000000000000", "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1", "1710627450", {from: accounts[0], value: "1000000000000000000"})

        tokenBalance = await token.balanceOf.call(addrController);
        assert.equal(
            tokenBalance.valueOf().toString(),
            "1199999995000000000000000000",
            "correct amounts wasn't in the account"
        );

        let quote = await router.getAmountsIn("1000000000000000000", [weth.address, token.address], {from: accounts[0]})
        console.log(quote.valueOf().toString());

        await router.swapETHForExactTokens("1000000000000000000", [weth.address, token.address], accounts[1], "1710627450", {from: accounts[0], value: quote.valueOf().toString().split(",")[0]})
        
        tokenBalance = await token.balanceOf.call(accounts[1]);
        assert.equal(
            tokenBalance.valueOf().toString(),
            "1000000000000000000",
            "correct amounts wasn't in the account 1"
        );

    });

});