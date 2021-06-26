const {
    expectRevert,
    time
} = require("@openzeppelin/test-helpers");
const timeMachine = require('ganache-time-traveler');
const {
    assert
} = require("hardhat");

const vestingSpawner = artifacts.require("VestingSpawner");
const vesting = artifacts.require("Vesting");
const xgtToken = artifacts.require("XGTToken");

const MONTH = 60 * 60 * 24 * 31;
const DAY = 60 * 60 * 24;

contract('Vesting', async (accounts) => {
    let admin = accounts[0];
    let founders = [accounts[1], accounts[2], accounts[3]];
    let foundersAmounts = [70000000, 50000000, 30000000];
    let teamMembers = [accounts[4], accounts[5], accounts[6]];
    let investors = [accounts[7], accounts[8], accounts[9]];
    let investorsAmounts = [1125000, 375000, 12222];
    let outsider = accounts[10];

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

    it("vesting check", async () => {
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

        await xgtInstance.initialize(vestingSpawnerInstance.address, "0x0000000000000000000000000000000000000001", admin, mmAmount, {
            from: admin
        });

        snapshot = await timeMachine.takeSnapshot();
        snapshotId = snapshot['result'];

        console.log("### vesting: founder 1")
        let epochDuration = await vestingSpawnerInstance.EPOCH_DURATION_MONTH();
        let amount = web3.utils.toWei(foundersAmounts[0].toString(), "ether");
        let currBlockNum = await web3.eth.getBlockNumber()
        let currBlock = await web3.eth.getBlock(currBlockNum)
        await vestingSpawnerInstance.spawnVestingContract(founders[0], amount, currBlock.timestamp, epochDuration, 6, 48, 1, {
            from: admin
        });

        let vestingAddr = await vestingSpawnerInstance.vestingContracts(founders[0]);
        let vestingInstance = await vesting.at(vestingAddr);

        await expectRevert(vestingInstance.claim({
            from: founders[0]
        }), "VESTING-CLIFF-NOT-OVER-YET");

        let vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        let personalBalance = await xgtInstance.balanceOf(founders[0]);
        let currEpoch = await vestingInstance.getCurrentEpoch();
        assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(foundersAmounts[0].toString(), "ether"), "total vesting amount not matching");

        await timeMachine.advanceTimeAndBlock(1 * MONTH);
        await expectRevert(vestingInstance.claim({
            from: founders[0]
        }), "VESTING-CLIFF-NOT-OVER-YET");

        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(founders[0]);

        assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(foundersAmounts[0].toString(), "ether"), "total vesting amount not matching");

        await timeMachine.advanceTimeAndBlock(4 * MONTH);
        await expectRevert(vestingInstance.claim({
            from: founders[0]
        }), "VESTING-CLIFF-NOT-OVER-YET");
        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(founders[0]);

        assert.equal(personalBalance, web3.utils.toWei("0".toString(), "ether"), "personal vesting amount not matching");
        assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(foundersAmounts[0].toString(), "ether"), "total vesting amount not matching");

        await timeMachine.advanceTimeAndBlock(2 * MONTH);
        // check if multi claiming breaks it
        await vestingInstance.claim({
            from: founders[0]
        });
        await vestingInstance.claim({
            from: founders[0]
        });
        await vestingInstance.claim({
            from: founders[0]
        });
        await vestingInstance.claim({
            from: founders[0]
        });
        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(founders[0]);

        assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(foundersAmounts[0].toString(), "ether"), "total vesting amount not matching");

        await timeMachine.advanceTimeAndBlock(46 * MONTH);
        await vestingInstance.claim({
            from: founders[0]
        });
        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(founders[0]);

        assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(foundersAmounts[0].toString(), "ether"), "total vesting amount not matching");
        assert.equal(personalBalance, web3.utils.toWei(foundersAmounts[0].toString(), "ether"), "personal vesting amount not matching");
        assert.equal(vestingBalance, web3.utils.toWei("0".toString(), "ether"), "contract vesting amount not matching");

        // await timeMachine.revertToSnapshot(snapshotId);

        console.log("### vesting: founder 2")
        epochDuration = await vestingSpawnerInstance.EPOCH_DURATION_MONTH();
        amount = web3.utils.toWei(foundersAmounts[1].toString(), "ether");
        currBlockNum = await web3.eth.getBlockNumber()
        currBlock = await web3.eth.getBlock(currBlockNum)
        await vestingSpawnerInstance.spawnVestingContract(founders[1], amount, currBlock.timestamp, epochDuration, 6, 48, 1, {
            from: admin
        });

        vestingAddr = await vestingSpawnerInstance.vestingContracts(founders[1]);
        vestingInstance = await vesting.at(vestingAddr);

        await expectRevert(vestingInstance.claim({
            from: founders[1]
        }), "VESTING-CLIFF-NOT-OVER-YET");

        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(founders[1]);

        assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(foundersAmounts[1].toString(), "ether"), "total vesting amount not matching");

        await timeMachine.advanceTimeAndBlock(1 * MONTH);
        await expectRevert(vestingInstance.claim({
            from: founders[1]
        }), "VESTING-CLIFF-NOT-OVER-YET");

        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(founders[1]);

        assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(foundersAmounts[1].toString(), "ether"), "total vesting amount not matching");

        await timeMachine.advanceTimeAndBlock(4 * MONTH);
        await expectRevert(vestingInstance.claim({
            from: founders[1]
        }), "VESTING-CLIFF-NOT-OVER-YET");
        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(founders[1]);

        assert.equal(personalBalance, web3.utils.toWei("0".toString(), "ether"), "personal vesting amount not matching");
        assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(foundersAmounts[1].toString(), "ether"), "total vesting amount not matching");

        await timeMachine.advanceTimeAndBlock(3 * MONTH);
        await vestingInstance.claim({
            from: founders[1]
        });
        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(founders[1]);

        assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(foundersAmounts[1].toString(), "ether"), "total vesting amount not matching");

        await timeMachine.advanceTimeAndBlock(46 * MONTH);
        await vestingInstance.claim({
            from: founders[1]
        });
        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(founders[1]);


        assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(foundersAmounts[1].toString(), "ether"), "total vesting amount not matching");
        assert.equal(personalBalance, web3.utils.toWei(foundersAmounts[1].toString(), "ether"), "personal vesting amount not matching");
        assert.equal(vestingBalance, web3.utils.toWei("0".toString(), "ether"), "contract vesting amount not matching");

        // await timeMachine.revertToSnapshot(snapshotId);

        console.log("### vesting: founder 3")
        epochDuration = await vestingSpawnerInstance.EPOCH_DURATION_MONTH();
        amount = web3.utils.toWei(foundersAmounts[2].toString(), "ether");
        currBlockNum = await web3.eth.getBlockNumber()
        currBlock = await web3.eth.getBlock(currBlockNum)
        await vestingSpawnerInstance.spawnVestingContract(founders[2], amount, currBlock.timestamp, epochDuration, 6, 48, 1, {
            from: admin
        });

        vestingAddr = await vestingSpawnerInstance.vestingContracts(founders[2]);
        vestingInstance = await vesting.at(vestingAddr);

        await expectRevert(vestingInstance.claim({
            from: founders[2]
        }), "VESTING-CLIFF-NOT-OVER-YET");

        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(founders[2]);

        assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(foundersAmounts[2].toString(), "ether"), "total vesting amount not matching");

        await timeMachine.advanceTimeAndBlock(1 * MONTH);
        await expectRevert(vestingInstance.claim({
            from: founders[2]
        }), "VESTING-CLIFF-NOT-OVER-YET");

        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(founders[2]);

        assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(foundersAmounts[2].toString(), "ether"), "total vesting amount not matching");

        await timeMachine.advanceTimeAndBlock(2 * MONTH);
        await expectRevert(vestingInstance.claim({
            from: founders[2]
        }), "VESTING-CLIFF-NOT-OVER-YET");
        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(founders[2]);

        assert.equal(personalBalance, web3.utils.toWei("0".toString(), "ether"), "personal vesting amount not matching");
        assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(foundersAmounts[2].toString(), "ether"), "total vesting amount not matching");

        await timeMachine.advanceTimeAndBlock(4 * MONTH);
        await vestingInstance.claim({
            from: founders[2]
        });
        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(founders[2]);

        assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(foundersAmounts[2].toString(), "ether"), "total vesting amount not matching");

        await timeMachine.advanceTimeAndBlock(46 * MONTH);
        await vestingInstance.claim({
            from: founders[2]
        });
        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(founders[2]);


        assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(foundersAmounts[2].toString(), "ether"), "total vesting amount not matching");
        assert.equal(personalBalance, web3.utils.toWei(foundersAmounts[2].toString(), "ether"), "personal vesting amount not matching");
        assert.equal(vestingBalance, web3.utils.toWei("0".toString(), "ether"), "contract vesting amount not matching");

        //  
        console.log("### vesting: seed investor")
        epochDuration = await vestingSpawnerInstance.EPOCH_DURATION_MONTH();
        amount = web3.utils.toWei(investorsAmounts[0].toString(), "ether");
        currBlockNum = await web3.eth.getBlockNumber()
        currBlock = await web3.eth.getBlock(currBlockNum)
        await vestingSpawnerInstance.spawnVestingContract(investors[0], amount, currBlock.timestamp, epochDuration, 3, 12, 0, {
            from: admin
        });

        vestingAddr = await vestingSpawnerInstance.vestingContracts(investors[0]);
        vestingInstance = await vesting.at(vestingAddr);

        await expectRevert(vestingInstance.claim({
            from: investors[0]
        }), "VESTING-CLIFF-NOT-OVER-YET");

        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(investors[0]);

        assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(investorsAmounts[0].toString(), "ether"), "total vesting amount not matching");

        await timeMachine.advanceTimeAndBlock(1 * MONTH);
        await expectRevert(vestingInstance.claim({
            from: investors[0]
        }), "VESTING-CLIFF-NOT-OVER-YET");

        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(investors[0]);

        assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(investorsAmounts[0].toString(), "ether"), "total vesting amount not matching");

        await timeMachine.advanceTimeAndBlock(2 * MONTH);
        await vestingInstance.claim({
            from: investors[0]
        });
        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(investors[0]);

        assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(investorsAmounts[0].toString(), "ether"), "total vesting amount not matching");

        await timeMachine.advanceTimeAndBlock(5 * MONTH);
        await vestingInstance.claim({
            from: investors[0]
        });
        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(investors[0]);

        assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(investorsAmounts[0].toString(), "ether"), "total vesting amount not matching");

        await timeMachine.advanceTimeAndBlock(7 * MONTH);
        await vestingInstance.claim({
            from: investors[0]
        });
        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(investors[0]);


        assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(investorsAmounts[0].toString(), "ether"), "total vesting amount not matching");
        assert.equal(personalBalance, web3.utils.toWei(investorsAmounts[0].toString(), "ether"), "personal vesting amount not matching");
        assert.equal(vestingBalance, web3.utils.toWei("0".toString(), "ether"), "contract vesting amount not matching");

        console.log("### vesting: whitelist private investor")
        epochDuration = await vestingSpawnerInstance.EPOCH_DURATION_MONTH();
        amount = web3.utils.toWei(investorsAmounts[1].toString(), "ether");
        currBlockNum = await web3.eth.getBlockNumber()
        currBlock = await web3.eth.getBlock(currBlockNum)
        await vestingSpawnerInstance.spawnVestingContract(investors[1], amount, currBlock.timestamp, epochDuration, 2, 10, 0, {
            from: admin
        });

        vestingAddr = await vestingSpawnerInstance.vestingContracts(investors[1]);
        vestingInstance = await vesting.at(vestingAddr);

        await expectRevert(vestingInstance.claim({
            from: investors[1]
        }), "VESTING-CLIFF-NOT-OVER-YET");

        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(investors[1]);

        assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(investorsAmounts[1].toString(), "ether"), "total vesting amount not matching");

        await timeMachine.advanceTimeAndBlock(0.9 * MONTH);
        await expectRevert(vestingInstance.claim({
            from: investors[1]
        }), "VESTING-CLIFF-NOT-OVER-YET");

        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(investors[1]);

        assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(investorsAmounts[1].toString(), "ether"), "total vesting amount not matching");

        await timeMachine.advanceTimeAndBlock(1 * MONTH);
        await expectRevert(vestingInstance.claim({
            from: investors[1]
        }), "VESTING-CLIFF-NOT-OVER-YET");
        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(investors[1]);

        assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(investorsAmounts[1].toString(), "ether"), "total vesting amount not matching");

        await timeMachine.advanceTimeAndBlock(0.1 * MONTH);
        await vestingInstance.claim({
            from: investors[1]
        });
        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(investors[1]);

        assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(investorsAmounts[1].toString(), "ether"), "total vesting amount not matching");

        await timeMachine.advanceTimeAndBlock(4 * MONTH);
        await vestingInstance.claim({
            from: investors[1]
        });
        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(investors[1]);

        assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(investorsAmounts[1].toString(), "ether"), "total vesting amount not matching");

        await timeMachine.advanceTimeAndBlock(6 * MONTH);
        await vestingInstance.claim({
            from: investors[1]
        });
        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(investors[1]);


        assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(investorsAmounts[1].toString(), "ether"), "total vesting amount not matching");
        assert.equal(personalBalance, web3.utils.toWei(investorsAmounts[1].toString(), "ether"), "personal vesting amount not matching");
        assert.equal(vestingBalance, web3.utils.toWei("0".toString(), "ether"), "contract vesting amount not matching");

        console.log("### vesting: public sale investor")
        epochDuration = await vestingSpawnerInstance.EPOCH_DURATION_WEEK();
        amount = web3.utils.toWei(investorsAmounts[2].toString(), "ether");
        currBlockNum = await web3.eth.getBlockNumber()
        currBlock = await web3.eth.getBlock(currBlockNum)
        await vestingSpawnerInstance.spawnVestingContract(investors[2], amount, currBlock.timestamp, epochDuration, 1, 2, 0, {
            from: admin
        });

        vestingAddr = await vestingSpawnerInstance.vestingContracts(investors[2]);
        vestingInstance = await vesting.at(vestingAddr);

        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(investors[2]);

        await vestingInstance.claim({
            from: investors[2]
        });

        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(investors[2]);

        assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(investorsAmounts[2].toString(), "ether"), "total vesting amount not matching");
        assert.equal(personalBalance.add(personalBalance), web3.utils.toWei(investorsAmounts[2].toString(), "ether"), "personal amount not matching");

        await timeMachine.advanceTimeAndBlock(5 * DAY);
        await expectRevert(vestingInstance.claim({
            from: investors[2]
        }), "VESTING-CLIFF-NOT-OVER-YET");


        await timeMachine.advanceTimeAndBlock(2 * DAY);
        await vestingInstance.claim({
            from: investors[2]
        });
        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(investors[2]);

        await timeMachine.advanceTimeAndBlock(2 * DAY);
        await vestingInstance.claim({
            from: investors[2]
        });
        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(investors[2]);

        await timeMachine.advanceTimeAndBlock(5 * DAY);
        await vestingInstance.claim({
            from: investors[2]
        });
        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(investors[2]);

        await timeMachine.revertToSnapshot(snapshotId);

        snapshot = await timeMachine.takeSnapshot();
        snapshotId = snapshot['result'];

        console.log("### vesting: late schedule")
        epochDuration = await vestingSpawnerInstance.EPOCH_DURATION_MONTH();
        amount = web3.utils.toWei(foundersAmounts[0].toString(), "ether");
        currBlockNum = await web3.eth.getBlockNumber()
        currBlock = await web3.eth.getBlock(currBlockNum)
        await vestingSpawnerInstance.spawnVestingContract(founders[0], amount, currBlock.timestamp + (3 * MONTH), epochDuration, 6, 48, 1, {
            from: admin
        });

        vestingAddr = await vestingSpawnerInstance.vestingContracts(founders[0]);
        vestingInstance = await vesting.at(vestingAddr);

        await expectRevert(vestingInstance.claim({
            from: founders[0]
        }), "VESTING-CLIFF-NOT-OVER-YET");

        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(founders[0]);
        currEpoch = await vestingInstance.getCurrentEpoch();
        assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(foundersAmounts[0].toString(), "ether"), "total vesting amount not matching");

        await timeMachine.advanceTimeAndBlock(1 * MONTH);
        await expectRevert(vestingInstance.claim({
            from: founders[0]
        }), "VESTING-CLIFF-NOT-OVER-YET");

        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(founders[0]);

        assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(foundersAmounts[0].toString(), "ether"), "total vesting amount not matching");

        await timeMachine.advanceTimeAndBlock(7 * MONTH);
        await expectRevert(vestingInstance.claim({
            from: founders[0]
        }), "VESTING-CLIFF-NOT-OVER-YET");
        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(founders[0]);

        assert.equal(personalBalance, web3.utils.toWei("0".toString(), "ether"), "personal vesting amount not matching");
        assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(foundersAmounts[0].toString(), "ether"), "total vesting amount not matching");

        await timeMachine.advanceTimeAndBlock(2 * MONTH);
        await vestingInstance.claim({
            from: founders[0]
        });
        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(founders[0]);

        assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(foundersAmounts[0].toString(), "ether"), "total vesting amount not matching");

        await timeMachine.advanceTimeAndBlock(46 * MONTH);
        await vestingInstance.claim({
            from: founders[0]
        });
        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(founders[0]);


        assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(foundersAmounts[0].toString(), "ether"), "total vesting amount not matching");
        assert.equal(personalBalance, web3.utils.toWei(foundersAmounts[0].toString(), "ether"), "personal vesting amount not matching");
        assert.equal(vestingBalance, web3.utils.toWei("0".toString(), "ether"), "contract vesting amount not matching");

        await timeMachine.revertToSnapshot(snapshotId);

        snapshot = await timeMachine.takeSnapshot();
        snapshotId = snapshot['result'];


        console.log("### vesting: late schedule 2")

        epochDuration = await vestingSpawnerInstance.EPOCH_DURATION_WEEK();
        amount = web3.utils.toWei(investorsAmounts[2].toString(), "ether");
        currBlockNum = await web3.eth.getBlockNumber()
        currBlock = await web3.eth.getBlock(currBlockNum)
        // timestamp is three minutes in the future
        await vestingSpawnerInstance.spawnVestingContract(investors[2], amount, currBlock.timestamp + 180, epochDuration, 1, 2, 0, {
            from: admin
        });

        vestingAddr = await vestingSpawnerInstance.vestingContracts(investors[2]);
        vestingInstance = await vesting.at(vestingAddr);

        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(investors[2]);

        await expectRevert(vestingInstance.claim({
            from: investors[2]
        }), "VESTING-NOT-STARTED-YET");

        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(investors[2]);

        assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(investorsAmounts[2].toString(), "ether"), "total vesting amount not matching");
        assert.equal(personalBalance, web3.utils.toWei("0", "ether"), "personal amount not matching");

        await timeMachine.advanceTimeAndBlock(170);
        await expectRevert(vestingInstance.claim({
            from: investors[2]
        }), "VESTING-NOT-STARTED-YET");

        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(investors[2]);

        assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(investorsAmounts[2].toString(), "ether"), "total vesting amount not matching");
        assert.equal(personalBalance, web3.utils.toWei("0", "ether"), "personal amount not matching");

        await timeMachine.advanceTimeAndBlock(4);
        await expectRevert(vestingInstance.claim({
            from: investors[2]
        }), "VESTING-NOT-STARTED-YET");

        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(investors[2]);

        assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(investorsAmounts[2].toString(), "ether"), "total vesting amount not matching");
        assert.equal(personalBalance, web3.utils.toWei("0", "ether"), "personal amount not matching");

        // note: each contract call adds 1 second to the time with ganache, so this is exactly 180 seconds later
        await timeMachine.advanceTimeAndBlock(1);
        await vestingInstance.claim({
            from: investors[2]
        });
        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(investors[2]);
        assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(investorsAmounts[2].toString(), "ether"), "total vesting amount not matching");
        assert.equal(personalBalance.add(personalBalance), web3.utils.toWei(investorsAmounts[2].toString(), "ether"), "personal amount not matching");

        await timeMachine.advanceTimeAndBlock(2 * DAY);
        await expectRevert(vestingInstance.claim({
            from: investors[2]
        }), "VESTING-CLIFF-NOT-OVER-YET");
        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(investors[2]);
        assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(investorsAmounts[2].toString(), "ether"), "total vesting amount not matching");
        assert.equal(personalBalance.add(personalBalance), web3.utils.toWei(investorsAmounts[2].toString(), "ether"), "personal amount not matching");

        await timeMachine.advanceTimeAndBlock(5 * DAY);
        await vestingInstance.claim({
            from: investors[2]
        });
        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(investors[2]);
        assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(investorsAmounts[2].toString(), "ether"), "total vesting amount not matching");
        // 4x vesting balance means 25% is left after 7 days. (50% up front, then 25% each week, so 75% vested)
        assert.equal(vestingBalance.add(vestingBalance).add(vestingBalance).add(vestingBalance), web3.utils.toWei(investorsAmounts[2].toString(), "ether"), "personal amount not matching");

        await timeMachine.advanceTimeAndBlock(7 * DAY);
        await vestingInstance.claim({
            from: investors[2]
        });
        vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        personalBalance = await xgtInstance.balanceOf(investors[2]);
        assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(investorsAmounts[2].toString(), "ether"), "total vesting amount not matching");
        assert.equal(personalBalance, web3.utils.toWei(investorsAmounts[2].toString(), "ether"), "total vesting amount not matching");
        assert.equal(vestingBalance, web3.utils.toWei("0", "ether"), "total vesting amount not matching");

        await timeMachine.revertToSnapshot(snapshotId);

        // snapshot = await timeMachine.takeSnapshot();
        // snapshotId = snapshot['result'];

        // console.log("### vesting: founder 1 detailed")
        // epochDuration = await vestingSpawnerInstance.EPOCH_DURATION_WEEK();
        // amount = web3.utils.toWei(foundersAmounts[0].toString(), "ether");
        // currBlockNum = await web3.eth.getBlockNumber()
        // currBlock = await web3.eth.getBlock(currBlockNum)
        // await vestingSpawnerInstance.spawnVestingContract(founders[0], amount, currBlock.timestamp, epochDuration, 1, 2, 0, {
        //     from: admin
        // });

        // vestingAddr = await vestingSpawnerInstance.vestingContracts(founders[0]);
        // vestingInstance = await vesting.at(vestingAddr);

        // await vestingInstance.claim({
        //     from: founders[0]
        // });

        // vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        // personalBalance = await xgtInstance.balanceOf(founders[0]);
        // console.log("Personal: " + personalBalance.toString())
        // console.log("Vesting: " + vestingBalance.toString())

        // let cliffDone = false;
        // let hours = 0;
        // while (!cliffDone) {
        //     console.log(hours + " hours")
        //     await expectRevert(vestingInstance.claim({
        //         from: founders[0]
        //     }), "VESTING-CLIFF-NOT-OVER-YET");
        //     await timeMachine.advanceTimeAndBlock(2 * 60 * 60);
        //     hours = hours + 2
        //     if (hours == 168) {
        //         break
        //     }
        // }
        // // 183 days == 6 months CHECK

        // await vestingInstance.claim({
        //     from: founders[0]
        // });
        // vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        // personalBalance = await xgtInstance.balanceOf(founders[0]);
        // console.log("Personal: " + personalBalance.toString())
        // console.log("Vesting: " + vestingBalance.toString())

        // let vestingHours = 0
        // while (vestingBalance.toString() != "0") {
        //     await timeMachine.advanceTimeAndBlock(6 * 60 * 60);
        //     await vestingInstance.claim({
        //         from: founders[0]
        //     });
        //     vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        //     personalBalance = await xgtInstance.balanceOf(founders[0]);
        //     vestingHours = vestingHours + 6;
        //     console.log("vestingB " + vestingBalance.toString())
        // }
        // console.log("waited for " + vestingHours + " hours");
        // console.log("waited for " + vestingHours / 24 + " days");
        // // await timeMachine.advanceTimeAndBlock(1 * DAY);
        // // await vestingInstance.claim({
        // // from: founders[0]
        // // });
        // await vestingInstance.claim({
        //     from: founders[0]
        // });
        // await vestingInstance.claim({
        //     from: founders[0]
        // });
        // await vestingInstance.claim({
        //     from: founders[0]
        // });
        // vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        // personalBalance = await xgtInstance.balanceOf(founders[0]);
        // console.log("Personal: " + personalBalance.toString())
        // console.log("Vesting: " + vestingBalance.toString())
        // // assert.equal(personalBalance, web3.utils.toWei(foundersAmounts[0].toString(), "ether"), "personal vesting amount not matching");
        // // assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(foundersAmounts[0].toString(), "ether"), "total vesting amount not matching");

        // // await timeMachine.advanceTimeAndBlock(2 * MONTH);
        // // // check if multi claiming breaks it
        // // await vestingInstance.claim({
        // //     from: founders[0]
        // // });
        // // await vestingInstance.claim({
        // //     from: founders[0]
        // // });
        // // await vestingInstance.claim({
        // //     from: founders[0]
        // // });
        // // await vestingInstance.claim({
        // //     from: founders[0]
        // // });
        // // vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        // // personalBalance = await xgtInstance.balanceOf(founders[0]);

        // // assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(foundersAmounts[0].toString(), "ether"), "total vesting amount not matching");

        // // await timeMachine.advanceTimeAndBlock(46 * MONTH);
        // // await vestingInstance.claim({
        // //     from: founders[0]
        // // });
        // // vestingBalance = await xgtInstance.balanceOf(vestingAddr);
        // // personalBalance = await xgtInstance.balanceOf(founders[0]);

        // // assert.equal(vestingBalance.add(personalBalance), web3.utils.toWei(foundersAmounts[0].toString(), "ether"), "total vesting amount not matching");
        // // assert.equal(personalBalance, web3.utils.toWei(foundersAmounts[0].toString(), "ether"), "personal vesting amount not matching");
        // // assert.equal(vestingBalance, web3.utils.toWei("0".toString(), "ether"), "contract vesting amount not matching");

        await timeMachine.revertToSnapshot(snapshotId);
    });
});