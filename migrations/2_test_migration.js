const XGTToken = artifacts.require("PreAllocERC20");
const XGTTokenMainnet = artifacts.require("XGTTokenMainnet");
const XGTStake = artifacts.require("XGTStake");
const XGTGenerator = artifacts.require("XGTGenerator");
const UniswapV2Router02 = artifacts.require("UniswapV2Router02");
const WETH = artifacts.require("WETH");

const UniswapV2FactoryJson = require('@uniswap/v2-core/build/UniswapV2Factory.json')
const contract = require('@truffle/contract');
const UniswapV2Factory = contract(UniswapV2FactoryJson);

UniswapV2Factory.setProvider(this.web3._provider);

const bridgeXDaiSide = "0x75Df5AF045d91108662D8080fD1FEFAd6aA0bb59";
const bridgeMainnetSide = "0x4C36d2919e407f0Cc2Ee3c993ccF8ac26d9CE64e";
const cDAI = "0x5d3a536e4d6dbd6114cc1ead35777bab948e3643";
const comptroller = "0x3d9819210a31b4961b30ef54be2aed79b9c9cd3b";
const comp = "0xc00e94cb662c3520282e6f5717214004a7f26888";
const DAI = "0x6b175474e89094c44da98b954eedeac495271d0f";

const XGTTokenAddress = "0xBbcCae8Aa4339c4e648aD97f150F1c7204398E3c";
const XGTStakeAddress = "0xBbcCae8Aa4339c4e648aD97f150F1c7204398E3c";
const XGTGeneratorAddress = "0x05DcC5724AF8d5Ba4325581B8B899cDd6930327c";
const XGTPairAddress = "0x7238853E10221E7e5d017111633E4F94216BD4Cd";
const RUN = 2;

module.exports = async function (deployer, network, accounts) {
  if (deployer.network_id == 100) {
    if (RUN == 1) {
      // xDai
      await deployer.deploy(XGTToken);
      let XGTTokenInstance = await XGTToken.deployed({
        from: accounts[0]
      });

      // XDai
      await deployer.deploy(XGTGenerator);
      let XGTGeneratorInstance = await XGTGenerator.deployed({
        from: accounts[0]
      });

      await XGTTokenInstance.initializeToken("0x36985f8AA15C02964d8450c930354C70f382bBC3", XGTGeneratorInstance.address, {
        from: accounts[0]
      });

      // XDAI
      await deployer.deploy(WETH, {
        from: accounts[0]
      })
      let wethInstance = await WETH.deployed();

      await deployer.deploy(UniswapV2Factory, accounts[0], {
        from: accounts[0]
      });
      let instanceUniswapV2Factory = await UniswapV2Factory.deployed();
      let pairAddress = await instanceUniswapV2Factory.createPair(wethInstance.address, XGTToken.address, {
        from: accounts[0]
      });

      console.log("####################################################")
      console.log("PAIR ADDRESS: " + pairAddress.logs[0].args.pair)
      console.log("####################################################")

      await deployer.deploy(UniswapV2Router02, instanceUniswapV2Factory.address, wethInstance.address, XGTTokenInstance.address, XGTGeneratorInstance.address, {
        from: accounts[0],
        gas: 8000000,
      });
    } else {
      let XGTTokenInstance = await XGTToken.deployed();
      let XGTGeneratorInstance = await XGTGenerator.deployed();
      let UniswapV2Router02Instance = await UniswapV2Router02.deployed()
      await XGTGeneratorInstance.initialize(bridgeXDaiSide, XGTStakeAddress, XGTTokenInstance.address, UniswapV2Router02Instance.address, XGTPairAddress, "76103501000", "152207002000", "150000000000000000000000");
    }
  }

  if (deployer.network_id == 1) {
    if (RUN == 1) {
      // Mainnet
      // await deployer.deploy(XGTTokenMainnet);
      // let XGTTokenMainnetInstance = await XGTTokenMainnet.deployed({
      //   from: accounts[0]
      // });
      // await XGTTokenMainnetInstance.initialize(XGTTokenAddress, bridgeMainnetSide);

      // Mainnet
      await deployer.deploy(XGTStake);
      let stakeInstance = await XGTStake.deployed({
        from: accounts[0]
      });
      await stakeInstance.initialize(DAI, cDAI, comptroller, comp, bridgeMainnetSide, XGTGeneratorAddress)
    }
  }

};