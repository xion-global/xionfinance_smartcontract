/**
 * @type import('hardhat/config').HardhatUserConfig
 */
require("@nomiclabs/hardhat-truffle5");
require('@nomiclabs/hardhat-ethers');
require('@openzeppelin/hardhat-upgrades');

module.exports = {
  solidity: "0.7.6",
  settings: {
    optimizer: {
      enabled: true,
      runs: 200,
    },
  },
};