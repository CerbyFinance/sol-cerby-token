const Weth = artifacts.require("WETH9");
const TestCerbyToken = artifacts.require("TestCerbyToken");
const TestCerUsdToken = artifacts.require("TestCerUsdToken");
const TestUsdcToken = artifacts.require("TestUsdcToken");
const CerbySwapLP1155V1 = artifacts.require("CerbySwapLP1155V1");
// const CerbySwapV1 = artifacts.require("CerbySwapV1");

module.exports = function (deployer) {
  [
    Weth,
    TestCerbyToken,
    TestCerUsdToken,
    TestUsdcToken,
    CerbySwapLP1155V1,
    // CerbySwapV1,
  ].forEach(item => deployer.deploy(item));
} as Truffle.Migration;

export {};
