// const Weth = artifacts.require("WETH9");
const CrossChainBridgeV2 = artifacts.require("CrossChainBridgeV2");

module.exports = function (deployer) {
  [CrossChainBridgeV2].forEach(item => deployer.deploy(item));
} as Truffle.Migration;

export {};
