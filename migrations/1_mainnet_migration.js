const {
  deployProxy,
  admin
} = require('@openzeppelin/truffle-upgrades');

const XGTToken = artifacts.require("XGTToken");
const Vesting = artifacts.require("Vesting");
const XGTTokenMainnet = artifacts.require("XGTTokenMainnet");
const XGTStake = artifacts.require("XGTStake");
const XGTGenerator = artifacts.require("XGTGenerator");
const UniswapV2Router02 = artifacts.require("UniswapV2Router02");
const WETH = artifacts.require("WETH");
const UniswapV2Factory = artifacts.require('UniswapV2Factory')

const bridgeXDaiSide = "0x75Df5AF045d91108662D8080fD1FEFAd6aA0bb59";
const bridgeMainnetSide = "0x4C36d2919e407f0Cc2Ee3c993ccF8ac26d9CE64e";
const cDAI = "0x5d3a536e4d6dbd6114cc1ead35777bab948e3643";
const comptroller = "0x3d9819210a31b4961b30ef54be2aed79b9c9cd3b";
const comp = "0xc00e94cb662c3520282e6f5717214004a7f26888";
const DAI = "0x6b175474e89094c44da98b954eedeac495271d0f";

const XGTTokenAddress = "0xf1738912ae7439475712520797583ac784ea9033";
const XGTTokenAddressMainnet = "0xf1738912ae7439475712520797583ac784ea9033";
const XGTStakeAddress = "0xa294A842A34ab045ddb1E6eE07c417a1e13c2eDf";
const XGTGeneratorAddress = "0xa294A842A34ab045ddb1E6eE07c417a1e13c2eDf";
const XGTPairAddress = "0x2745aA5c196bb8eCdBc43A1b15dFCC1f3a711611";
const XGTRouterAddress = "0x5170Bdae56b22D96721E7867aa296802ED498Ec0";

const RUN = 2;

const gnosisSafeMainnet = "0x429BC3d02ba23585632b955E88247F20A778E686";
const gnosisSafeXDai = "0x7418Eb337cF87AF223d07A857387c1F8E7942Ae6";
const interestReceiver = "0xB43bBb77A4636CDb024795cC77b8b46061da3C75";
const refundReceiver = "0x0000000000000000000000000000000000000000";

UniswapV2Factory.setProvider(this.web3._provider);

module.exports = async function (deployer, network, accounts) {
  if (deployer.network_id == 100) {
    if (RUN == 1) {
      await deployProxy(XGTToken, ["XionGlobal Token", "XGT", 18], {
        deployer,
        unsafeAllowCustomTypes: true
      });
      let XGTTokenInstance = await XGTToken.deployed({
        from: accounts[0]
      });

      await deployProxy(Vesting, [accounts[0]], {
        deployer,
        unsafeAllowCustomTypes: true
      });
      let vestingInstance = await Vesting.deployed({
        from: accounts[0]
      });

      await deployProxy(XGTGenerator, [accounts[0]], {
        deployer,
        unsafeAllowCustomTypes: true
      });
      let XGTGeneratorInstance = await XGTGenerator.deployed({
        from: accounts[0]
      });

      await admin.transferProxyAdminOwnership(gnosisSafeXDai);

      await XGTTokenInstance.initializeToken(
        "0x0000000000000000000000000000000000000000",
        vestingInstance.address,
        // Reserve Addresses
        [XGTGeneratorInstance.address, gnosisSafeXDai, gnosisSafeXDai],
        // Founders Addresses
        ["0x5540eE86E9f11D6670C41e934DFc2AC28fe378e5", "0x78c346CA61DD8393Fce282adE47ab2299a72c790", "0x15aC78A62027F13Ab989e89e10eA07B06dE7eAdE"],
        // Founders Amounts
        [toWei("210000000"), toWei("150000000"), toWei("90000000")],
        // Team Addresses
        ["0xb9Edd24591De55dB94A0e7fB2939D8F2eF49bf3E", "0x63f235E60d5A006591bBfF6c7e74888B5c8d633B"],
        // Team Amounts
        [toWei("30000000"), toWei("7500000")],
        // Community Addresses
        ["0x2814e2b7E8915451b0c12C41a6d9aE377a6c4DD6", "0xf560ff907f3a5C377E0bDdA10c27D7a1961a86A7", "0x6C9468108e9DFa635AdE9385F368Ae4948bD292C", "0xE88ee1A0Ae067095C9570b687e7cEBC70Ce95b71", "0xE88ee1A0Ae067095C9570b687e7cEBC70Ce95b71", "0xe4f6b21fCe416aE9399542f06B13d3baE853A3b8", "0x2F912f06a06DC52496b8849AEe39C0179e6939c8", "0xf955286314868f6118508bb4f95ea3319E6946B1"],
        // Community Amounts
        [toWei("89162866"), toWei("42217185"), toWei("13412500"), toWei("1341250"), toWei("1341250"), toWei("1073000"), toWei("1073000"), toWei("378949")], {
          from: accounts[0]
        }
      );

      await vestingInstance.transferOwnership(gnosisSafeXDai)

      await XGTTokenInstance.setBridge(bridgeXDaiSide);

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
      // let XGTTokenInstance = await XGTToken.at(XGTTokenAddress);
      // await XGTTokenInstance.setMainnetContract(XGTTokenAddressMainnet);
      // await XGTTokenInstance.transferOwnership(gnosisSafeXDai);


      let XGTGeneratorInstance = await XGTGenerator.at(XGTGeneratorAddress);
      let UniswapV2Router02Instance = await UniswapV2Router02.at(XGTRouterAddress)
      await XGTGeneratorInstance.initializeGenerator(bridgeXDaiSide, XGTStakeAddress, XGTTokenAddress, UniswapV2Router02Instance.address, XGTPairAddress, "76103501000", "152207002000", "1200000000000000000000000000");
      await XGTGeneratorInstance.transferOwnership(gnosisSafeXDai);
    }
  }
  if (deployer.network_id == 1) {
    if (RUN == 1) {
      let bal1 = await web3.eth.getBalance(accounts[0]);
      console.log(bal1.toString())
      // Mainnet
      await deployProxy(XGTTokenMainnet, ["XionGlobal Token", "XGT", 18], {
        deployer,
        unsafeAllowCustomTypes: true
      });
      let XGTTokenMainnetInstance = await XGTTokenMainnet.deployed({
        from: accounts[0]
      });
      await XGTTokenMainnetInstance.initializeToken(XGTTokenAddress, bridgeMainnetSide);
      await XGTTokenMainnetInstance.transferOwnership(gnosisSafeMainnet);

      // Mainnet
      await deployProxy(XGTStake, [accounts[0]], {
        deployer,
        unsafeAllowCustomTypes: true
      });
      let stakeInstance = await XGTStake.deployed({
        from: accounts[0]
      });
      await stakeInstance.initializeStake(DAI, cDAI, comptroller, comp, bridgeMainnetSide, interestReceiver, refundReceiver)
      await admin.transferProxyAdminOwnership(gnosisSafeMainnet);
    } else {
      let stakeInstance = await XGTStake.at(XGTStakeAddress);
      await stakeInstance.setXGTGeneratorContract(XGTGeneratorAddress, {
        from: accounts[0],
        gas: 1000000,
      });
      await stakeInstance.transferOwnership(gnosisSafeMainnet, {
        from: accounts[0],
        gas: 1000000,
      });
    }
  }
};

function toWei(number) {
  return web3.utils.toWei(number);
}