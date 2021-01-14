const timeMachine = require('ganache-time-traveler');
const vesting = artifacts.require("Vesting");
const testErc20 = artifacts.require("TestERC20");

const addrFounder1 = "0x0000000000000000000000000000000000000004";
const totalFounder1 = 210000000;
const addrFounder2 = "0x0000000000000000000000000000000000000005";
const totalFounder2 = 150000000;

const addrTeam = "0x0000000000000000000000000000000000000007";
const totalTeam = 50000000;

contract('Vesting', async (accounts) =>  {

    beforeEach(async() => {
        let snapshot = await timeMachine.takeSnapshot();
        snapshotId = snapshot['result'];
    });
  
    afterEach(async() => {
        await timeMachine.revertToSnapshot(snapshotId);
    });
        
    it("founder 1 - total before", async () => {
        let instance = await vesting.deployed();
        let token = await testErc20.deployed();
        await instance.claimAll();

        let balance = await instance.getTotalTokens.call(addrFounder1);
        assert.equal(
            balance.valueOf().toString(),
            web3.utils.toWei(totalFounder1.toString(), "ether"),
            "correct amounts wasn't in the account"
        );

        // let tokenBalance = await token.balanceOf.call(addrFounder1);
        // assert.equal(
        //     tokenBalance.valueOf().toString(),
        //     web3.utils.toWei("0", "ether"),
        //     "correct amounts wasn't in the account"
        // );

        // balance = await instance.getClaimedTokens.call(addrFounder1);
        // assert.equal(
        //     balance.valueOf().toString(),
        //     web3.utils.toWei("0", "ether"),
        //     "correct amounts wasn't in the account"
        // );

        // await timeMachine.advanceTimeAndBlock(60*60*24*31);

        // balance = await instance.getClaimedTokens.call(addrFounder1);
        // assert.equal(
        //     balance.valueOf().toString(),
        //     web3.utils.toWei("0", "ether"),
        //     "correct amounts wasn't in the account"
        // );
        
        // balance = await instance.getUnclaimedTokens.call(addrFounder1);
        // assert.equal(
        //     balance.valueOf().toString(),
        //     web3.utils.toWei((totalFounder1/24).toString(), "ether"),
        //     "correct amounts wasn't in the account"
        // );
        // await instance.claimAll();

        balance = await instance.getClaimedTokens.call(addrFounder1);
        assert.equal(
            balance.valueOf().toString(),
            web3.utils.toWei((totalFounder1/24).toString(), "ether"),
            "correct amounts wasn't in the account"
        );

        tokenBalance = await token.balanceOf.call(addrFounder1);
        assert.equal(
            tokenBalance.valueOf().toString(),
            web3.utils.toWei((totalFounder1/24).toString(), "ether"),
            "correct amounts wasn't in the account"
        );

        balance = await instance.getUnclaimedTokens.call(addrFounder1);
        assert.equal(
            balance.valueOf().toString(),
            web3.utils.toWei("0", "ether"),
            "correct amounts wasn't in the account"
        );

        await instance.claimAll();

        balance = await instance.getClaimedTokens.call(addrFounder1);
        assert.equal(
            balance.valueOf().toString(),
            web3.utils.toWei((totalFounder1/24).toString(), "ether"),
            "correct amounts wasn't in the account"
        );

        await timeMachine.advanceTimeAndBlock(60*60*24*31*3);

        await instance.claimAll();

        balance = await instance.getClaimedTokens.call(addrFounder1);
        assert.equal(
            balance.valueOf().toString(),
            web3.utils.toWei((totalFounder1/6).toString(), "ether"),
            "correct amounts wasn't in the account"
        );

        await timeMachine.advanceTimeAndBlock(60*60*24*31*23);

        await instance.claimAll();

        balance = await instance.getClaimedTokens.call(addrFounder1);
        assert.equal(
            balance.valueOf().toString(),
            web3.utils.toWei((totalFounder1).toString(), "ether"),
            "correct amounts wasn't in the account"
        );

        tokenBalance = await token.balanceOf.call(addrFounder1);
        assert.equal(
            tokenBalance.valueOf().toString(),
            web3.utils.toWei((totalFounder1).toString(), "ether"),
            "correct amounts wasn't in the account"
        );
    });

    it("founder 2 - total before", async () => {
        let instance = await vesting.deployed();
        await instance.claimAll();

        let balance = await instance.getTotalTokens.call(addrFounder2);
        assert.equal(
            balance.valueOf().toString(),
            web3.utils.toWei(totalFounder2.toString(), "ether"),
            "correct amounts wasn't in the account"
        );

        await timeMachine.advanceTimeAndBlock(60*60*24*31*22);
        
        balance = await instance.getUnclaimedTokens.call(addrFounder2);
        assert.equal(
            balance.valueOf().toString(),
            web3.utils.toWei((totalFounder2/24*22).toString(), "ether"),
            "correct amounts wasn't in the account"
        );
        await instance.claimAll();

        balance = await instance.getClaimedTokens.call(addrFounder2);
        assert.equal(
            balance.valueOf().toString(),
            web3.utils.toWei((totalFounder2/24*23).toString(), "ether"),
            "correct amounts wasn't in the account"
        );

        balance = await instance.getUnclaimedTokens.call(addrFounder2);
        assert.equal(
            balance.valueOf().toString(),
            web3.utils.toWei("0", "ether"),
            "correct amounts wasn't in the account"
        );

        await instance.claimAll();

        balance = await instance.getClaimedTokens.call(addrFounder2);
        assert.equal(
            balance.valueOf().toString(),
            web3.utils.toWei((totalFounder2/24*23).toString(), "ether"),
            "correct amounts wasn't in the account"
        );

        await timeMachine.advanceTimeAndBlock(60*60*24*31);

        await instance.claimAll();

        balance = await instance.getClaimedTokens.call(addrFounder2);
        assert.equal(
            balance.valueOf().toString(),
            web3.utils.toWei((totalFounder2).toString(), "ether"),
            "correct amounts wasn't in the account"
        );
    });

    it("team - total before", async () => {
        let instance = await vesting.deployed();
        let token = await testErc20.deployed();
        await instance.claimAll();

        let balance = await instance.getTotalTokens.call(addrTeam);
        assert.equal(
            balance.valueOf().toString(),
            web3.utils.toWei(totalTeam.toString(), "ether"),
            "correct amounts wasn't in the account"
        );

        let tokenBalance = await token.balanceOf.call(addrTeam);
        assert.equal(
            tokenBalance.valueOf().toString().slice(0,-9),
            web3.utils.toWei((totalTeam/24).toString(), "ether").slice(0,-9),
            "correct amounts wasn't in the account"
        );

        balance = await instance.getClaimedTokens.call(addrTeam);
        assert.equal(
            balance.valueOf().toString().slice(0,-9),
            web3.utils.toWei((totalTeam/24).toString(), "ether").slice(0,-9),
            "correct amounts wasn't in the account"
        );

        await timeMachine.advanceTimeAndBlock(60*60*24*31);

        balance = await instance.getClaimedTokens.call(addrTeam);
        assert.equal(
            balance.valueOf().toString().slice(0,-9),
            web3.utils.toWei((totalTeam/24).toString(), "ether").slice(0,-9),
            "correct amounts wasn't in the account"
        );
        
        balance = await instance.getUnclaimedTokens.call(addrTeam);
        assert.equal(
            balance.valueOf().toString().slice(0,-9),
            web3.utils.toWei((totalTeam/24).toString(), "ether").slice(0,-9),
            "correct amounts wasn't in the account"
        );
        await instance.claimAll();

        balance = await instance.getClaimedTokens.call(addrTeam);
        assert.equal(
            balance.valueOf().toString().slice(0,-9),
            web3.utils.toWei((totalTeam/24*2).toString(), "ether").slice(0,-9),
            "correct amounts wasn't in the account"
        );

        tokenBalance = await token.balanceOf.call(addrTeam);
        assert.equal(
            tokenBalance.valueOf().toString().slice(0,-9),
            web3.utils.toWei((totalTeam/24*2).toString(), "ether").slice(0,-9),
            "correct amounts wasn't in the account"
        );

        balance = await instance.getUnclaimedTokens.call(addrTeam);
        assert.equal(
            balance.valueOf().toString(),
            web3.utils.toWei("0", "ether"),
            "correct amounts wasn't in the account"
        );

        await instance.claimAll();

        balance = await instance.getClaimedTokens.call(addrTeam);
        assert.equal(
            balance.valueOf().toString().slice(0,-9),
            web3.utils.toWei((totalTeam/24*2).toString(), "ether").slice(0,-9),
            "correct amounts wasn't in the account"
        );

        await timeMachine.advanceTimeAndBlock(60*60*24*31*2);

        await instance.claimAll();

        balance = await instance.getClaimedTokens.call(addrTeam);
        assert.equal(
            balance.valueOf().toString().slice(0,-9),
            web3.utils.toWei((totalTeam/6).toString(), "ether").slice(0,-9),
            "correct amounts wasn't in the account"
        );

        await timeMachine.advanceTimeAndBlock(60*60*24*31*24);

        await instance.claimAll();

        balance = await instance.getClaimedTokens.call(addrTeam);
        assert.equal(
            balance.valueOf().toString().slice(0,-9),
            web3.utils.toWei((totalTeam).toString(), "ether").slice(0,-9),
            "correct amounts wasn't in the account"
        );

        tokenBalance = await token.balanceOf.call(addrTeam);
        assert.equal(
            tokenBalance.valueOf().toString().slice(0,-9),
            web3.utils.toWei((totalTeam).toString(), "ether").slice(0,-9),
            "correct amounts wasn't in the account"
        );
    });

});