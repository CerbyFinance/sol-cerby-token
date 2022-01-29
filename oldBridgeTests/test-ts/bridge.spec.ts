const truffleAssert = require("truffle-assertions");

const CrossChainBridgeV2 = artifacts.require("CrossChainBridgeV2");

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
    const address = await CrossChainBridgeV2.deployed().then(_ => _.address);

    console.log({
      address,
    });
  });

  it("deploy them all", async () => {
    const deployed = await Promise.all(
      tokens.map(([name, symbol]) =>
        TestNamedToken.new(name, symbol).then(some => some.address),
      ),
    );

    console.log(deployed);
  });

  it("set allowances", async () => {
    const bridge = await CrossChainBridgeV2.at(bridgeAddress);

    const evmTokens = [
      "0xfF06B30A102A80d3d3C82C091317D1e82Bb4aCF5", // cerCSPR
      "0xB58FcB5D931AC11919462c3A7A812aFdb4c89D28", // cerETH
      "0xe2129472461b1b28ABcA079f72E3529eC24031cD", // cerUSDC
    ];

    const _8bytes = "0000000000000000";

    const casperChainId = 1010;
    const casperTokens = [
      "0x" +
        _8bytes +
        "378bDF003f218b28dfCcFe5f21D7AA6b818D1D79aC4156eDE3F1c107d323f4ad", // cerCSPR
      "0x" +
        _8bytes +
        "04D292244FcF091aB7B15c4B62d86ed1f40C93Ef38CF9280725370aa99Fa700c", // cerETH
      "0x" +
        _8bytes +
        "aC1E4705239368F33B142fD19Aec51F73d57dEb398dF5D095A14c01AbE6Cb59B", // cerUSDC
    ];

    // 3 combos
    // set allowance only for those tokens that are similar
    const combos = evmTokens.map(
      (evmToken, i) => [evmToken, casperTokens[i]] as const,
    );

    const deploys = await Promise.all(
      combos.map(([evmToken, casperToken]) => {
        return bridge.setAllowance(
          evmToken,
          casperToken,
          2, // casper
          casperChainId,
        );
      }),
    );
  });
});
