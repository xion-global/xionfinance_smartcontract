const XGTStakeMainnet = artifacts.require("XGTStakeMainnet");

module.exports = async function (deployer) {
  await deployer.deploy(XGTStakeMainnet);
  let instance = await XGTStakeMainnet.deployed();
  await instance.initialize("0x5592ec0cfb4dbc12d3ab100b257153436a1f0fea", "0x6d7f0754ffeb405d23c51ce938289d4835be3b14", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000")
};
