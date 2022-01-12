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
  it("swapExactTokensForTokens: swap 1001 CERBY --> cerUSD; received cerUSD is correct", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();
    const CERBY_TOKEN_POS = await cerbySwap.getTokenToPoolPosition(
      TestCerbyToken.address,
    );

    const beforeCerbyPool = await cerbySwap.getPoolByToken(
      TestCerbyToken.address,
    );

    {
      const tokenIn = TestCerbyToken.address;
      const tokenOut = TestCerUsdToken.address;
      const amountTokensIn = new BN(1001).mul(bn1e18);
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

      // check pool increased by amountTokensIn
      assert.deepEqual(
        beforeCerbyPool.balanceToken.add(amountTokensIn).toString(),
        afterCerbyPool.balanceToken.toString(),
      );

      assert.deepEqual(
        beforeCerbyPool.balanceCerUsd.sub(amountTokensOut).toString(),
        afterCerbyPool.balanceCerUsd.toString(),
      );

      // check K must be increased
      assert.isTrue(
        beforeCerbyPool.balanceCerUsd.mul(beforeCerbyPool.balanceToken).lte(afterCerbyPool.balanceCerUsd.mul(afterCerbyPool.balanceToken))
      );
    }
  });


  it("swapExactTokensForTokens: swap 1002 cerUSD --> CERBY; received CERBY is correct", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();
    const CERBY_TOKEN_POS = await cerbySwap.getTokenToPoolPosition(
      TestCerbyToken.address,
    );

    const beforeCerbyPool = await cerbySwap.getPoolByToken(
      TestCerbyToken.address,
    );

    {
      const tokenIn = TestCerUsdToken.address;
      const tokenOut = TestCerbyToken.address;
      const amountTokensIn = new BN(1002).mul(bn1e18);
      const amountTokensOut = await cerbySwap.getOutputExactCerUsdForTokens(
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

      // check pool increased by amountTokensIn
      assert.deepEqual(
        beforeCerbyPool.balanceCerUsd.add(amountTokensIn).toString(),
        afterCerbyPool.balanceCerUsd.toString(),
      );

      assert.deepEqual(
        beforeCerbyPool.balanceToken.sub(amountTokensOut).toString(),
        afterCerbyPool.balanceToken.toString(),
      );

      // check K must be increased
      assert.isTrue(
        beforeCerbyPool.balanceCerUsd.mul(beforeCerbyPool.balanceToken).lte(afterCerbyPool.balanceCerUsd.mul(afterCerbyPool.balanceToken))
      );
    }
  });


  it("swapExactTokensForTokens: swap 1003 cerUSD --> CERBY --> cerUSD; sent cerUSD >= received cerUSD", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();
    const CERBY_TOKEN_POS = await cerbySwap.getTokenToPoolPosition(
      TestCerbyToken.address,
    );

    const beforeCerbyPool = await cerbySwap.getPoolByToken(
      TestCerbyToken.address,
    );

    {

      // cerUSD --> CERBY
      const tokenIn1 = TestCerUsdToken.address;
      const tokenOut1 = TestCerbyToken.address;
      const amountTokensIn1 = new BN(1003).mul(bn1e18);
      const amountTokensOut1 = await cerbySwap.getOutputExactCerUsdForTokens(
        CERBY_TOKEN_POS,
        amountTokensIn1,
      );
      const minAmountTokensOut1 = 0;
      const expireTimestamp1 = now() + 86400;
      const transferTo1 = firstAccount;

      await cerbySwap.swapExactTokensForTokens(
        tokenIn1,
        tokenOut1,
        amountTokensIn1,
        minAmountTokensOut1,
        expireTimestamp1,
        transferTo1,
      );

      // CERBY --> cerUSD
      const tokenIn2 = TestCerbyToken.address;
      const tokenOut2 = TestCerUsdToken.address;
      const amountTokensIn2 = amountTokensOut1;
      const amountTokensOut2 = await cerbySwap.getOutputExactTokensForCerUsd(
        CERBY_TOKEN_POS,
        amountTokensIn2,
      );
      const minAmountTokensOut2 = 0;
      const expireTimestamp2 = now() + 86400;
      const transferTo2 = firstAccount;

      await cerbySwap.swapExactTokensForTokens(
        tokenIn2,
        tokenOut2,
        amountTokensIn2,
        minAmountTokensOut2,
        expireTimestamp2,
        transferTo2,
      );

      const afterCerbyPool = await cerbySwap.getPoolByToken(
        TestCerbyToken.address,
      );

      // check sent amount must be larger than received
      assert.isTrue(
        amountTokensIn1.gte(amountTokensOut2)
      );

      // check intermediate token balance must not change
      assert.deepEqual(
        beforeCerbyPool.balanceToken.toString(),
        afterCerbyPool.balanceToken.toString(),
      );

      // check K must be increased
      assert.isTrue(
        beforeCerbyPool.balanceCerUsd.mul(beforeCerbyPool.balanceToken).lte(afterCerbyPool.balanceCerUsd.mul(afterCerbyPool.balanceToken))
      );
    }
  });


  it("swapExactTokensForTokens: swap 1004 CERBY --> cerUSD --> CERBY; sent CERBY >= received CERBY", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();
    const CERBY_TOKEN_POS = await cerbySwap.getTokenToPoolPosition(
      TestCerbyToken.address,
    );

    const beforeCerbyPool = await cerbySwap.getPoolByToken(
      TestCerbyToken.address,
    );

    {
      // CERBY --> cerUSD
      const tokenIn1 = TestCerbyToken.address;
      const tokenOut1 = TestCerUsdToken.address;
      const amountTokensIn1 = new BN(1004).mul(bn1e18);
      const amountTokensOut1 = await cerbySwap.getOutputExactTokensForCerUsd(
        CERBY_TOKEN_POS,
        amountTokensIn1,
      );
      const minAmountTokensOut1 = 0;
      const expireTimestamp1 = now() + 86400;
      const transferTo1 = firstAccount;

      await cerbySwap.swapExactTokensForTokens(
        tokenIn1,
        tokenOut1,
        amountTokensIn1,
        minAmountTokensOut1,
        expireTimestamp1,
        transferTo1,
      );

      // cerUSD --> CERBY
      const tokenIn2 = TestCerUsdToken.address;
      const tokenOut2 = TestCerbyToken.address;
      const amountTokensIn2 = amountTokensOut1;
      const amountTokensOut2 = await cerbySwap.getOutputExactCerUsdForTokens(
        CERBY_TOKEN_POS,
        amountTokensIn2,
      );
      const minAmountTokensOut2 = 0;
      const expireTimestamp2 = now() + 86400;
      const transferTo2 = firstAccount;

      await cerbySwap.swapExactTokensForTokens(
        tokenIn2,
        tokenOut2,
        amountTokensIn2,
        minAmountTokensOut2,
        expireTimestamp2,
        transferTo2,
      );

      const afterCerbyPool = await cerbySwap.getPoolByToken(
        TestCerbyToken.address,
      );
      
      // check sent amount larger than received
      assert.isTrue(
        amountTokensIn1.gte(amountTokensOut2)
      );

      // check intermediate token balance must not change
      assert.deepEqual(
        beforeCerbyPool.balanceCerUsd.toString(),
        afterCerbyPool.balanceCerUsd.toString(),
      );

      // check token balance increased and decreased correctly
      assert.deepEqual(
        beforeCerbyPool.balanceToken.add(amountTokensIn1).sub(amountTokensOut2).toString(),
        afterCerbyPool.balanceToken.toString(),
      );

      // check K must be increased
      assert.isTrue(
        beforeCerbyPool.balanceCerUsd.mul(beforeCerbyPool.balanceToken).lte(afterCerbyPool.balanceCerUsd.mul(afterCerbyPool.balanceToken))
      );
    }
  });


  it("swapExactTokensForTokens: swap 1005 CERBY --> cerUSD --> USDC; received USDC is correct", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();
    const CERBY_TOKEN_POS = await cerbySwap.getTokenToPoolPosition(
      TestCerbyToken.address,
    );
    const USDC_TOKEN_POS = await cerbySwap.getTokenToPoolPosition(
      TestUsdcToken.address,
    );

    const beforeCerbyPool = await cerbySwap.getPoolByToken(
      TestCerbyToken.address,
    );

    const beforeUSDCPool = await cerbySwap.getPoolByToken(
      TestUsdcToken.address,
    );

    {
      // CERBY --> cerUSD
      const tokenIn1 = TestCerbyToken.address;
      const tokenOut1 = TestCerUsdToken.address;
      const amountTokensIn1 = new BN(1005).mul(bn1e18);
      const amountTokensOut1 = await cerbySwap.getOutputExactTokensForCerUsd(
        CERBY_TOKEN_POS,
        amountTokensIn1,
      );
      const minAmountTokensOut1 = 0;
      const expireTimestamp1 = now() + 86400;
      const transferTo1 = firstAccount;

      await cerbySwap.swapExactTokensForTokens(
        tokenIn1,
        tokenOut1,
        amountTokensIn1,
        minAmountTokensOut1,
        expireTimestamp1,
        transferTo1,
      );

      // cerUSD --> USDC
      const tokenIn2 = TestCerUsdToken.address;
      const tokenOut2 = TestUsdcToken.address;
      const amountTokensIn2 = amountTokensOut1;
      const amountTokensOut2 = await cerbySwap.getOutputExactCerUsdForTokens(
        USDC_TOKEN_POS,
        amountTokensIn2,
      );
      const minAmountTokensOut2 = 0;
      const expireTimestamp2 = now() + 86400;
      const transferTo2 = firstAccount;

      await cerbySwap.swapExactTokensForTokens(
        tokenIn2,
        tokenOut2,
        amountTokensIn2,
        minAmountTokensOut2,
        expireTimestamp2,
        transferTo2,
      );


      const afterCerbyPool = await cerbySwap.getPoolByToken(
        TestCerbyToken.address,
      );

      const afterUSDCPool = await cerbySwap.getPoolByToken(
        TestUsdcToken.address,
      );
      
      // check sum cerUsd balances in USDC and Cerby pools must be equal
      assert.deepEqual(
        beforeCerbyPool.balanceCerUsd.add(beforeUSDCPool.balanceCerUsd).toString(),
        afterCerbyPool.balanceCerUsd.add(afterUSDCPool.balanceCerUsd).toString(),
      );
      
      // check pool increased by amountTokensIn1
      assert.deepEqual(
        beforeCerbyPool.balanceToken.add(amountTokensIn1).toString(),
        afterCerbyPool.balanceToken.toString(),
      );      
      
      // check pool decreased by amountTokensOut1
      assert.deepEqual(
        beforeCerbyPool.balanceCerUsd.sub(amountTokensOut1).toString(),
        afterCerbyPool.balanceCerUsd.toString(),
      );
      
      // check pool increased by amountTokensIn2
      assert.deepEqual(
        beforeUSDCPool.balanceCerUsd.add(amountTokensIn2).toString(),
        afterUSDCPool.balanceCerUsd.toString(),
      );      
      
      // check pool decreased by amountTokensOut2
      assert.deepEqual(
        beforeUSDCPool.balanceToken.sub(amountTokensOut2).toString(),
        afterUSDCPool.balanceToken.toString(),
      );

      // check K must be increased
      assert.isTrue(
        beforeCerbyPool.balanceCerUsd.mul(beforeCerbyPool.balanceToken).lte(afterCerbyPool.balanceCerUsd.mul(afterCerbyPool.balanceToken))
      );

      // check K must be increased
      assert.isTrue(
        beforeUSDCPool.balanceCerUsd.mul(beforeUSDCPool.balanceToken).lte(afterUSDCPool.balanceCerUsd.mul(afterUSDCPool.balanceToken))
      );
    }
  });


  it("swapExactTokensForTokens: swap 1006 CERBY --> USDC; received USDC is correct", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();
    const CERBY_TOKEN_POS = await cerbySwap.getTokenToPoolPosition(
      TestCerbyToken.address,
    );
    const USDC_TOKEN_POS = await cerbySwap.getTokenToPoolPosition(
      TestUsdcToken.address,
    );

    const beforeCerbyPool = await cerbySwap.getPoolByToken(
      TestCerbyToken.address,
    );

    const beforeUSDCPool = await cerbySwap.getPoolByToken(
      TestUsdcToken.address,
    );

    {
      // CERBY --> cerUSD
      const tokenIn1 = TestCerbyToken.address;
      const tokenOut1 = TestCerUsdToken.address;
      const amountTokensIn1 = new BN(1006).mul(bn1e18);
      const amountTokensOut1 = await cerbySwap.getOutputExactTokensForCerUsd(
        CERBY_TOKEN_POS,
        amountTokensIn1,
      );
      const minAmountTokensOut1 = 0;
      const expireTimestamp1 = now() + 86400;
      const transferTo1 = firstAccount;

      await cerbySwap.swapExactTokensForTokens(
        tokenIn1,
        tokenOut1,
        amountTokensIn1,
        minAmountTokensOut1,
        expireTimestamp1,
        transferTo1,
      );

      // cerUSD --> USDC
      const tokenIn2 = TestCerUsdToken.address;
      const tokenOut2 = TestUsdcToken.address;
      const amountTokensIn2 = amountTokensOut1;
      const amountTokensOut2 = await cerbySwap.getOutputExactCerUsdForTokens(
        USDC_TOKEN_POS,
        amountTokensIn2,
      );
      const minAmountTokensOut2 = 0;
      const expireTimestamp2 = now() + 86400;
      const transferTo2 = firstAccount;

      await cerbySwap.swapExactTokensForTokens(
        tokenIn2,
        tokenOut2,
        amountTokensIn2,
        minAmountTokensOut2,
        expireTimestamp2,
        transferTo2,
      );


      const afterCerbyPool = await cerbySwap.getPoolByToken(
        TestCerbyToken.address,
      );

      const afterUSDCPool = await cerbySwap.getPoolByToken(
        TestUsdcToken.address,
      );
      
      // check sum cerUsd balances in USDC and Cerby pools must be equal
      assert.deepEqual(
        beforeCerbyPool.balanceCerUsd.add(beforeUSDCPool.balanceCerUsd).toString(),
        afterCerbyPool.balanceCerUsd.add(afterUSDCPool.balanceCerUsd).toString(),
      );
      
      // check pool increased by amountTokensIn1
      assert.deepEqual(
        beforeCerbyPool.balanceToken.add(amountTokensIn1).toString(),
        afterCerbyPool.balanceToken.toString(),
      );      
      
      // check pool decreased by amountTokensOut1
      assert.deepEqual(
        beforeCerbyPool.balanceCerUsd.sub(amountTokensOut1).toString(),
        afterCerbyPool.balanceCerUsd.toString(),
      );
      
      // check pool increased by amountTokensIn2
      assert.deepEqual(
        beforeUSDCPool.balanceCerUsd.add(amountTokensIn2).toString(),
        afterUSDCPool.balanceCerUsd.toString(),
      );      
      
      // check pool decreased by amountTokensOut2
      assert.deepEqual(
        beforeUSDCPool.balanceToken.sub(amountTokensOut2).toString(),
        afterUSDCPool.balanceToken.toString(),
      );

      // check K must be increased
      assert.isTrue(
        beforeCerbyPool.balanceCerUsd.mul(beforeCerbyPool.balanceToken).lte(afterCerbyPool.balanceCerUsd.mul(afterCerbyPool.balanceToken))
      );

      // check K must be increased
      assert.isTrue(
        beforeUSDCPool.balanceCerUsd.mul(beforeUSDCPool.balanceToken).lte(afterUSDCPool.balanceCerUsd.mul(afterUSDCPool.balanceToken))
      );
    }
  });


  it("swapExactTokensForTokens: swap 1007 USDC --> cerUSD --> CERBY; received CERBY is correct", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();
    const CERBY_TOKEN_POS = await cerbySwap.getTokenToPoolPosition(
      TestCerbyToken.address,
    );
    const USDC_TOKEN_POS = await cerbySwap.getTokenToPoolPosition(
      TestUsdcToken.address,
    );

    const beforeCerbyPool = await cerbySwap.getPoolByToken(
      TestCerbyToken.address,
    );

    const beforeUSDCPool = await cerbySwap.getPoolByToken(
      TestUsdcToken.address,
    );

    {
      // USDC --> cerUSD
      const tokenIn1 = TestUsdcToken.address;
      const tokenOut1 = TestCerUsdToken.address;
      const amountTokensIn1 = new BN(1007).mul(bn1e18);
      const amountTokensOut1 = await cerbySwap.getOutputExactTokensForCerUsd(
        USDC_TOKEN_POS,
        amountTokensIn1,
      );
      const minAmountTokensOut1 = 0;
      const expireTimestamp1 = now() + 86400;
      const transferTo1 = firstAccount;

      await cerbySwap.swapExactTokensForTokens(
        tokenIn1,
        tokenOut1,
        amountTokensIn1,
        minAmountTokensOut1,
        expireTimestamp1,
        transferTo1,
      );

      // cerUSD --> CERBY
      const tokenIn2 = TestCerUsdToken.address;
      const tokenOut2 = TestCerbyToken.address;
      const amountTokensIn2 = amountTokensOut1;
      const amountTokensOut2 = await cerbySwap.getOutputExactCerUsdForTokens(
        CERBY_TOKEN_POS,
        amountTokensIn2,
      );
      const minAmountTokensOut2 = 0;
      const expireTimestamp2 = now() + 86400;
      const transferTo2 = firstAccount;

      await cerbySwap.swapExactTokensForTokens(
        tokenIn2,
        tokenOut2,
        amountTokensIn2,
        minAmountTokensOut2,
        expireTimestamp2,
        transferTo2,
      );

      const afterCerbyPool = await cerbySwap.getPoolByToken(
        TestCerbyToken.address,
      );

      const afterUSDCPool = await cerbySwap.getPoolByToken(
        TestUsdcToken.address,
      );
      
      // check sum cerUsd balances in USDC and Cerby pools must be equal
      assert.deepEqual(
        beforeCerbyPool.balanceCerUsd.add(beforeUSDCPool.balanceCerUsd).toString(),
        afterCerbyPool.balanceCerUsd.add(afterUSDCPool.balanceCerUsd).toString(),
      );
      
      // check pool increased by amountTokensIn1
      assert.deepEqual(
        beforeUSDCPool.balanceToken.add(amountTokensIn1).toString(),
        afterUSDCPool.balanceToken.toString(),
      );      
      
      // check pool decreased by amountTokensOut1
      assert.deepEqual(
        beforeUSDCPool.balanceCerUsd.sub(amountTokensOut1).toString(),
        afterUSDCPool.balanceCerUsd.toString(),
      );
      
      // check pool increased by amountTokensIn2
      assert.deepEqual(
        beforeCerbyPool.balanceCerUsd.add(amountTokensIn2).toString(),
        afterCerbyPool.balanceCerUsd.toString(),
      );      
      
      // check pool decreased by amountTokensOut2
      assert.deepEqual(
        beforeCerbyPool.balanceToken.sub(amountTokensOut2).toString(),
        afterCerbyPool.balanceToken.toString(),
      );

      // check K must be increased
      assert.isTrue(
        beforeCerbyPool.balanceCerUsd.mul(beforeCerbyPool.balanceToken).lte(afterCerbyPool.balanceCerUsd.mul(afterCerbyPool.balanceToken))
      );

      // check K must be increased
      assert.isTrue(
        beforeUSDCPool.balanceCerUsd.mul(beforeUSDCPool.balanceToken).lte(afterUSDCPool.balanceCerUsd.mul(afterUSDCPool.balanceToken))
      );
    }
  });


  it.only("swapExactTokensForTokens: swap 1008 USDC --> CERBY; received CERBY is correct", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();
    const CERBY_TOKEN_POS = await cerbySwap.getTokenToPoolPosition(
      TestCerbyToken.address,
    );
    const USDC_TOKEN_POS = await cerbySwap.getTokenToPoolPosition(
      TestUsdcToken.address,
    );

    const beforeCerbyPool = await cerbySwap.getPoolByToken(
      TestCerbyToken.address,
    );

    const beforeUSDCPool = await cerbySwap.getPoolByToken(
      TestUsdcToken.address,
    );

    {
      // USDC --> cerUSD
      const tokenIn1 = TestUsdcToken.address;
      const tokenOut1 = TestCerUsdToken.address;
      const amountTokensIn1 = new BN(1008).mul(bn1e18);
      const amountTokensOut1 = await cerbySwap.getOutputExactTokensForCerUsd(
        USDC_TOKEN_POS,
        amountTokensIn1,
      );
      const minAmountTokensOut1 = 0;
      const expireTimestamp1 = now() + 86400;
      const transferTo1 = firstAccount;

      // cerUSD --> CERBY
      const tokenIn2 = TestCerUsdToken.address;
      const tokenOut2 = TestCerbyToken.address;
      const amountTokensIn2 = amountTokensOut1;
      const amountTokensOut2 = await cerbySwap.getOutputExactCerUsdForTokens(
        CERBY_TOKEN_POS,
        amountTokensIn2,
      );
      const minAmountTokensOut2 = 0;
      const expireTimestamp2 = now() + 86400;
      const transferTo2 = firstAccount;

      await cerbySwap.swapExactTokensForTokens(
        tokenIn1,
        tokenOut2,
        amountTokensIn1,
        minAmountTokensOut2,
        expireTimestamp2,
        transferTo2,
      );

      const afterCerbyPool = await cerbySwap.getPoolByToken(
        TestCerbyToken.address,
      );

      const afterUSDCPool = await cerbySwap.getPoolByToken(
        TestUsdcToken.address,
      );
      
      // check sum cerUsd balances in USDC and Cerby pools must be equal
      assert.deepEqual(
        beforeCerbyPool.balanceCerUsd.add(beforeUSDCPool.balanceCerUsd).toString(),
        afterCerbyPool.balanceCerUsd.add(afterUSDCPool.balanceCerUsd).toString(),
      );
      
      // check pool increased by amountTokensIn1
      assert.deepEqual(
        beforeUSDCPool.balanceToken.add(amountTokensIn1).toString(),
        afterUSDCPool.balanceToken.toString(),
      );      
      
      // check pool decreased by amountTokensOut1
      assert.deepEqual(
        beforeUSDCPool.balanceCerUsd.sub(amountTokensOut1).toString(),
        afterUSDCPool.balanceCerUsd.toString(),
      );
      
      // check pool increased by amountTokensIn2
      assert.deepEqual(
        beforeCerbyPool.balanceCerUsd.add(amountTokensIn2).toString(),
        afterCerbyPool.balanceCerUsd.toString(),
      );      
      
      // check pool decreased by amountTokensOut2
      assert.deepEqual(
        beforeCerbyPool.balanceToken.sub(amountTokensOut2).toString(),
        afterCerbyPool.balanceToken.toString(),
      );

      // check K must be increased
      assert.isTrue(
        beforeCerbyPool.balanceCerUsd.mul(beforeCerbyPool.balanceToken).lte(afterCerbyPool.balanceCerUsd.mul(afterCerbyPool.balanceToken))
      );

      // check K must be increased
      assert.isTrue(
        beforeUSDCPool.balanceCerUsd.mul(beforeUSDCPool.balanceToken).lte(afterUSDCPool.balanceCerUsd.mul(afterUSDCPool.balanceToken))
      );
    }
  });


  it("swapExactTokensForTokens: swap 1009 CERBY --> CERBY; sent CERBY >= received CERBY", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();
    const CERBY_TOKEN_POS = await cerbySwap.getTokenToPoolPosition(
      TestCerbyToken.address,
    );

    const beforeCerbyPool = await cerbySwap.getPoolByToken(
      TestCerbyToken.address,
    );

    {
      // CERBY --> cerUSD
      const tokenIn1 = TestCerbyToken.address;
      const tokenOut1 = TestCerUsdToken.address;
      const amountTokensIn1 = new BN(1009).mul(bn1e18);
      const amountTokensOut1 = await cerbySwap.getOutputExactTokensForCerUsd(
        CERBY_TOKEN_POS,
        amountTokensIn1,
      );
      const minAmountTokensOut1 = 0;
      const expireTimestamp1 = now() + 86400;
      const transferTo1 = firstAccount;


      // cerUSD --> CERBY
      const tokenIn2 = TestCerUsdToken.address;
      const tokenOut2 = TestCerbyToken.address;
      const amountTokensIn2 = amountTokensOut1;
      const amountTokensOut2 = await cerbySwap.getOutputExactCerUsdForTokens(
        CERBY_TOKEN_POS,
        amountTokensIn2,
      );
      const minAmountTokensOut2 = 0;
      const expireTimestamp2 = now() + 86400;
      const transferTo2 = firstAccount;

      await cerbySwap.swapExactTokensForTokens(
        tokenIn1,
        tokenOut2,
        amountTokensIn1,
        minAmountTokensOut2,
        expireTimestamp2,
        transferTo2,
      );

      const afterCerbyPool = await cerbySwap.getPoolByToken(
        TestCerbyToken.address,
      );

      // check sent is larger than received
      assert.isTrue(
        amountTokensIn1.gte(amountTokensOut2)
      );

      // intermediate balance must not change
      assert.deepEqual(
        beforeCerbyPool.balanceCerUsd.toString(),
        afterCerbyPool.balanceCerUsd.toString(),
      );

      // check pool increased and decreased balance correctly
      assert.deepEqual(
        beforeCerbyPool.balanceToken.add(amountTokensIn1).sub(amountTokensOut2).toString(),
        afterCerbyPool.balanceToken.toString(),
      );

      // check K must be increased
      assert.isTrue(
        beforeCerbyPool.balanceCerUsd.mul(beforeCerbyPool.balanceToken).lte(afterCerbyPool.balanceCerUsd.mul(afterCerbyPool.balanceToken))
      );
    }
  });


  it("swapExactTokensForTokens: swap 1010 cerUSD --> cerUSD; should revert", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();
    const CERBY_TOKEN_POS = await cerbySwap.getTokenToPoolPosition(
      TestCerbyToken.address,
    );

    const beforeCerbyPool = await cerbySwap.getPoolByToken(
      TestCerbyToken.address,
    );

    const SWAP_CERUSD_FOR_CERUSD_IS_FORBIDDEN_L = "L";

    {
      // cerUSD --> cerUSD      
      const tokenIn1 = TestCerUsdToken.address;
      const tokenOut1 = TestCerUsdToken.address;
      const amountTokensIn1 = new BN(1010).mul(bn1e18);
      const minAmountTokensOut1 = 0;
      const expireTimestamp1 = now() + 86400;
      const transferTo1 = firstAccount;
      await truffleAssert.reverts(
        cerbySwap.swapExactTokensForTokens(
          tokenIn1,
          tokenOut1,
          amountTokensIn1,
          minAmountTokensOut1,
          expireTimestamp1,
          transferTo1,
        ),
        SWAP_CERUSD_FOR_CERUSD_IS_FORBIDDEN_L
      );
    }
  });

});
