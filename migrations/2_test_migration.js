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

const bridgeXDaiSide = "0xFe446bEF1DbF7AFE24E81e05BC8B271C1BA9a560";
const bridgeMainnetSide = "0xFe446bEF1DbF7AFE24E81e05BC8B271C1BA9a560";
const cDAI = "0x4a92e71227d294f041bd82dd8f78591b75140d63";
const DAI = "0xb7a4f3e9097c08da09517b5ab877f7a917224ede";

const XGTTokenAddress = "0x1593bcef860Fc10F9f1027168B105148549b79F1";
const XGTStakeAddress = "0xE51557AB7fF3cb43f8FbE10497D9D93Ad4Fdc81F";
const XGTGeneratorAddress = "0x2314EE0432383d7B7AD3900874dDFe6373a7FC16";
const XGTPairAddress = "0x161a51eE0b1c659b8b13691CacEbB06813D5B523";
const RUN = 2;

module.exports = async function (deployer, network, accounts) {
  if (deployer.network_id == 77) {
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

      await XGTTokenInstance.initializeToken("0xdE8DcD65042db880006421dD3ECA5D94117642d1", XGTGeneratorInstance.address, {
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
      await XGTGeneratorInstance.initialize(bridgeXDaiSide, XGTStakeAddress, XGTTokenInstance.address, UniswapV2Router02Instance.address, XGTPairAddress, 76103501000, 152207002000);
    }
  }

  if (deployer.network_id == 42) {
    if (RUN == 1) {
      // Mainnet
      await deployer.deploy(XGTTokenMainnet);
      let XGTTokenMainnetInstance = await XGTTokenMainnet.deployed({
        from: accounts[0]
      });
      await XGTTokenMainnetInstance.initialize(XGTTokenAddress, bridgeMainnetSide);

      // Mainnet
      await deployer.deploy(XGTStake);
      let stakeInstance = await XGTStake.deployed({
        from: accounts[0]
      });
      await stakeInstance.initialize(DAI, cDAI, bridgeMainnetSide, XGTGeneratorAddress)
    }
  }

};