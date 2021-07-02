const {
    expectRevert,
} = require("@openzeppelin/test-helpers");
const {
    web3
} = require("@openzeppelin/test-helpers/src/setup");
const timeMachine = require('ganache-time-traveler');
const {
    assert
} = require("hardhat");

const rewardChest = artifacts.require("RewardChest");
const poolModule = artifacts.require("PoolModule");
const vestingSpawner = artifacts.require("VestingSpawner");
const vesting = artifacts.require("Vesting");
const xgtToken = artifacts.require("XGTToken");

const MONTH = 60 * 60 * 24 * 31;
const DAY = 60 * 60 * 24;

contract('Rewards', async (accounts) => {
    let admin = accounts[0];
    let users = [accounts[1], accounts[2], accounts[3]];
    let pools = ["0x0000000000000000000000000000000000000001", "0x0000000000000000000000000000000000000002"]

    let chestInstance;
    let poolModuleInstance;
    let xgtInstance;
    let vestingSpawnerInstance;

    let snapshot;

    beforeEach(async () => {
        let snapshot = await timeMachine.takeSnapshot();
        snapshotId = snapshot['result'];
    });

    afterEach(async () => {
        await timeMachine.revertToSnapshot(snapshotId);
    });

    it("rewards check", async () => {
        let vestingContract = await vesting.new({
            from: admin
        });

        xgtInstance = await xgtToken.new({
            from: admin
        });

        vestingSpawnerInstance = await vestingSpawner.new(vestingContract.address, xgtInstance.address, {
            from: admin
        });

        let mmAmount = web3.utils.toWei("1000000", "ether");

        chestInstance = await rewardChest.new({
            from: admin
        });

        await chestInstance.initialize(admin, xgtInstance.address, {
            from: admin
        });

        await xgtInstance.initialize(vestingSpawnerInstance.address, chestInstance.address, admin, mmAmount, {
            from: admin
        });

        poolModuleInstance = await poolModule.new({
            from: admin
        });

        await poolModuleInstance.initialize(xgtInstance.address, chestInstance.address, {
            from: admin
        });

        await expectRevert(chestInstance.toggleModule(poolModuleInstance.address, true, {
            from: users[0]
        }), "Ownable: caller is not the owner");

        await chestInstance.toggleModule(poolModuleInstance.address, true, {
            from: admin
        });

        await expectRevert(poolModuleInstance.setIndexerAddress(admin, true, {
            from: users[0]
        }), "Ownable: caller is not the owner");

        await poolModuleInstance.setIndexerAddress(admin, true, {
            from: admin
        });

        // note: in the contract 100 percent == 10000 to have precision for 2 decimals
        await poolModuleInstance.changePoolBaseAPY(10000, {
            from: admin
        });

        await poolModuleInstance.addPool(pools[0], 1, 0, {
            from: admin
        });

        let currBlockNum = await web3.eth.getBlockNumber()
        let currBlock = await web3.eth.getBlock(currBlockNum)

        await poolModuleInstance.setCurrentPoolPrice(1, web3.utils.toWei("2", "ether"), currBlock.timestamp, {
            from: admin
        });
        let latestPoolPrice = await poolModuleInstance.getLatestPoolPrice(1);
        assert.equal(latestPoolPrice, web3.utils.toWei("2", "ether"), "Pool price incorrect");

        await chestInstance.claim({
            from: users[0]
        });

        snapshot = await timeMachine.takeSnapshot();
        snapshotId = snapshot['result'];

        await poolModuleInstance.setUserPoolTokens(users[0], [1], [web3.utils.toWei("100", "ether")], {
            from: admin
        });
        let userPoolTokens = await poolModuleInstance.userPoolTokens(users[0], 1);
        assert.equal(userPoolTokens, web3.utils.toWei("100", "ether"), "User pool tokens don't match");

        await timeMachine.advanceTimeAndBlock(365 * DAY);

        await chestInstance.claim({
            from: users[0]
        });

        let balanceAfter1Year = await xgtInstance.balanceOf(users[0]);
        balanceAfter1Year = web3.utils.fromWei(balanceAfter1Year);
        assert.equal(400, parseFloat(balanceAfter1Year.toString()).toFixed(0), "rewards should match");

        await timeMachine.revertToSnapshot(snapshotId);

        snapshot = await timeMachine.takeSnapshot();
        snapshotId = snapshot['result'];

        await poolModuleInstance.setUserPoolTokens(users[0], [1], [web3.utils.toWei("100", "ether")], {
            from: admin
        });
        userPoolTokens = await poolModuleInstance.userPoolTokens(users[0], 1);
        assert.equal(userPoolTokens, web3.utils.toWei("100", "ether"), "User pool tokens don't match");

        // 25% bonus
        await poolModuleInstance.changePoolBonusAPY(1, 2500, {
            from: admin
        });

        await timeMachine.advanceTimeAndBlock(365 * DAY);

        await chestInstance.claim({
            from: users[0]
        });

        balanceAfter1Year = await xgtInstance.balanceOf(users[0]);
        balanceAfter1Year = web3.utils.fromWei(balanceAfter1Year);
        assert.equal(400 * 1.25, parseFloat(balanceAfter1Year.toString()).toFixed(0), "rewards should match");

        await timeMachine.revertToSnapshot(snapshotId);

        snapshot = await timeMachine.takeSnapshot();
        snapshotId = snapshot['result'];

        await poolModuleInstance.setUserPoolTokens(users[0], [1], [web3.utils.toWei("100", "ether")], {
            from: admin
        });
        userPoolTokens = await poolModuleInstance.userPoolTokens(users[0], 1);
        assert.equal(userPoolTokens, web3.utils.toWei("100", "ether"), "User pool tokens don't match");

        // 25% bonus
        await poolModuleInstance.changePoolBonusAPY(1, 2500, {
            from: admin
        });

        currBlockNum = await web3.eth.getBlockNumber()
        currBlock = await web3.eth.getBlock(currBlockNum)

        // 10% boost for 50% of the time
        await poolModuleInstance.addUserBoost([users[0]], 1, currBlock.timestamp, currBlock.timestamp + 365 * DAY / 2, 1000, {
            from: admin
        });

        // 10% boost for 100% of the time
        await poolModuleInstance.addUserBoost([users[0]], 1, currBlock.timestamp, currBlock.timestamp + 365 * DAY, 1000, {
            from: admin
        });

        await timeMachine.advanceTimeAndBlock(365 * DAY);

        await chestInstance.claim({
            from: users[0]
        });

        balanceAfter1Year = await xgtInstance.balanceOf(users[0]);
        balanceAfter1Year = web3.utils.fromWei(balanceAfter1Year);
        assert.equal(560, parseFloat(balanceAfter1Year.toString()).toFixed(0), "rewards should match");

        await timeMachine.revertToSnapshot(snapshotId);

        snapshot = await timeMachine.takeSnapshot();
        snapshotId = snapshot['result'];

        currBlockNum = await web3.eth.getBlockNumber()
        currBlock = await web3.eth.getBlock(currBlockNum)

        // 10% promo boost for half a year
        await poolModuleInstance.addPromotionBoost(1, currBlock.timestamp + 1 * DAY, DAY * 365 / 2, 1000, 1, {
            from: admin
        });

        await poolModuleInstance.setUserPoolTokens(users[0], [1], [web3.utils.toWei("100", "ether")], {
            from: admin
        });
        userPoolTokens = await poolModuleInstance.userPoolTokens(users[0], 1);
        assert.equal(userPoolTokens, web3.utils.toWei("100", "ether"), "User pool tokens don't match");

        // 25% bonus
        await poolModuleInstance.changePoolBonusAPY(1, 2500, {
            from: admin
        });

        currBlockNum = await web3.eth.getBlockNumber()
        currBlock = await web3.eth.getBlock(currBlockNum)

        // 10% boost for 50% of the time
        await poolModuleInstance.addUserBoost([users[0]], 1, currBlock.timestamp, currBlock.timestamp + 365 * DAY / 2, 1000, {
            from: admin
        });

        // 10% boost for 100% of the time
        await poolModuleInstance.addUserBoost([users[0]], 1, currBlock.timestamp, currBlock.timestamp + 365 * DAY, 1000, {
            from: admin
        });

        await timeMachine.advanceTimeAndBlock(365 * DAY / 3);

        await chestInstance.claim({
            from: users[0]
        });
        await timeMachine.advanceTimeAndBlock(365 * DAY / 3);

        await chestInstance.claim({
            from: users[0]
        });
        await timeMachine.advanceTimeAndBlock(365 * DAY / 3);

        await chestInstance.claim({
            from: users[0]
        });

        balanceAfter1Year = await xgtInstance.balanceOf(users[0]);
        balanceAfter1Year = web3.utils.fromWei(balanceAfter1Year);
        assert.equal(580, parseFloat(balanceAfter1Year.toString()).toFixed(0), "rewards should match");

        await timeMachine.revertToSnapshot(snapshotId);

        snapshot = await timeMachine.takeSnapshot();
        snapshotId = snapshot['result'];

        currBlockNum = await web3.eth.getBlockNumber()
        currBlock = await web3.eth.getBlock(currBlockNum)

        // 10% promo boost for half a year
        await poolModuleInstance.addPromotionBoost(1, currBlock.timestamp + 1 * DAY, DAY * 365 / 2, 1000, 1, {
            from: admin
        });

        await poolModuleInstance.setUserPoolTokens(users[0], [1], [web3.utils.toWei("100", "ether")], {
            from: admin
        });
        userPoolTokens = await poolModuleInstance.userPoolTokens(users[0], 1);
        assert.equal(userPoolTokens, web3.utils.toWei("100", "ether"), "User pool tokens don't match");

        // 25% bonus
        await poolModuleInstance.changePoolBonusAPY(1, 2500, {
            from: admin
        });

        currBlockNum = await web3.eth.getBlockNumber()
        currBlock = await web3.eth.getBlock(currBlockNum)

        // 10% boost for 50% of the time
        await poolModuleInstance.addUserBoost([users[0]], 1, currBlock.timestamp, currBlock.timestamp + 365 * DAY / 2, 1000, {
            from: admin
        });

        // 10% boost for 100% of the time
        await poolModuleInstance.addUserBoost([users[0]], 1, currBlock.timestamp, currBlock.timestamp + 365 * DAY, 1000, {
            from: admin
        });

        await timeMachine.advanceTimeAndBlock(365 * DAY / 4);

        currBlockNum = await web3.eth.getBlockNumber()
        currBlock = await web3.eth.getBlock(currBlockNum)

        await poolModuleInstance.setCurrentPoolPrice(1, web3.utils.toWei("4", "ether"), currBlock.timestamp, {
            from: admin
        });
        latestPoolPrice = await poolModuleInstance.getLatestPoolPrice(1);
        assert.equal(latestPoolPrice.toString(), web3.utils.toWei("4", "ether"), "Pool price incorrect");

        await timeMachine.advanceTimeAndBlock(365 * DAY / 4);

        currBlockNum = await web3.eth.getBlockNumber()
        currBlock = await web3.eth.getBlock(currBlockNum)

        await poolModuleInstance.setCurrentPoolPrice(1, web3.utils.toWei("2", "ether"), currBlock.timestamp, {
            from: admin
        });
        latestPoolPrice = await poolModuleInstance.getLatestPoolPrice(1);
        assert.equal(latestPoolPrice.toString(), web3.utils.toWei("2", "ether"), "Pool price incorrect");

        await timeMachine.advanceTimeAndBlock(365 * DAY / 4);

        currBlockNum = await web3.eth.getBlockNumber()
        currBlock = await web3.eth.getBlock(currBlockNum)

        await poolModuleInstance.setCurrentPoolPrice(1, web3.utils.toWei("4", "ether"), currBlock.timestamp, {
            from: admin
        });
        latestPoolPrice = await poolModuleInstance.getLatestPoolPrice(1);
        assert.equal(latestPoolPrice.toString(), web3.utils.toWei("4", "ether"), "Pool price incorrect");

        await timeMachine.advanceTimeAndBlock(365 * DAY / 4);

        await chestInstance.claim({
            from: users[0]
        });

        balanceAfter1Year = await xgtInstance.balanceOf(users[0]);
        balanceAfter1Year = web3.utils.fromWei(balanceAfter1Year);
        assert.equal(870, parseFloat(balanceAfter1Year.toString()).toFixed(0), "rewards should match");

        await timeMachine.revertToSnapshot(snapshotId);

        snapshot = await timeMachine.takeSnapshot();
        snapshotId = snapshot['result'];

        await poolModuleInstance.addPromotionBoost(1, currBlock.timestamp + 1 * DAY, DAY * 365 / 2, 3000, 1, {
            from: admin
        });

        await poolModuleInstance.setUserPoolTokens(users[1], [1], [web3.utils.toWei("100", "ether")], {
            from: admin
        });

        await poolModuleInstance.setUserPoolTokens(users[0], [1], [web3.utils.toWei("100", "ether")], {
            from: admin
        });

        await poolModuleInstance.setUserPoolTokens(users[0], [1], [web3.utils.toWei("100", "ether")], {
            from: admin
        });
        userPoolTokens = await poolModuleInstance.userPoolTokens(users[0], 1);
        assert.equal(userPoolTokens, web3.utils.toWei("100", "ether"), "User pool tokens don't match");

        await timeMachine.advanceTimeAndBlock(365 * DAY / 4);

        currBlockNum = await web3.eth.getBlockNumber()
        currBlock = await web3.eth.getBlock(currBlockNum)

        await poolModuleInstance.setCurrentPoolPrice(1, web3.utils.toWei("4", "ether"), currBlock.timestamp, {
            from: admin
        });
        latestPoolPrice = await poolModuleInstance.getLatestPoolPrice(1);
        assert.equal(latestPoolPrice.toString(), web3.utils.toWei("4", "ether"), "Pool price incorrect");

        await timeMachine.advanceTimeAndBlock(365 * DAY / 4);

        await poolModuleInstance.setUserPoolTokens(users[0], [1], [web3.utils.toWei("50", "ether")], {
            from: admin
        });

        currBlockNum = await web3.eth.getBlockNumber()
        currBlock = await web3.eth.getBlock(currBlockNum)

        await poolModuleInstance.setCurrentPoolPrice(1, web3.utils.toWei("2", "ether"), currBlock.timestamp, {
            from: admin
        });
        latestPoolPrice = await poolModuleInstance.getLatestPoolPrice(1);
        assert.equal(latestPoolPrice.toString(), web3.utils.toWei("2", "ether"), "Pool price incorrect");

        await timeMachine.advanceTimeAndBlock(365 * DAY / 4);

        currBlockNum = await web3.eth.getBlockNumber()
        currBlock = await web3.eth.getBlock(currBlockNum)

        await poolModuleInstance.setCurrentPoolPrice(1, web3.utils.toWei("4", "ether"), currBlock.timestamp, {
            from: admin
        });
        latestPoolPrice = await poolModuleInstance.getLatestPoolPrice(1);
        assert.equal(latestPoolPrice.toString(), web3.utils.toWei("4", "ether"), "Pool price incorrect");

        await timeMachine.advanceTimeAndBlock(365 * DAY / 4);

        await chestInstance.claim({
            from: users[0]
        });

        balanceAfter1Year = await xgtInstance.balanceOf(users[0]);
        balanceAfter1Year = web3.utils.fromWei(balanceAfter1Year);
        assert.equal(450, parseFloat(balanceAfter1Year.toString()).toFixed(0), "rewards should match");
    });
});