const CerbySwapV1 = artifacts.require("CerbySwapV1");

const Weth = artifacts.require("WETH9");
const TestCerbyToken = artifacts.require("TestCerbyToken");
const TestCerUsdToken = artifacts.require("TestCerUsdToken");
const TestUsdcToken = artifacts.require("TestUsdcToken");
const CerbySwapLP1155V1 = artifacts.require("CerbySwapLP1155V1");

module.exports = async function (deployer) {
  const setup = async () => {
    const cerbySwap = await CerbySwapV1.deployed();

    await cerbySwap.testSetupTokens(
      CerbySwapLP1155V1.address,
      TestCerbyToken.address,

      TestCerUsdToken.address,
      TestUsdcToken.address,
      Weth.address,
    );

    await cerbySwap.adminInitialize();
  };

  await setup();
} as Truffle.Migration;

export {};
