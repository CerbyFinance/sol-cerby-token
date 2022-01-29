const CerbyBridgeV2 = artifacts.require("CerbyBridgeV2");

module.exports = function (deployer) {
  [CerbyBridgeV2].forEach(item => deployer.deploy(item));
} as Truffle.Migration;

export {};
