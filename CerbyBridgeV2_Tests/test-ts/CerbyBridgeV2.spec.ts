import BN from "bn.js";
import crypto from "crypto";

const truffleAssert = require("truffle-assertions");

const CerbyBridgeV2 = artifacts.require("CerbyBridgeV2");

const TestNamedToken = artifacts.require("TestNamedToken");

const now = () => Math.floor(+new Date() / 1000);

const tokens = [
  ["CerbyCasper", "cerCSPR"],
  ["CerbyETH", "cerETH"],
  ["CerbyUSDC", "cerUSDC"],
] as const;

const bridgeAddress = "0x99B2eC6eb6D25D2DBb5127D084553ddc9575d40f";

contract("CerbyBridgeV2", () => {
  it("deploy cross-chain-bridge", async () => {
    const address = await CerbyBridgeV2.deployed().then((_) => _.address);

    console.log({
      address,
    });
  });

  it("deploy all tokens", async () => {
    const deployed = await Promise.all(
      tokens.map(([name, symbol]) =>
        TestNamedToken.new(name, symbol).then((some) => some.address)
      )
    );

    console.log(deployed);
  });

  it.only("set allowances", async () => {
    const bridge = await CerbyBridgeV2.deployed();

    const evmCerCsprToken = "0xfF06B30A102A80d3d3C82C091317D1e82Bb4aCF5";
    const evmCerEthToken = "0xB58FcB5D931AC11919462c3A7A812aFdb4c89D28";
    const evmCerUsdcToken = "0xe2129472461b1b28ABcA079f72E3529eC24031cD";

    const casperCerCsprToken = "0x378bDF003f218b28dfCcFe5f21D7AA6b818D1D79aC4156eDE3F1c107d323f4ad";
    const casperCerEthToken = "0x4D292244FcF091aB7B15c4B62d86ed1f40C93Ef38CF9280725370aa99Fa700c";
    const casperCerUsdcToken = "0xaC1E4705239368F33B142fD19Aec51F73d57dEb398dF5D095A14c01AbE6Cb59B";

    const _20bytes = "0000000000000000000000000000000000000000";
    const evmCerCsprGenericToken = "0x" + _20bytes + evmCerCsprToken.substring(2);
    const evmCerEthGenericToken = "0x" + _20bytes + evmCerEthToken.substring(2);
    const evmCerUsdcGenericToken = "0x" + _20bytes + evmCerUsdcToken.substring(2);

    const _8bytes = "0000000000000000";
    const casperCerCsprGenericToken = "0x" + _8bytes + casperCerCsprToken.substring(2);
    const casperCerEthGenericToken = "0x" + _8bytes + casperCerEthToken.substring(2);
    const casperCerUsdcGenericToken = "0x" + _8bytes + casperCerUsdcToken.substring(2);

    const casperChainId = 1010;
    const evmChainIdFrom = 123;
    const evmChainIdTo = 1337;
    const evmChainType = 1;

    const allowanceAllowed = 1;
    const evmAllowance = {
      burnGenericToken: evmCerCsprGenericToken,
      burnChainType: evmChainType,
      burnChainId: evmChainIdFrom,
      mintGenericToken: evmCerCsprGenericToken,
      mintChainType: evmChainType,
      mintChainId: evmChainIdTo
    };
    await bridge.setAllowancesBulk([
      evmAllowance
    ], allowanceAllowed);

    const evmAllowanceHash = await bridge.getAllowanceHashMint2Burn(evmAllowance);
    console.log(evmAllowance);

  });
});
