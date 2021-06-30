 const Migrator = artifacts.require("XGTMigrator");

 module.exports = async function (deployer, network, accounts) {
     await deployer.deploy(Migrator, "0xa856c335623e27cf6ea336c9f806e1d504095983", "0xc00f13ed829df0808408edbe7bfea76811bcdc25", ["0x5304b088de79aa24c337d18fc7ca5a3cab3631da"], ["0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"], "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D", "0x69a0b4db19ed7f4840316b92f16408bff7f04d00", {
         from: accounts[0]
     })
 };