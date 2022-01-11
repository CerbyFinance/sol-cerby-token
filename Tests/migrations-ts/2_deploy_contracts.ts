const Weth = artifacts.require("WETH9");
// const MetaCoin = artifacts.require("MetaCoin");

module.exports = function (deployer) {
  // deployer.deploy(ConvertLib);
  // deployer.link(ConvertLib, MetaCoin);
  deployer.deploy(Weth);
} as Truffle.Migration;

// because of https://stackoverflow.com/questions/40900791/cannot-redeclare-block-scoped-variable-in-unrelated-files
export {};
