import BN from "bn.js";
import { getCurrentFeeBasedOnTrades } from "./utils";

const truffleAssert = require("truffle-assertions");

const Weth = artifacts.require("WETH9");
const TestCerbyToken = artifacts.require("TestCerbyToken");
const TestCerUsdToken = artifacts.require("TestCerUsdToken");
const TestUsdcToken = artifacts.require("TestUsdcToken");
const CerbySwapLP1155V1 = artifacts.require("CerbySwapLP1155V1");
const CerbySwapV1 = artifacts.require("CerbySwapV1");

const FEE_DENORM = 10000;

const now = () => Math.floor(+new Date() / 1000);

const bn1e18 = new BN((1e18).toString());

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

contract("Cerby", accounts => {
  it("test everything", async () => {
    await setup();

    // Available Accounts
    // ganache accounts

    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();

    const beforeCerbyPool = await cerbySwap.getPoolByToken(
      TestCerbyToken.address,
    );
    const beforeUsdcPool = await cerbySwap.getPoolByToken(
      TestUsdcToken.address,
    );

    {
      const cerbyTokenFee = await getCurrentFeeBasedOnTrades(
        cerbySwap,
        TestCerbyToken.address,
      );

      assert.equal(cerbyTokenFee.toNumber(), 9900, "should be 9900");
    }

    //
    const CERBY_TOKEN_POS = await cerbySwap.getTokenToPoolPosition(
      TestCerbyToken.address,
    );
    const cerbyPool = await cerbySwap.getPoolByPosition(CERBY_TOKEN_POS);

    const cerbyPoolToken = cerbyPool.token;
    const cerbyPoolTradeVolume = cerbyPool.hourlyTradeVolumeInCerUsd;
    //
    const USDC_TOKEN_POS = await cerbySwap.getTokenToPoolPosition(
      TestCerUsdToken.address,
    );
    const usdcPool = await cerbySwap.getPoolByPosition(USDC_TOKEN_POS);
    const usdcPoolToken = usdcPool.token;
    const usdcPoolTradeVolume = usdcPool.hourlyTradeVolumeInCerUsd;
    //

    //  some 1
    {
      const output1 = await cerbySwap.getOutputExactTokensForCerUsd(
        CERBY_TOKEN_POS,
        new BN(1000).mul(bn1e18),
      );
      const output2 = await cerbySwap.getOutputExactCerUsdForTokens(
        CERBY_TOKEN_POS,
        new BN(1000).mul(bn1e18),
      );

      const input1 = await cerbySwap.getInputTokensForExactCerUsd(
        CERBY_TOKEN_POS,
        new BN(1000).mul(bn1e18),
      );

      const input2 = await cerbySwap.getInputCerUsdForExactTokens(
        CERBY_TOKEN_POS,
        new BN(1000).mul(bn1e18),
      );

      const result = output1.mul(output2).add(input1).add(input2).toString();
    }

    // some swap

    {
      const tokenIn = TestCerbyToken.address;
      const tokenOut = TestCerUsdToken.address;
      const amountTokensIn = new BN(1000).mul(bn1e18);
      const amountTokensOut = await cerbySwap.getOutputExactTokensForCerUsd(
        CERBY_TOKEN_POS,
        amountTokensIn,
      );

      const minAmountTokensOut = 0;
      const expireTimestamp = now() + 86400;

      const transferTo = firstAccount;

      await cerbySwap.swapExactTokensForTokens(
        tokenIn,
        tokenOut,
        amountTokensIn,
        minAmountTokensOut,
        expireTimestamp,
        transferTo,
      );

      const afterCerbyPool = await cerbySwap.getPoolByToken(
        TestCerbyToken.address,
      );

      assert.deepEqual(
        afterCerbyPool.balanceToken.toString(),
        beforeCerbyPool.balanceToken.add(amountTokensIn).toString(),
      );

      // fails for some reason
      assert.deepEqual(
        afterCerbyPool.balanceCerUsd.toString(),
        beforeCerbyPool.balanceCerUsd.sub(amountTokensOut).toString(),
      );
    }
  });
});
