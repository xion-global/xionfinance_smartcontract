// const XGTStakeMainnet = artifacts.require("XGTStakeMainnet");
const erc20 = artifacts.require("XGTToken");
const Vesting = artifacts.require("Vesting");
const UniswapV2Router02 = artifacts.require("UniswapV2Router02");
const WETH = artifacts.require("WETH");

const UniswapV2FactoryJson = require('@uniswap/v2-core/build/UniswapV2Factory.json')
const contract = require('@truffle/contract');
const UniswapV2Factory = contract(UniswapV2FactoryJson);

UniswapV2Factory.setProvider(this.web3._provider);

module.exports = async function (deployer, network, accounts) {
  // await deployer.deploy(XGTStakeMainnet);
  // let instance = await XGTStakeMainnet.deployed();
  // await instance.initialize("0x5592ec0cfb4dbc12d3ab100b257153436a1f0fea", "0x6d7f0754ffeb405d23c51ce938289d4835be3b14", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000")

  await deployer.deploy(erc20);
  await deployer.deploy(Vesting);

  let erc20Instance = await erc20.deployed({from: accounts[0]});
  let vestingInstance = await Vesting.deployed({from: accounts[0]});

  await erc20Instance.initializeToken(
    "0x0000000000000000000000000000000000000001",
    vestingInstance.address,
    // Reserve Addresses
    ["0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1", "0x0000000000000000000000000000000000000002", "0x0000000000000000000000000000000000000003"],
    // Founders Addresses
    ["0x0000000000000000000000000000000000000004", "0x0000000000000000000000000000000000000005", "0x0000000000000000000000000000000000000006"], 
    // Founders Amounts
    ["210000000000000000000000000", "150000000000000000000000000", "90000000000000000000000000"],
    // Team Addresses
    ["0x0000000000000000000000000000000000000007", "0x0000000000000000000000000000000000000008"], 
    // Team Amounts
    ["50000000000000000000000000", "50000000000000000000000000"],
    // Community Addresses
    ["0x0000000000000000000000000000000000000009", "0x0000000000000000000000000000000000000010"], 
    // Community Amounts
    ["50000000000000000000000000", "50000000000000000000000000"], {from: accounts[0]}
  );

  await deployer.deploy(WETH, {from: accounts[0]})
  let wethInstance = await WETH.deployed();

  await deployer.deploy(UniswapV2Factory, accounts[0], {from: accounts[0]});
  let instanceUniswapV2Factory = await UniswapV2Factory.deployed();
  await instanceUniswapV2Factory.createPair(wethInstance.address, erc20Instance.address, {from: accounts[0]});

  await deployer.deploy(UniswapV2Router02, instanceUniswapV2Factory.address, wethInstance.address, {from: accounts[0]});
  let instanceRouter02 = await UniswapV2Router02.deployed();
};
