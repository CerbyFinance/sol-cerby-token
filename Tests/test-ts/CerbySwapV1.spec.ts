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

contract("Cerby", accounts => {
  it("swapExactCerbyForCerUsd: swap 1000 CERBY for cerUSD", async () => {

    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();
    const CERBY_TOKEN_POS = await cerbySwap.getTokenToPoolPosition(
      TestCerbyToken.address,
    );
    const USDC_TOKEN_POS = await cerbySwap.getTokenToPoolPosition(
      TestCerUsdToken.address,
    );

    const beforeCerbyPool = await cerbySwap.getPoolByToken(
      TestCerbyToken.address,
    );
    const beforeUsdcPool = await cerbySwap.getPoolByToken(
      TestUsdcToken.address,
    );

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
