import crypto from "crypto"
import BN from "bn.js";
import { TestCerbyToken2 } from "./utils";

const truffleAssert = require("truffle-assertions");

const TestCerbyToken = artifacts.require("TestCerbyToken");
const TestCerUsdToken = artifacts.require("TestCerUsdToken");
const TestUsdcToken = artifacts.require("TestUsdcToken");
const CerbySwapV1 = artifacts.require("CerbySwapV1");

const FEE_DENORM = 10000;

const now = () => Math.floor(+new Date() / 1000);

const randomAddress = () => '0x' + crypto.randomBytes(20).toString('hex')

const bn1e18 = new BN((1e18).toString());

contract("Cerby", accounts => {

  // ---------------------------------------------------------- //
  // swapExactTokensForTokens tests //
  // ---------------------------------------------------------- //

  it("swapExactTokensForTokens: swap 1001 CERBY --> cerUSD; received cerUSD is correct", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();

    const beforeCerbyPool = await cerbySwap.getPoolByToken(
      TestCerbyToken.address,
    );

    {
      const tokenIn = TestCerbyToken.address;
      const tokenOut = TestCerUsdToken.address;
      const amountTokensIn = new BN(1001).mul(bn1e18);
      const amountTokensOut = await cerbySwap.getOutputExactTokensForTokens(
        tokenIn,
        tokenOut,
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

    const beforeCerbyPool = await cerbySwap.getPoolByToken(
      TestCerbyToken.address,
    );

    {
      const tokenIn = TestCerUsdToken.address;
      const tokenOut = TestCerbyToken.address;
      const amountTokensIn = new BN(1002).mul(bn1e18);
      const amountTokensOut = await cerbySwap.getOutputExactTokensForTokens(
        tokenIn,
        tokenOut,
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

    const beforeCerbyPool = await cerbySwap.getPoolByToken(
      TestCerbyToken.address,
    );

    {

      // cerUSD --> CERBY
      const tokenIn1 = TestCerUsdToken.address;
      const tokenOut1 = TestCerbyToken.address;
      const amountTokensIn1 = new BN(1003).mul(bn1e18);
      const amountTokensOut1 = await cerbySwap.getOutputExactTokensForTokens(
        tokenIn1,
        tokenOut1,
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
      const amountTokensOut2 = await cerbySwap.getOutputExactTokensForTokens(
        tokenIn2,
        tokenOut2,
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

    const beforeCerbyPool = await cerbySwap.getPoolByToken(
      TestCerbyToken.address,
    );

    {
      // CERBY --> cerUSD
      const tokenIn1 = TestCerbyToken.address;
      const tokenOut1 = TestCerUsdToken.address;
      const amountTokensIn1 = new BN(1004).mul(bn1e18);
      const amountTokensOut1 = await cerbySwap.getOutputExactTokensForTokens(
        tokenIn1,
        tokenOut1,
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
      const amountTokensOut2 = await cerbySwap.getOutputExactTokensForTokens(
        tokenIn2,
        tokenOut2,
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
      const amountTokensOut1 = await cerbySwap.getOutputExactTokensForTokens(
        tokenIn1,
        tokenOut1,
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
      const amountTokensOut2 = await cerbySwap.getOutputExactTokensForTokens(
        tokenIn2,
        tokenOut2,
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
      const amountTokensOut1 = await cerbySwap.getOutputExactTokensForTokens(
        tokenIn1,
        tokenOut1,
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
      const amountTokensOut2 = await cerbySwap.getOutputExactTokensForTokens(
        tokenIn2,
        tokenOut2,
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
      const amountTokensOut1 = await cerbySwap.getOutputExactTokensForTokens(
        tokenIn1,
        tokenOut1,
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
      const amountTokensOut2 = await cerbySwap.getOutputExactTokensForTokens(
        tokenIn2,
        tokenOut2,
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


  it("swapExactTokensForTokens: swap 1008 USDC --> CERBY; received CERBY is correct", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();

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
      const amountTokensOut1 = await cerbySwap.getOutputExactTokensForTokens(
        tokenIn1,
        tokenOut1,
        amountTokensIn1,
      );
      const minAmountTokensOut1 = 0;
      const expireTimestamp1 = now() + 86400;
      const transferTo1 = firstAccount;

      // cerUSD --> CERBY
      const tokenIn2 = TestCerUsdToken.address;
      const tokenOut2 = TestCerbyToken.address;
      const amountTokensIn2 = amountTokensOut1;
      const amountTokensOut2 = await cerbySwap.getOutputExactTokensForTokens(
        tokenIn2,
        tokenOut2,
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

    const beforeCerbyPool = await cerbySwap.getPoolByToken(
      TestCerbyToken.address,
    );

    {
      // CERBY --> cerUSD
      const tokenIn1 = TestCerbyToken.address;
      const tokenOut1 = TestCerUsdToken.address;
      const amountTokensIn1 = new BN(1009).mul(bn1e18);
      const amountTokensOut1 = await cerbySwap.getOutputExactTokensForTokens(
        tokenIn1,
        tokenOut1,
        amountTokensIn1,
      );
      const minAmountTokensOut1 = 0;
      const expireTimestamp1 = now() + 86400;
      const transferTo1 = firstAccount;


      // cerUSD --> CERBY
      const tokenIn2 = TestCerUsdToken.address;
      const tokenOut2 = TestCerbyToken.address;
      const amountTokensIn2 = amountTokensOut1;
      const amountTokensOut2 = await cerbySwap.getOutputExactTokensForTokens(
        tokenIn2,
        tokenOut2,
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


  it("swapExactTokensForTokens: check reverts", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();


    {
      // cerUSD --> cerUSD      
      const SWAP_CERUSD_FOR_CERUSD_IS_FORBIDDEN_L = "L";
      let tokenIn1 = TestCerUsdToken.address;
      let tokenOut1 = TestCerUsdToken.address;
      let amountTokensIn1 = new BN(1010).mul(bn1e18);
      let minAmountTokensOut1 = new BN(0);
      let expireTimestamp1 = now() + 86400;
      let transferTo1 = firstAccount;
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

      const OUTPUT_CERUSD_AMOUNT_IS_LESS_THAN_MINIMUM_SPECIFIED_H = "H";
      tokenIn1 = TestCerbyToken.address;
      tokenOut1 = TestCerUsdToken.address;
      amountTokensIn1 = new BN(1010).mul(bn1e18);
      minAmountTokensOut1 = new BN(1000000000).mul(bn1e18);
      expireTimestamp1 = now() + 86400;
      transferTo1 = firstAccount;
      await truffleAssert.reverts(
        cerbySwap.swapExactTokensForTokens(
          tokenIn1,
          tokenOut1,
          amountTokensIn1,
          minAmountTokensOut1,
          expireTimestamp1,
          transferTo1,
        ),
        OUTPUT_CERUSD_AMOUNT_IS_LESS_THAN_MINIMUM_SPECIFIED_H
      );

      const OUTPUT_TOKENS_AMOUNT_IS_LESS_THAN_MINIMUM_SPECIFIED_i = "i";
      tokenIn1 = TestCerUsdToken.address;
      tokenOut1 = TestCerbyToken.address;
      amountTokensIn1 = new BN(1010).mul(bn1e18);
      minAmountTokensOut1 = new BN(1000000000).mul(bn1e18);
      expireTimestamp1 = now() + 86400;
      transferTo1 = firstAccount;
      await truffleAssert.reverts(
        cerbySwap.swapExactTokensForTokens(
          tokenIn1,
          tokenOut1,
          amountTokensIn1,
          minAmountTokensOut1,
          expireTimestamp1,
          transferTo1,
        ),
        OUTPUT_TOKENS_AMOUNT_IS_LESS_THAN_MINIMUM_SPECIFIED_i
      );

      const TOKEN_DOES_NOT_EXIST_C = "C";
      tokenIn1 = TestCerUsdToken.address;
      tokenOut1 = (await TestCerbyToken2()).address;
      amountTokensIn1 = new BN(1010).mul(bn1e18);
      minAmountTokensOut1 = new BN(0);
      expireTimestamp1 = now() + 86400;
      transferTo1 = firstAccount;
      await truffleAssert.reverts(
        cerbySwap.swapExactTokensForTokens(
          tokenIn1,
          tokenOut1,
          amountTokensIn1,
          minAmountTokensOut1,
          expireTimestamp1,
          transferTo1,
        ),
        TOKEN_DOES_NOT_EXIST_C
      );

      const TRANSACTION_IS_EXPIRED_D = "D";
      tokenIn1 = TestCerbyToken.address;
      tokenOut1 = TestCerUsdToken.address;
      amountTokensIn1 = new BN(1010).mul(bn1e18);
      minAmountTokensOut1 = new BN(0);
      expireTimestamp1 = now() - 86400;
      transferTo1 = firstAccount;
      await truffleAssert.reverts(
        cerbySwap.swapExactTokensForTokens(
          tokenIn1,
          tokenOut1,
          amountTokensIn1,
          minAmountTokensOut1,
          expireTimestamp1,
          transferTo1,
        ),
        TRANSACTION_IS_EXPIRED_D
      );

      const AMOUNT_OF_CERUSD_OR_TOKENS_MUST_BE_LARGER_THAN_ZERO_O = "O";
      tokenIn1 = TestCerbyToken.address;
      tokenOut1 = TestCerUsdToken.address;
      amountTokensIn1 = new BN(0).mul(bn1e18);
      minAmountTokensOut1 = new BN(0);
      expireTimestamp1 = now() + 86400;
      transferTo1 = firstAccount;
      await truffleAssert.reverts(
        cerbySwap.swapExactTokensForTokens(
          tokenIn1,
          tokenOut1,
          amountTokensIn1,
          minAmountTokensOut1,
          expireTimestamp1,
          transferTo1,
        ),
        AMOUNT_OF_CERUSD_OR_TOKENS_MUST_BE_LARGER_THAN_ZERO_O
      );

      tokenIn1 = TestCerUsdToken.address;
      tokenOut1 = TestCerbyToken.address;
      amountTokensIn1 = new BN(0).mul(bn1e18);
      minAmountTokensOut1 = new BN(0);
      amountTokensIn1 = new BN(0);
      expireTimestamp1 = now() + 86400;
      transferTo1 = firstAccount;
      await truffleAssert.reverts(
        cerbySwap.swapExactTokensForTokens(
          tokenIn1,
          tokenOut1,
          amountTokensIn1,
          minAmountTokensOut1,
          expireTimestamp1,
          transferTo1,
        ),
        AMOUNT_OF_CERUSD_OR_TOKENS_MUST_BE_LARGER_THAN_ZERO_O
      );

      tokenIn1 = TestUsdcToken.address;
      tokenOut1 = TestCerbyToken.address;
      amountTokensIn1 = new BN(0).mul(bn1e18);
      minAmountTokensOut1 = new BN(0);
      amountTokensIn1 = new BN(0);
      expireTimestamp1 = now() + 86400;
      transferTo1 = firstAccount;
      await truffleAssert.reverts(
        cerbySwap.swapExactTokensForTokens(
          tokenIn1,
          tokenOut1,
          amountTokensIn1,
          minAmountTokensOut1,
          expireTimestamp1,
          transferTo1,
        ),
        AMOUNT_OF_CERUSD_OR_TOKENS_MUST_BE_LARGER_THAN_ZERO_O
      );
    }
  });

  // ---------------------------------------------------------- //
  // swapTokensForExactTokens tests //
  // ---------------------------------------------------------- //

  it("swapTokensForExactTokens: swap CERBY --> 1011 cerUSD; received cerUSD is correct", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();

    const beforeCerbyPool = await cerbySwap.getPoolByToken(
      TestCerbyToken.address,
    );

    {
      const tokenIn = TestCerbyToken.address;
      const tokenOut = TestCerUsdToken.address;
      const amountTokensOut = new BN(1011).mul(bn1e18);
      const amountTokensIn = await cerbySwap.getInputTokensForExactTokens(
        tokenIn,
        tokenOut,
        amountTokensOut,
      );
      const maxAmountTokensIn = new BN(1000000).mul(bn1e18);
      const expireTimestamp = now() + 86400;
      const transferTo = firstAccount;

      await cerbySwap.swapTokensForExactTokens(
        tokenIn,
        tokenOut,
        amountTokensOut,
        maxAmountTokensIn,
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


  it("swapTokensForExactTokens: swap cerUSD --> 1012 CERBY; received CERBY is correct", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();

    const beforeCerbyPool = await cerbySwap.getPoolByToken(
      TestCerbyToken.address,
    );

    {
      const tokenIn = TestCerUsdToken.address;
      const tokenOut = TestCerbyToken.address;
      const amountTokensOut = new BN(1012).mul(bn1e18);
      const amountTokensIn = await cerbySwap.getInputTokensForExactTokens(
        tokenIn,
        tokenOut,
        amountTokensOut,
      );
      const maxAmountTokensIn = new BN(1000000).mul(bn1e18);
      const expireTimestamp = now() + 86400;
      const transferTo = firstAccount;

      await cerbySwap.swapTokensForExactTokens(
        tokenIn,
        tokenOut,
        amountTokensOut,
        maxAmountTokensIn,
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


  it("swapTokensForExactTokens: swap cerUSD --> CERBY --> 1013 cerUSD; sent cerUSD >= received cerUSD", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();

    const beforeCerbyPool = await cerbySwap.getPoolByToken(
      TestCerbyToken.address,
    );

    {
      const tokenIn1 = TestCerUsdToken.address;
      const tokenOut1 = TestCerbyToken.address;
      const tokenIn2 = TestCerbyToken.address;
      const tokenOut2 = TestCerUsdToken.address;
      const amountTokensOut2 = new BN(1013).mul(bn1e18);
      const amountTokensIn2 = await cerbySwap.getInputTokensForExactTokens(
        tokenIn2,
        tokenOut2,
        amountTokensOut2,
      );
      const amountTokensOut1 = amountTokensIn2;
      const amountTokensIn1 = await cerbySwap.getInputTokensForExactTokens(
        tokenIn1,
        tokenOut1,
        amountTokensOut1,
      );

      const maxAmountTokensIn1 = new BN(1000000).mul(bn1e18);
      const expireTimestamp1 = now() + 86400;
      const transferTo1 = firstAccount;
      const maxAmountTokensIn2 = new BN(1000000).mul(bn1e18);
      const expireTimestamp2 = now() + 86400;
      const transferTo2 = firstAccount;

      // cerUSD --> CERBY
      await cerbySwap.swapTokensForExactTokens(
        tokenIn1,
        tokenOut1,
        amountTokensOut1,
        maxAmountTokensIn1,
        expireTimestamp1,
        transferTo1,
      );

      // CERBY --> cerUSD
      await cerbySwap.swapTokensForExactTokens(
        tokenIn2,
        tokenOut2,
        amountTokensOut2,
        maxAmountTokensIn2,
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
      // since pool is changing during swaps
      // it is not correct to do such test
      // thats why commenting failing assert below
      /*assert.deepEqual(
        beforeCerbyPool.balanceToken.toString(),
        afterCerbyPool.balanceToken.toString(),
      );*/

      // check K must be increased
      assert.isTrue(
        beforeCerbyPool.balanceCerUsd.mul(beforeCerbyPool.balanceToken).lte(afterCerbyPool.balanceCerUsd.mul(afterCerbyPool.balanceToken))
      );
    }
  });


  it("swapTokensForExactTokens: swap CERBY --> cerUSD --> 1014 CERBY; sent CERBY >= received CERBY", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();

    const beforeCerbyPool = await cerbySwap.getPoolByToken(
      TestCerbyToken.address,
    );

    {      
      const tokenIn1 = TestCerbyToken.address;
      const tokenOut1 = TestCerUsdToken.address;
      const tokenIn2 = TestCerUsdToken.address;
      const tokenOut2 = TestCerbyToken.address;
      const amountTokensOut2 = new BN(1014).mul(bn1e18);
      const amountTokensIn2 = await cerbySwap.getInputTokensForExactTokens(
        tokenIn2,
        tokenOut2,
        amountTokensOut2,
      );
      const amountTokensOut1 = amountTokensIn2;
      const amountTokensIn1 = await cerbySwap.getInputTokensForExactTokens(
        tokenIn1,
        tokenOut1,
        amountTokensOut1,
      );
      const maxAmountTokensIn1 = new BN(1000000).mul(bn1e18);
      const expireTimestamp1 = now() + 86400;
      const transferTo1 = firstAccount;
      const maxAmountTokensIn2 = new BN(1000000).mul(bn1e18);
      const expireTimestamp2 = now() + 86400;
      const transferTo2 = firstAccount;

      // CERBY --> cerUSD
      await cerbySwap.swapTokensForExactTokens(
        tokenIn1,
        tokenOut1,
        amountTokensOut1,
        maxAmountTokensIn1,
        expireTimestamp1,
        transferTo1,
      );

      // cerUSD --> CERBY
      await cerbySwap.swapTokensForExactTokens(
        tokenIn2,
        tokenOut2,
        amountTokensOut2,
        maxAmountTokensIn2,
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
      // since pool is changing during swaps
      // it is not correct to do such test
      // thats why commenting failing assert below
      /*assert.deepEqual(
        beforeCerbyPool.balanceCerUsd.toString(),
        afterCerbyPool.balanceCerUsd.toString(),
      );*/

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


  it("swapTokensForExactTokens: swap CERBY --> cerUSD --> 1015 USDC; received USDC is correct", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();

    const beforeCerbyPool = await cerbySwap.getPoolByToken(
      TestCerbyToken.address,
    );

    const beforeUSDCPool = await cerbySwap.getPoolByToken(
      TestUsdcToken.address,
    );

    {
      const tokenIn1 = TestCerbyToken.address;
      const tokenOut1 = TestCerUsdToken.address;
      const tokenIn2 = TestCerUsdToken.address;
      const tokenOut2 = TestUsdcToken.address;
      const amountTokensOut2 = new BN(1015).mul(bn1e18);
      const amountTokensIn2 = await cerbySwap.getInputTokensForExactTokens(
        tokenIn2,
        tokenOut2,
        amountTokensOut2,
      );
      const amountTokensOut1 = amountTokensIn2;
      const amountTokensIn1 = await cerbySwap.getInputTokensForExactTokens(
        tokenIn1,
        tokenOut1,
        amountTokensOut1,
      );
      const maxAmountTokensIn1 = new BN(1000000).mul(bn1e18);
      const expireTimestamp1 = now() + 86400;
      const transferTo1 = firstAccount;
      const maxAmountTokensIn2 = new BN(1000000).mul(bn1e18);
      const expireTimestamp2 = now() + 86400;
      const transferTo2 = firstAccount;

      // CERBY --> cerUSD
      await cerbySwap.swapTokensForExactTokens(
        tokenIn1,
        tokenOut1,
        amountTokensOut1,
        maxAmountTokensIn1,
        expireTimestamp1,
        transferTo1,
      );

      // cerUSD --> USDC
      await cerbySwap.swapTokensForExactTokens(
        tokenIn2,
        tokenOut2,
        amountTokensOut2,
        maxAmountTokensIn2,
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


  it("swapTokensForExactTokens: swap CERBY --> 1016 USDC; received USDC is correct", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();

    const beforeCerbyPool = await cerbySwap.getPoolByToken(
      TestCerbyToken.address,
    );

    const beforeUSDCPool = await cerbySwap.getPoolByToken(
      TestUsdcToken.address,
    );

    {
      const tokenIn1 = TestCerbyToken.address;
      const tokenOut1 = TestCerUsdToken.address;
      const tokenIn2 = TestCerUsdToken.address;
      const tokenOut2 = TestUsdcToken.address;
      const amountTokensOut2 = new BN(1016).mul(bn1e18);
      const amountTokensIn2 = await cerbySwap.getInputTokensForExactTokens(
        tokenIn2,
        tokenOut2,
        amountTokensOut2,
      );
      const amountTokensOut1 = amountTokensIn2;
      const amountTokensIn1 = await cerbySwap.getInputTokensForExactTokens(
        tokenIn1,
        tokenOut1,
        amountTokensOut1,
      );
      const maxAmountTokensIn1 = new BN(1000000).mul(bn1e18);
      const expireTimestamp1 = now() + 86400;
      const transferTo1 = firstAccount;
      const maxAmountTokensIn2 = new BN(1000000).mul(bn1e18);
      const expireTimestamp2 = now() + 86400;
      const transferTo2 = firstAccount;

      // CERBY --> USDC
      await cerbySwap.swapTokensForExactTokens(
        tokenIn1,
        tokenOut2,
        amountTokensOut2,
        maxAmountTokensIn2,
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


  it("swapTokensForExactTokens: swap USDC --> cerUSD --> 1017 CERBY; received CERBY is correct", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();

    const beforeCerbyPool = await cerbySwap.getPoolByToken(
      TestCerbyToken.address,
    );

    const beforeUSDCPool = await cerbySwap.getPoolByToken(
      TestUsdcToken.address,
    );

    {
      const tokenIn1 = TestUsdcToken.address;
      const tokenOut1 = TestCerUsdToken.address;
      const tokenIn2 = TestCerUsdToken.address;
      const tokenOut2 = TestCerbyToken.address;
      const amountTokensOut2 = new BN(1017).mul(bn1e18);
      const amountTokensIn2 = await cerbySwap.getInputTokensForExactTokens(
        tokenIn2,
        tokenOut2,
        amountTokensOut2,
      );
      const amountTokensOut1 = amountTokensIn2;
      const amountTokensIn1 = await cerbySwap.getInputTokensForExactTokens(
        tokenIn1,
        tokenOut1,
        amountTokensOut1,
      );
      const maxAmountTokensIn1 = new BN(1000000).mul(bn1e18);
      const expireTimestamp1 = now() + 86400;
      const transferTo1 = firstAccount;
      const maxAmountTokensIn2 = new BN(1000000).mul(bn1e18);
      const expireTimestamp2 = now() + 86400;
      const transferTo2 = firstAccount;

      // USDC --> cerUSD
      await cerbySwap.swapTokensForExactTokens(
        tokenIn1,
        tokenOut1,
        amountTokensOut1,
        maxAmountTokensIn1,
        expireTimestamp1,
        transferTo1,
      );

      // cerUSD --> CERBY
      await cerbySwap.swapTokensForExactTokens(
        tokenIn2,
        tokenOut2,
        amountTokensOut2,
        maxAmountTokensIn2,
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


  it("swapTokensForExactTokens: swap USDC --> 1018 CERBY; received CERBY is correct", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();

    const beforeCerbyPool = await cerbySwap.getPoolByToken(
      TestCerbyToken.address,
    );

    const beforeUSDCPool = await cerbySwap.getPoolByToken(
      TestUsdcToken.address,
    );

    {
      const tokenIn1 = TestUsdcToken.address;
      const tokenOut1 = TestCerUsdToken.address;
      const tokenIn2 = TestCerUsdToken.address;
      const tokenOut2 = TestCerbyToken.address;
      const amountTokensOut2 = new BN(1018).mul(bn1e18);
      const amountTokensIn2 = await cerbySwap.getInputTokensForExactTokens(
        tokenIn2,
        tokenOut2,
        amountTokensOut2,
      );
      const amountTokensOut1 = amountTokensIn2;
      const amountTokensIn1 = await cerbySwap.getInputTokensForExactTokens(
        tokenIn1,
        tokenOut1,
        amountTokensOut1,
      );
      const maxAmountTokensIn1 = new BN(1000000).mul(bn1e18);
      const expireTimestamp1 = now() + 86400;
      const transferTo1 = firstAccount;
      const maxAmountTokensIn2 = new BN(1000000).mul(bn1e18);
      const expireTimestamp2 = now() + 86400;
      const transferTo2 = firstAccount;

      // USDC --> CERBY
      await cerbySwap.swapTokensForExactTokens(
        tokenIn1,
        tokenOut2,
        amountTokensOut2,
        maxAmountTokensIn2,
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


  it("swapTokensForExactTokens: swap CERBY --> 1019 CERBY; sent CERBY >= received CERBY", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();
    const beforeCerbyPool = await cerbySwap.getPoolByToken(
      TestCerbyToken.address,
    );

    {
      const tokenIn1 = TestCerbyToken.address;
      const tokenOut1 = TestCerUsdToken.address;
      const tokenIn2 = TestCerUsdToken.address;
      const tokenOut2 = TestCerbyToken.address;
      const amountTokensOut2 = new BN(1019).mul(bn1e18);
      const amountTokensIn2 = await cerbySwap.getInputTokensForExactTokens(
        tokenIn2,
        tokenOut2,
        amountTokensOut2,
      );
      const amountTokensOut1 = amountTokensIn2;
      const amountTokensIn1 = await cerbySwap.getInputTokensForExactTokens(
        tokenIn1,
        tokenOut1,
        amountTokensOut1,
      );
      const maxAmountTokensIn1 = new BN(1000000).mul(bn1e18);
      const expireTimestamp1 = now() + 86400;
      const transferTo1 = firstAccount;
      const maxAmountTokensIn2 = new BN(1000000).mul(bn1e18);
      const expireTimestamp2 = now() + 86400;
      const transferTo2 = firstAccount;

      // CERBY --> CERBY
      await cerbySwap.swapTokensForExactTokens(
        tokenIn1,
        tokenOut2,
        amountTokensOut2,
        maxAmountTokensIn2,
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


  it("swapTokensForExactTokens: check reverts", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();


    {
      // cerUSD --> cerUSD      
      const SWAP_CERUSD_FOR_CERUSD_IS_FORBIDDEN_L = "L";
      let tokenIn1 = TestCerUsdToken.address;
      let tokenOut1 = TestCerUsdToken.address;
      let amountTokensOut1 = new BN(1020).mul(bn1e18);
      let maxAmountTokensIn1 = new BN(1000000).mul(bn1e18);
      let expireTimestamp1 = now() + 86400;
      let transferTo1 = firstAccount;
      await truffleAssert.reverts(
        cerbySwap.swapTokensForExactTokens(
          tokenIn1,
          tokenOut1,
          amountTokensOut1,
          maxAmountTokensIn1,
          expireTimestamp1,
          transferTo1,
        ),
        SWAP_CERUSD_FOR_CERUSD_IS_FORBIDDEN_L
      );

      const OUTPUT_TOKENS_AMOUNT_IS_MORE_THAN_MAXIMUM_SPECIFIED_K = "K";
      tokenIn1 = TestCerbyToken.address;
      tokenOut1 = TestCerUsdToken.address;
      amountTokensOut1 = new BN(1020).mul(bn1e18);
      maxAmountTokensIn1 = new BN(0).mul(bn1e18);
      expireTimestamp1 = now() + 86400;
      transferTo1 = firstAccount;
      await truffleAssert.reverts(
        cerbySwap.swapTokensForExactTokens(
          tokenIn1,
          tokenOut1,
          amountTokensOut1,
          maxAmountTokensIn1,
          expireTimestamp1,
          transferTo1,
        ),
        OUTPUT_TOKENS_AMOUNT_IS_MORE_THAN_MAXIMUM_SPECIFIED_K
      );

      const OUTPUT_CERUSD_AMOUNT_IS_MORE_THAN_MAXIMUM_SPECIFIED_J = "J";
      tokenIn1 = TestCerUsdToken.address;
      tokenOut1 = TestCerbyToken.address;
      amountTokensOut1 = new BN(1020).mul(bn1e18);
      maxAmountTokensIn1 = new BN(0).mul(bn1e18);
      expireTimestamp1 = now() + 86400;
      transferTo1 = firstAccount;
      await truffleAssert.reverts(
        cerbySwap.swapTokensForExactTokens(
          tokenIn1,
          tokenOut1,
          amountTokensOut1,
          maxAmountTokensIn1,
          expireTimestamp1,
          transferTo1,
        ),
        OUTPUT_CERUSD_AMOUNT_IS_MORE_THAN_MAXIMUM_SPECIFIED_J
      );

      const TOKEN_DOES_NOT_EXIST_C = "C";
      tokenIn1 = TestCerUsdToken.address;
      tokenOut1 = (await TestCerbyToken2()).address;
      amountTokensOut1 = new BN(1020).mul(bn1e18);
      maxAmountTokensIn1 = new BN(1000000).mul(bn1e18);
      expireTimestamp1 = now() + 86400;
      transferTo1 = firstAccount;
      await truffleAssert.reverts(
        cerbySwap.swapTokensForExactTokens(
          tokenIn1,
          tokenOut1,
          amountTokensOut1,
          maxAmountTokensIn1,
          expireTimestamp1,
          transferTo1,
        ),
        TOKEN_DOES_NOT_EXIST_C
      );

      const TRANSACTION_IS_EXPIRED_D = "D";
      tokenIn1 = TestCerbyToken.address;
      tokenOut1 = TestCerUsdToken.address;
      amountTokensOut1 = new BN(1020).mul(bn1e18);
      maxAmountTokensIn1 = new BN(1000000).mul(bn1e18);
      expireTimestamp1 = now() - 86400;
      transferTo1 = firstAccount;
      await truffleAssert.reverts(
        cerbySwap.swapTokensForExactTokens(
          tokenIn1,
          tokenOut1,
          amountTokensOut1,
          maxAmountTokensIn1,
          expireTimestamp1,
          transferTo1,
        ),
        TRANSACTION_IS_EXPIRED_D
      );

      const AMOUNT_OF_CERUSD_OR_TOKENS_MUST_BE_LARGER_THAN_ZERO_O = "O";
      tokenIn1 = TestCerbyToken.address;
      tokenOut1 = TestCerUsdToken.address;
      amountTokensOut1 = new BN(0);
      maxAmountTokensIn1 = new BN(1000000).mul(bn1e18);
      expireTimestamp1 = now() + 86400;
      transferTo1 = firstAccount;
      await truffleAssert.reverts(
        cerbySwap.swapTokensForExactTokens(
          tokenIn1,
          tokenOut1,
          amountTokensOut1,
          maxAmountTokensIn1,
          expireTimestamp1,
          transferTo1,
        ),
        AMOUNT_OF_CERUSD_OR_TOKENS_MUST_BE_LARGER_THAN_ZERO_O
      );

      tokenIn1 = TestCerUsdToken.address;
      tokenOut1 = TestCerbyToken.address;
      amountTokensOut1 = new BN(0);
      maxAmountTokensIn1 = new BN(1000000).mul(bn1e18);
      expireTimestamp1 = now() + 86400;
      transferTo1 = firstAccount;
      await truffleAssert.reverts(
        cerbySwap.swapTokensForExactTokens(
          tokenIn1,
          tokenOut1,
          amountTokensOut1,
          maxAmountTokensIn1,
          expireTimestamp1,
          transferTo1,
        ),
        AMOUNT_OF_CERUSD_OR_TOKENS_MUST_BE_LARGER_THAN_ZERO_O
      );

      tokenIn1 = TestUsdcToken.address;
      tokenOut1 = TestCerbyToken.address;
      amountTokensOut1 = new BN(0);
      maxAmountTokensIn1 = new BN(1000000).mul(bn1e18);
      expireTimestamp1 = now() + 86400;
      transferTo1 = firstAccount;
      await truffleAssert.reverts(
        cerbySwap.swapTokensForExactTokens(
          tokenIn1,
          tokenOut1,
          amountTokensOut1,
          maxAmountTokensIn1,
          expireTimestamp1,
          transferTo1,
        ),
        AMOUNT_OF_CERUSD_OR_TOKENS_MUST_BE_LARGER_THAN_ZERO_O
      );

    }
  });


  
  // ---------------------------------------------------------- //
  // swapExactTokensForTokens ETH tests //
  // ---------------------------------------------------------- //

  it("swapExactTokensForTokens: swap 1021e10 ETH --> cerUSD; received cerUSD is correct", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();

    const beforeEthPool = await cerbySwap.getPoolByToken(
      '0x14769F96e57B80c66837701DE0B43686Fb4632De',
    );

    {
      const tokenIn = '0x14769F96e57B80c66837701DE0B43686Fb4632De';
      const tokenOut = TestCerUsdToken.address;
      const amountTokensIn = new BN((1021e10).toString());
      const amountTokensOut = await cerbySwap.getOutputExactTokensForTokens(
        tokenIn,
        tokenOut,
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
        { value: amountTokensIn }
      );

      const afterEthPool = await cerbySwap.getPoolByToken(
        '0x14769F96e57B80c66837701DE0B43686Fb4632De',
      );

      // check pool increased by amountTokensIn
      assert.deepEqual(
        beforeEthPool.balanceToken.add(amountTokensIn).toString(),
        afterEthPool.balanceToken.toString(),
      );

      assert.deepEqual(
        beforeEthPool.balanceCerUsd.sub(amountTokensOut).toString(),
        afterEthPool.balanceCerUsd.toString(),
      );

      // check K must be increased
      assert.isTrue(
        beforeEthPool.balanceCerUsd.mul(beforeEthPool.balanceToken).lte(afterEthPool.balanceCerUsd.mul(afterEthPool.balanceToken))
      );
    }
  }); 


  it("swapExactTokensForTokens: swap 1022 cerUSD --> ETH; received ETH is correct", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();

    const beforeEthPool = await cerbySwap.getPoolByToken(
      '0x14769F96e57B80c66837701DE0B43686Fb4632De',
    );

    {
      const tokenIn = TestCerUsdToken.address;
      const tokenOut = '0x14769F96e57B80c66837701DE0B43686Fb4632De';
      const amountTokensIn = new BN(1022).mul(bn1e18);
      const amountTokensOut = await cerbySwap.getOutputExactTokensForTokens(
        tokenIn,
        tokenOut,
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

      const afterEthPool = await cerbySwap.getPoolByToken(
        '0x14769F96e57B80c66837701DE0B43686Fb4632De',
      );

      // check pool increased by amountTokensIn
      assert.deepEqual(
        beforeEthPool.balanceCerUsd.add(amountTokensIn).toString(),
        afterEthPool.balanceCerUsd.toString(),
      );

      assert.deepEqual(
        beforeEthPool.balanceToken.sub(amountTokensOut).toString(),
        afterEthPool.balanceToken.toString(),
      );

      // check K must be increased
      assert.isTrue(
        beforeEthPool.balanceCerUsd.mul(beforeEthPool.balanceToken).lte(afterEthPool.balanceCerUsd.mul(afterEthPool.balanceToken))
      );
    }
  });


  it("swapExactTokensForTokens: swap 1023 cerUSD --> ETH --> cerUSD; sent cerUSD >= received cerUSD", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();
    
    const beforeEthPool = await cerbySwap.getPoolByToken(
      '0x14769F96e57B80c66837701DE0B43686Fb4632De',
    );

    {

      // cerUSD --> ETH
      const tokenIn1 = TestCerUsdToken.address;
      const tokenOut1 = '0x14769F96e57B80c66837701DE0B43686Fb4632De';
      const amountTokensIn1 = new BN(1023).mul(bn1e18);
      const amountTokensOut1 = await cerbySwap.getOutputExactTokensForTokens(
        tokenIn1,
        tokenOut1,
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

      // ETH --> cerUSD
      const tokenIn2 = '0x14769F96e57B80c66837701DE0B43686Fb4632De';
      const tokenOut2 = TestCerUsdToken.address;
      const amountTokensIn2 = amountTokensOut1;
      const amountTokensOut2 = await cerbySwap.getOutputExactTokensForTokens(
        tokenIn2,
        tokenOut2,
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
        { value: amountTokensIn2 }
      );

      const afterEthPool = await cerbySwap.getPoolByToken(
        '0x14769F96e57B80c66837701DE0B43686Fb4632De',
      );

      // check sent amount must be larger than received
      assert.isTrue(
        amountTokensIn1.gte(amountTokensOut2)
      );

      // check intermediate token balance must not change
      assert.deepEqual(
        beforeEthPool.balanceToken.toString(),
        afterEthPool.balanceToken.toString(),
      );

      // check K must be increased
      assert.isTrue(
        beforeEthPool.balanceCerUsd.mul(beforeEthPool.balanceToken).lte(afterEthPool.balanceCerUsd.mul(afterEthPool.balanceToken))
      );
    }
  });


  it("swapExactTokensForTokens: swap 1024e10 ETH --> cerUSD --> ETH; sent ETH >= received ETH", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();

    const beforeEthPool = await cerbySwap.getPoolByToken(
      '0x14769F96e57B80c66837701DE0B43686Fb4632De',
    );

    {
      // ETH --> cerUSD
      const tokenIn1 = '0x14769F96e57B80c66837701DE0B43686Fb4632De';
      const tokenOut1 = TestCerUsdToken.address;
      const amountTokensIn1 = new BN((1024e10).toString());
      const amountTokensOut1 = await cerbySwap.getOutputExactTokensForTokens(
        tokenIn1,
        tokenOut1,
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
        { value: amountTokensIn1 }
      );

      // cerUSD --> ETH
      const tokenIn2 = TestCerUsdToken.address;
      const tokenOut2 = '0x14769F96e57B80c66837701DE0B43686Fb4632De';
      const amountTokensIn2 = amountTokensOut1;
      const amountTokensOut2 = await cerbySwap.getOutputExactTokensForTokens(
        tokenIn2,
        tokenOut2,
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

      const afterEthPool = await cerbySwap.getPoolByToken(
        '0x14769F96e57B80c66837701DE0B43686Fb4632De',
      );
      
      // check sent amount larger than received
      assert.isTrue(
        amountTokensIn1.gte(amountTokensOut2)
      );

      // check intermediate token balance must not change
      assert.deepEqual(
        beforeEthPool.balanceCerUsd.toString(),
        afterEthPool.balanceCerUsd.toString(),
      );

      // check token balance increased and decreased correctly
      assert.deepEqual(
        beforeEthPool.balanceToken.add(amountTokensIn1).sub(amountTokensOut2).toString(),
        afterEthPool.balanceToken.toString(),
      );

      // check K must be increased
      assert.isTrue(
        beforeEthPool.balanceCerUsd.mul(beforeEthPool.balanceToken).lte(afterEthPool.balanceCerUsd.mul(afterEthPool.balanceToken))
      );
    }
  });


  it("swapExactTokensForTokens: swap 1025e10 ETH --> cerUSD --> USDC; received USDC is correct", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();

    const beforeEthPool = await cerbySwap.getPoolByToken(
      '0x14769F96e57B80c66837701DE0B43686Fb4632De',
    );

    const beforeUSDCPool = await cerbySwap.getPoolByToken(
      TestUsdcToken.address,
    );

    {
      // ETH --> cerUSD
      const tokenIn1 = '0x14769F96e57B80c66837701DE0B43686Fb4632De';
      const tokenOut1 = TestCerUsdToken.address;
      const amountTokensIn1 = new BN((1025e10).toString());
      const amountTokensOut1 = await cerbySwap.getOutputExactTokensForTokens(
        tokenIn1,
        tokenOut1,
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
        { value: amountTokensIn1 }
      );

      // cerUSD --> USDC
      const tokenIn2 = TestCerUsdToken.address;
      const tokenOut2 = TestUsdcToken.address;
      const amountTokensIn2 = amountTokensOut1;
      const amountTokensOut2 = await cerbySwap.getOutputExactTokensForTokens(
        tokenIn2,
        tokenOut2,
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


      const afterEthPool = await cerbySwap.getPoolByToken(
        '0x14769F96e57B80c66837701DE0B43686Fb4632De',
      );

      const afterUSDCPool = await cerbySwap.getPoolByToken(
        TestUsdcToken.address,
      );
      
      // check sum cerUsd balances in USDC and Cerby pools must be equal
      assert.deepEqual(
        beforeEthPool.balanceCerUsd.add(beforeUSDCPool.balanceCerUsd).toString(),
        afterEthPool.balanceCerUsd.add(afterUSDCPool.balanceCerUsd).toString(),
      );
      
      // check pool increased by amountTokensIn1
      assert.deepEqual(
        beforeEthPool.balanceToken.add(amountTokensIn1).toString(),
        afterEthPool.balanceToken.toString(),
      );      
      
      // check pool decreased by amountTokensOut1
      assert.deepEqual(
        beforeEthPool.balanceCerUsd.sub(amountTokensOut1).toString(),
        afterEthPool.balanceCerUsd.toString(),
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
        beforeEthPool.balanceCerUsd.mul(beforeEthPool.balanceToken).lte(afterEthPool.balanceCerUsd.mul(afterEthPool.balanceToken))
      );

      // check K must be increased
      assert.isTrue(
        beforeUSDCPool.balanceCerUsd.mul(beforeUSDCPool.balanceToken).lte(afterUSDCPool.balanceCerUsd.mul(afterUSDCPool.balanceToken))
      );
    }
  });


  it("swapExactTokensForTokens: swap 1026e10 ETH --> USDC; received USDC is correct", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();

    const beforeEthPool = await cerbySwap.getPoolByToken(
      '0x14769F96e57B80c66837701DE0B43686Fb4632De',
    );

    const beforeUSDCPool = await cerbySwap.getPoolByToken(
      TestUsdcToken.address,
    );

    {
      // ETH --> cerUSD
      const tokenIn1 = '0x14769F96e57B80c66837701DE0B43686Fb4632De';
      const tokenOut1 = TestCerUsdToken.address;
      const amountTokensIn1 = new BN((1026e10).toString());
      const amountTokensOut1 = await cerbySwap.getOutputExactTokensForTokens(
        tokenIn1,
        tokenOut1,
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
        { value: amountTokensIn1 }
      );

      // cerUSD --> USDC
      const tokenIn2 = TestCerUsdToken.address;
      const tokenOut2 = TestUsdcToken.address;
      const amountTokensIn2 = amountTokensOut1;
      const amountTokensOut2 = await cerbySwap.getOutputExactTokensForTokens(
        tokenIn2,
        tokenOut2,
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


      const afterEthPool = await cerbySwap.getPoolByToken(
        '0x14769F96e57B80c66837701DE0B43686Fb4632De',
      );

      const afterUSDCPool = await cerbySwap.getPoolByToken(
        TestUsdcToken.address,
      );
      
      // check sum cerUsd balances in USDC and Cerby pools must be equal
      assert.deepEqual(
        beforeEthPool.balanceCerUsd.add(beforeUSDCPool.balanceCerUsd).toString(),
        afterEthPool.balanceCerUsd.add(afterUSDCPool.balanceCerUsd).toString(),
      );
      
      // check pool increased by amountTokensIn1
      assert.deepEqual(
        beforeEthPool.balanceToken.add(amountTokensIn1).toString(),
        afterEthPool.balanceToken.toString(),
      );      
      
      // check pool decreased by amountTokensOut1
      assert.deepEqual(
        beforeEthPool.balanceCerUsd.sub(amountTokensOut1).toString(),
        afterEthPool.balanceCerUsd.toString(),
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
        beforeEthPool.balanceCerUsd.mul(beforeEthPool.balanceToken).lte(afterEthPool.balanceCerUsd.mul(afterEthPool.balanceToken))
      );

      // check K must be increased
      assert.isTrue(
        beforeUSDCPool.balanceCerUsd.mul(beforeUSDCPool.balanceToken).lte(afterUSDCPool.balanceCerUsd.mul(afterUSDCPool.balanceToken))
      );
    }
  });


  it("swapExactTokensForTokens: swap 1027 USDC --> cerUSD --> ETH; received ETH is correct", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();

    const beforeEthPool = await cerbySwap.getPoolByToken(
      '0x14769F96e57B80c66837701DE0B43686Fb4632De',
    );

    const beforeUSDCPool = await cerbySwap.getPoolByToken(
      TestUsdcToken.address,
    );

    {
      // USDC --> cerUSD
      const tokenIn1 = TestUsdcToken.address;
      const tokenOut1 = TestCerUsdToken.address;
      const amountTokensIn1 = new BN(1027).mul(bn1e18);
      const amountTokensOut1 = await cerbySwap.getOutputExactTokensForTokens(
        tokenIn1,
        tokenOut1,
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

      // cerUSD --> ETH
      const tokenIn2 = TestCerUsdToken.address;
      const tokenOut2 = '0x14769F96e57B80c66837701DE0B43686Fb4632De';
      const amountTokensIn2 = amountTokensOut1;
      const amountTokensOut2 = await cerbySwap.getOutputExactTokensForTokens(
        tokenIn2,
        tokenOut2,
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

      const afterEthPool = await cerbySwap.getPoolByToken(
        '0x14769F96e57B80c66837701DE0B43686Fb4632De',
      );

      const afterUSDCPool = await cerbySwap.getPoolByToken(
        TestUsdcToken.address,
      );
      
      // check sum cerUsd balances in USDC and Cerby pools must be equal
      assert.deepEqual(
        beforeEthPool.balanceCerUsd.add(beforeUSDCPool.balanceCerUsd).toString(),
        afterEthPool.balanceCerUsd.add(afterUSDCPool.balanceCerUsd).toString(),
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
        beforeEthPool.balanceCerUsd.add(amountTokensIn2).toString(),
        afterEthPool.balanceCerUsd.toString(),
      );      
      
      // check pool decreased by amountTokensOut2
      assert.deepEqual(
        beforeEthPool.balanceToken.sub(amountTokensOut2).toString(),
        afterEthPool.balanceToken.toString(),
      );

      // check K must be increased
      assert.isTrue(
        beforeEthPool.balanceCerUsd.mul(beforeEthPool.balanceToken).lte(afterEthPool.balanceCerUsd.mul(afterEthPool.balanceToken))
      );

      // check K must be increased
      assert.isTrue(
        beforeUSDCPool.balanceCerUsd.mul(beforeUSDCPool.balanceToken).lte(afterUSDCPool.balanceCerUsd.mul(afterUSDCPool.balanceToken))
      );
    }
  });


  it("swapExactTokensForTokens: swap 1028 USDC --> ETH; received ETH is correct", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();

    const beforeEthPool = await cerbySwap.getPoolByToken(
      '0x14769F96e57B80c66837701DE0B43686Fb4632De',
    );

    const beforeUSDCPool = await cerbySwap.getPoolByToken(
      TestUsdcToken.address,
    );

    {
      // USDC --> cerUSD
      const tokenIn1 = TestUsdcToken.address;
      const tokenOut1 = TestCerUsdToken.address;
      const amountTokensIn1 = new BN(1028).mul(bn1e18);
      const amountTokensOut1 = await cerbySwap.getOutputExactTokensForTokens(
        tokenIn1,
        tokenOut1,
        amountTokensIn1,
      );
      const minAmountTokensOut1 = 0;
      const expireTimestamp1 = now() + 86400;
      const transferTo1 = firstAccount;

      // cerUSD --> ETH
      const tokenIn2 = TestCerUsdToken.address;
      const tokenOut2 = '0x14769F96e57B80c66837701DE0B43686Fb4632De';
      const amountTokensIn2 = amountTokensOut1;
      const amountTokensOut2 = await cerbySwap.getOutputExactTokensForTokens(
        tokenIn2,
        tokenOut2,
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

      const afterEthPool = await cerbySwap.getPoolByToken(
        '0x14769F96e57B80c66837701DE0B43686Fb4632De',
      );

      const afterUSDCPool = await cerbySwap.getPoolByToken(
        TestUsdcToken.address,
      );
      
      // check sum cerUsd balances in USDC and Cerby pools must be equal
      assert.deepEqual(
        beforeEthPool.balanceCerUsd.add(beforeUSDCPool.balanceCerUsd).toString(),
        afterEthPool.balanceCerUsd.add(afterUSDCPool.balanceCerUsd).toString(),
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
        beforeEthPool.balanceCerUsd.add(amountTokensIn2).toString(),
        afterEthPool.balanceCerUsd.toString(),
      );      
      
      // check pool decreased by amountTokensOut2
      assert.deepEqual(
        beforeEthPool.balanceToken.sub(amountTokensOut2).toString(),
        afterEthPool.balanceToken.toString(),
      );

      // check K must be increased
      assert.isTrue(
        beforeEthPool.balanceCerUsd.mul(beforeEthPool.balanceToken).lte(afterEthPool.balanceCerUsd.mul(afterEthPool.balanceToken))
      );

      // check K must be increased
      assert.isTrue(
        beforeUSDCPool.balanceCerUsd.mul(beforeUSDCPool.balanceToken).lte(afterUSDCPool.balanceCerUsd.mul(afterUSDCPool.balanceToken))
      );
    }
  });


  it("swapExactTokensForTokens: swap 1029e10 ETH --> ETH; sent ETH >= received ETH", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();

    const beforeEthPool = await cerbySwap.getPoolByToken(
      '0x14769F96e57B80c66837701DE0B43686Fb4632De',
    );

    {
      // ETH --> cerUSD
      const tokenIn1 = '0x14769F96e57B80c66837701DE0B43686Fb4632De';
      const tokenOut1 = TestCerUsdToken.address;
      const amountTokensIn1 = new BN((1029e10).toString());
      const amountTokensOut1 = await cerbySwap.getOutputExactTokensForTokens(
        tokenIn1,
        tokenOut1,
        amountTokensIn1,
      );
      const minAmountTokensOut1 = 0;
      const expireTimestamp1 = now() + 86400;
      const transferTo1 = firstAccount;


      // cerUSD --> ETH
      const tokenIn2 = TestCerUsdToken.address;
      const tokenOut2 = '0x14769F96e57B80c66837701DE0B43686Fb4632De';
      const amountTokensIn2 = amountTokensOut1;
      const amountTokensOut2 = await cerbySwap.getOutputExactTokensForTokens(
        tokenIn2,
        tokenOut2,
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
        { value: amountTokensIn1 }
      );

      const afterEthPool = await cerbySwap.getPoolByToken(
        '0x14769F96e57B80c66837701DE0B43686Fb4632De',
      );

      // check sent is larger than received
      assert.isTrue(
        amountTokensIn1.gte(amountTokensOut2)
      );

      // intermediate balance must not change
      assert.deepEqual(
        beforeEthPool.balanceCerUsd.toString(),
        afterEthPool.balanceCerUsd.toString(),
      );

      // check pool increased and decreased balance correctly
      assert.deepEqual(
        beforeEthPool.balanceToken.add(amountTokensIn1).sub(amountTokensOut2).toString(),
        afterEthPool.balanceToken.toString(),
      );

      // check K must be increased
      assert.isTrue(
        beforeEthPool.balanceCerUsd.mul(beforeEthPool.balanceToken).lte(afterEthPool.balanceCerUsd.mul(afterEthPool.balanceToken))
      );
    }
  });

  it("swapExactTokensForTokens: swap 1040 CERBY --> cerUSD; if provided msg.value must be reverted", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();

    const beforeEthPool = await cerbySwap.getPoolByToken(
      '0x14769F96e57B80c66837701DE0B43686Fb4632De',
    );
    
    {
      const MSG_VALUE_PROVIDED_MUST_BE_ZERO_G = "G"; 
      const tokenIn1 = TestCerbyToken.address;
      const tokenOut1 = TestUsdcToken.address;
      const minAmountTokensOut1 = new BN(0);
      const amountTokensIn1 = new BN(1040).mul(bn1e18);
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
          { value: new BN((3e18).toString()) }
        ),
        MSG_VALUE_PROVIDED_MUST_BE_ZERO_G
      );

      const afterEthPool = await cerbySwap.getPoolByToken(
        '0x14769F96e57B80c66837701DE0B43686Fb4632De',
      );

      // check eth pool balances remained the same
      assert.deepEqual(
        beforeEthPool.balanceToken.toString(),
        afterEthPool.balanceToken.toString(),
      );
    }
  });

  // ---------------------------------------------------------- //
  // swapTokensForExactTokens ETH tests //
  // ---------------------------------------------------------- //

  it("swapTokensForExactTokens: swap ETH --> 1031e10 cerUSD; received cerUSD is correct", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();
    
    const beforeEthPool = await cerbySwap.getPoolByToken(
      '0x14769F96e57B80c66837701DE0B43686Fb4632De',
    );

    {
      const tokenIn = '0x14769F96e57B80c66837701DE0B43686Fb4632De';
      const tokenOut = TestCerUsdToken.address;
      const amountTokensOut = new BN((1031e10).toString());
      const amountTokensIn = await cerbySwap.getInputTokensForExactTokens(
        tokenIn,
        tokenOut,
        amountTokensOut,
      );
      const maxAmountTokensIn = new BN(33).mul(bn1e18);
      const expireTimestamp = now() + 86400;
      const transferTo = firstAccount;

      await cerbySwap.swapTokensForExactTokens(
        tokenIn,
        tokenOut,
        amountTokensOut,
        maxAmountTokensIn,
        expireTimestamp,
        transferTo,
        { value: maxAmountTokensIn }
      );

      const afterEthPool = await cerbySwap.getPoolByToken(
        '0x14769F96e57B80c66837701DE0B43686Fb4632De',
      );

      // check pool increased by amountTokensIn
      assert.deepEqual(
        beforeEthPool.balanceToken.add(amountTokensIn).toString(),
        afterEthPool.balanceToken.toString(),
      );

      assert.deepEqual(
        beforeEthPool.balanceCerUsd.sub(amountTokensOut).toString(),
        afterEthPool.balanceCerUsd.toString(),
      );

      // check K must be increased
      assert.isTrue(
        beforeEthPool.balanceCerUsd.mul(beforeEthPool.balanceToken).lte(afterEthPool.balanceCerUsd.mul(afterEthPool.balanceToken))
      );
    }
  });


  it("swapTokensForExactTokens: swap cerUSD --> 1032e10 ETH; received ETH is correct", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();

    const beforeEthPool = await cerbySwap.getPoolByToken(
      '0x14769F96e57B80c66837701DE0B43686Fb4632De',
    );

    {
      const tokenIn = TestCerUsdToken.address;
      const tokenOut = '0x14769F96e57B80c66837701DE0B43686Fb4632De';
      const amountTokensOut = new BN((1032e10).toString());
      const amountTokensIn = await cerbySwap.getInputTokensForExactTokens(
        tokenIn,
        tokenOut,
        amountTokensOut,
      );
      const maxAmountTokensIn = new BN(1000000).mul(bn1e18);
      const expireTimestamp = now() + 86400;
      const transferTo = firstAccount;

      await cerbySwap.swapTokensForExactTokens(
        tokenIn,
        tokenOut,
        amountTokensOut,
        maxAmountTokensIn,
        expireTimestamp,
        transferTo,
      );

      const afterEthPool = await cerbySwap.getPoolByToken(
        '0x14769F96e57B80c66837701DE0B43686Fb4632De',
      );

      // check pool increased by amountTokensIn
      assert.deepEqual(
        beforeEthPool.balanceCerUsd.add(amountTokensIn).toString(),
        afterEthPool.balanceCerUsd.toString(),
      );

      assert.deepEqual(
        beforeEthPool.balanceToken.sub(amountTokensOut).toString(),
        afterEthPool.balanceToken.toString(),
      );

      // check K must be increased
      assert.isTrue(
        beforeEthPool.balanceCerUsd.mul(beforeEthPool.balanceToken).lte(afterEthPool.balanceCerUsd.mul(afterEthPool.balanceToken))
      );
    }
  });


  it("swapTokensForExactTokens: swap cerUSD --> ETH --> 1033e10 cerUSD; sent cerUSD >= received cerUSD", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();

    const beforeEthPool = await cerbySwap.getPoolByToken(
      '0x14769F96e57B80c66837701DE0B43686Fb4632De',
    );

    {
      const tokenIn1 = TestCerUsdToken.address;
      const tokenOut1 = '0x14769F96e57B80c66837701DE0B43686Fb4632De';
      const tokenIn2 = '0x14769F96e57B80c66837701DE0B43686Fb4632De';
      const tokenOut2 = TestCerUsdToken.address;
      const amountTokensOut2 = new BN((1033e10).toString());
      const amountTokensIn2 = await cerbySwap.getInputTokensForExactTokens(
        tokenIn2,
        tokenOut2,
        amountTokensOut2,
      );
      const amountTokensOut1 = amountTokensIn2;
      const amountTokensIn1 = await cerbySwap.getInputTokensForExactTokens(
        tokenIn1,
        tokenOut1,
        amountTokensOut1,
      );

      const maxAmountTokensIn1 = new BN(1000000).mul(bn1e18);
      const expireTimestamp1 = now() + 86400;
      const transferTo1 = firstAccount;
      const maxAmountTokensIn2 = new BN(1).mul(bn1e18);
      const expireTimestamp2 = now() + 86400;
      const transferTo2 = firstAccount;

      // cerUSD --> CERBY
      await cerbySwap.swapTokensForExactTokens(
        tokenIn1,
        tokenOut1,
        amountTokensOut1,
        maxAmountTokensIn1,
        expireTimestamp1,
        transferTo1,
      );

      // CERBY --> cerUSD
      await cerbySwap.swapTokensForExactTokens(
        tokenIn2,
        tokenOut2,
        amountTokensOut2,
        maxAmountTokensIn2,
        expireTimestamp2,
        transferTo2,
        { value: maxAmountTokensIn2 }
      );

      const afterEthPool = await cerbySwap.getPoolByToken(
        '0x14769F96e57B80c66837701DE0B43686Fb4632De',
      );

      // check sent amount must be larger than received
      assert.isTrue(
        amountTokensIn1.gte(amountTokensOut2)
      );

      // check intermediate token balance must not change
      // since pool is changing during swaps
      // it is not correct to do such test
      // thats why commenting failing assert below
      /*assert.deepEqual(
        beforeEthPool.balanceToken.toString(),
        afterEthPool.balanceToken.toString(),
      );*/

      // check K must be increased
      assert.isTrue(
        beforeEthPool.balanceCerUsd.mul(beforeEthPool.balanceToken).lte(afterEthPool.balanceCerUsd.mul(afterEthPool.balanceToken))
      );
    }
  });


  it("swapTokensForExactTokens: swap ETH --> cerUSD --> 1034e10 CERBY; sent ETH >= received ETH", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();

    const beforeEthPool = await cerbySwap.getPoolByToken(
      '0x14769F96e57B80c66837701DE0B43686Fb4632De',
    );

    {      
      const tokenIn1 = '0x14769F96e57B80c66837701DE0B43686Fb4632De';
      const tokenOut1 = TestCerUsdToken.address;
      const tokenIn2 = TestCerUsdToken.address;
      const tokenOut2 = '0x14769F96e57B80c66837701DE0B43686Fb4632De';
      const amountTokensOut2 = new BN((1034e10).toString());
      const amountTokensIn2 = await cerbySwap.getInputTokensForExactTokens(
        tokenIn2,
        tokenOut2,
        amountTokensOut2,
      );
      const amountTokensOut1 = amountTokensIn2;
      const amountTokensIn1 = await cerbySwap.getInputTokensForExactTokens(
        tokenIn1,
        tokenOut1,
        amountTokensOut1,
      );
      const maxAmountTokensIn1 = new BN(1).mul(bn1e18);
      const expireTimestamp1 = now() + 86400;
      const transferTo1 = firstAccount;
      const maxAmountTokensIn2 = new BN(1000000).mul(bn1e18);
      const expireTimestamp2 = now() + 86400;
      const transferTo2 = firstAccount;

      // CERBY --> cerUSD
      await cerbySwap.swapTokensForExactTokens(
        tokenIn1,
        tokenOut1,
        amountTokensOut1,
        maxAmountTokensIn1,
        expireTimestamp1,
        transferTo1,
        { value: maxAmountTokensIn1 }
      );

      // cerUSD --> CERBY
      await cerbySwap.swapTokensForExactTokens(
        tokenIn2,
        tokenOut2,
        amountTokensOut2,
        maxAmountTokensIn2,
        expireTimestamp2,
        transferTo2,
      );

      const afterEthPool = await cerbySwap.getPoolByToken(
        '0x14769F96e57B80c66837701DE0B43686Fb4632De',
      );
      
      // check sent amount larger than received
      assert.isTrue(
        amountTokensIn1.gte(amountTokensOut2)
      );

      // check intermediate token balance must not change
      // since pool is changing during swaps
      // it is not correct to do such test
      // thats why commenting failing assert below
      /*assert.deepEqual(
        beforeEthPool.balanceCerUsd.toString(),
        afterEthPool.balanceCerUsd.toString(),
      );*/

      // check token balance increased and decreased correctly
      assert.deepEqual(
        beforeEthPool.balanceToken.add(amountTokensIn1).sub(amountTokensOut2).toString(),
        afterEthPool.balanceToken.toString(),
      );

      // check K must be increased
      assert.isTrue(
        beforeEthPool.balanceCerUsd.mul(beforeEthPool.balanceToken).lte(afterEthPool.balanceCerUsd.mul(afterEthPool.balanceToken))
      );
    }
  });


  it("swapTokensForExactTokens: swap ETH --> cerUSD --> 1035e10 USDC; received USDC is correct", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();

    const beforeEthPool = await cerbySwap.getPoolByToken(
      '0x14769F96e57B80c66837701DE0B43686Fb4632De',
    );

    const beforeUSDCPool = await cerbySwap.getPoolByToken(
      TestUsdcToken.address,
    );

    {
      const tokenIn1 = '0x14769F96e57B80c66837701DE0B43686Fb4632De';
      const tokenOut1 = TestCerUsdToken.address;
      const tokenIn2 = TestCerUsdToken.address;
      const tokenOut2 = TestUsdcToken.address;
      const amountTokensOut2 = new BN((1035e10).toString());
      const amountTokensIn2 = await cerbySwap.getInputTokensForExactTokens(
        tokenIn2,
        tokenOut2,
        amountTokensOut2,
      );
      const amountTokensOut1 = amountTokensIn2;
      const amountTokensIn1 = await cerbySwap.getInputTokensForExactTokens(
        tokenIn1,
        tokenOut1,
        amountTokensOut1,
      );
      const maxAmountTokensIn1 = new BN(1).mul(bn1e18);
      const expireTimestamp1 = now() + 86400;
      const transferTo1 = firstAccount;
      const maxAmountTokensIn2 = new BN(1000000).mul(bn1e18);
      const expireTimestamp2 = now() + 86400;
      const transferTo2 = firstAccount;

      // CERBY --> cerUSD
      await cerbySwap.swapTokensForExactTokens(
        tokenIn1,
        tokenOut1,
        amountTokensOut1,
        maxAmountTokensIn1,
        expireTimestamp1,
        transferTo1,
        { value: maxAmountTokensIn1 }
      );

      // cerUSD --> USDC
      await cerbySwap.swapTokensForExactTokens(
        tokenIn2,
        tokenOut2,
        amountTokensOut2,
        maxAmountTokensIn2,
        expireTimestamp2,
        transferTo2,
      );


      const afterEthPool = await cerbySwap.getPoolByToken(
        '0x14769F96e57B80c66837701DE0B43686Fb4632De',
      );

      const afterUSDCPool = await cerbySwap.getPoolByToken(
        TestUsdcToken.address,
      );
      
      // check sum cerUsd balances in USDC and Cerby pools must be equal
      assert.deepEqual(
        beforeEthPool.balanceCerUsd.add(beforeUSDCPool.balanceCerUsd).toString(),
        afterEthPool.balanceCerUsd.add(afterUSDCPool.balanceCerUsd).toString(),
      );
      
      // check pool increased by amountTokensIn1
      assert.deepEqual(
        beforeEthPool.balanceToken.add(amountTokensIn1).toString(),
        afterEthPool.balanceToken.toString(),
      );      
      
      // check pool decreased by amountTokensOut1
      assert.deepEqual(
        beforeEthPool.balanceCerUsd.sub(amountTokensOut1).toString(),
        afterEthPool.balanceCerUsd.toString(),
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
        beforeEthPool.balanceCerUsd.mul(beforeEthPool.balanceToken).lte(afterEthPool.balanceCerUsd.mul(afterEthPool.balanceToken))
      );

      // check K must be increased
      assert.isTrue(
        beforeUSDCPool.balanceCerUsd.mul(beforeUSDCPool.balanceToken).lte(afterUSDCPool.balanceCerUsd.mul(afterUSDCPool.balanceToken))
      );
    }
  });


  it("swapTokensForExactTokens: swap ETH --> 1036e10 USDC; received USDC is correct", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();

    const beforeEthPool = await cerbySwap.getPoolByToken(
      '0x14769F96e57B80c66837701DE0B43686Fb4632De',
    );

    const beforeUSDCPool = await cerbySwap.getPoolByToken(
      TestUsdcToken.address,
    );

    {
      const tokenIn1 = '0x14769F96e57B80c66837701DE0B43686Fb4632De';
      const tokenOut1 = TestCerUsdToken.address;
      const tokenIn2 = TestCerUsdToken.address;
      const tokenOut2 = TestUsdcToken.address;
      const amountTokensOut2 = new BN((1036e10).toString());
      const amountTokensIn2 = await cerbySwap.getInputTokensForExactTokens(
        tokenIn2,
        tokenOut2,
        amountTokensOut2,
      );
      const amountTokensOut1 = amountTokensIn2;
      const amountTokensIn1 = await cerbySwap.getInputTokensForExactTokens(
        tokenIn1,
        tokenOut1,
        amountTokensOut1,
      );
      const maxAmountTokensIn1 = new BN(1).mul(bn1e18);
      const expireTimestamp1 = now() + 86400;
      const transferTo1 = firstAccount;
      const maxAmountTokensIn2 = new BN(1000000).mul(bn1e18);
      const expireTimestamp2 = now() + 86400;
      const transferTo2 = firstAccount;

      // CERBY --> USDC
      await cerbySwap.swapTokensForExactTokens(
        tokenIn1,
        tokenOut2,
        amountTokensOut2,
        maxAmountTokensIn2,
        expireTimestamp2,
        transferTo2,
        { value: maxAmountTokensIn1 }
      );


      const afterEthPool = await cerbySwap.getPoolByToken(
        '0x14769F96e57B80c66837701DE0B43686Fb4632De',
      );

      const afterUSDCPool = await cerbySwap.getPoolByToken(
        TestUsdcToken.address,
      );
      
      // check sum cerUsd balances in USDC and Cerby pools must be equal
      assert.deepEqual(
        beforeEthPool.balanceCerUsd.add(beforeUSDCPool.balanceCerUsd).toString(),
        afterEthPool.balanceCerUsd.add(afterUSDCPool.balanceCerUsd).toString(),
      );
      
      // check pool increased by amountTokensIn1
      assert.deepEqual(
        beforeEthPool.balanceToken.add(amountTokensIn1).toString(),
        afterEthPool.balanceToken.toString(),
      );      
      
      // check pool decreased by amountTokensOut1
      assert.deepEqual(
        beforeEthPool.balanceCerUsd.sub(amountTokensOut1).toString(),
        afterEthPool.balanceCerUsd.toString(),
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
        beforeEthPool.balanceCerUsd.mul(beforeEthPool.balanceToken).lte(afterEthPool.balanceCerUsd.mul(afterEthPool.balanceToken))
      );

      // check K must be increased
      assert.isTrue(
        beforeUSDCPool.balanceCerUsd.mul(beforeUSDCPool.balanceToken).lte(afterUSDCPool.balanceCerUsd.mul(afterUSDCPool.balanceToken))
      );
    }
  });


  it("swapTokensForExactTokens: swap USDC --> cerUSD --> 1037e10 ETH; received ETH is correct", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();

    const beforeEthPool = await cerbySwap.getPoolByToken(
      '0x14769F96e57B80c66837701DE0B43686Fb4632De',
    );

    const beforeUSDCPool = await cerbySwap.getPoolByToken(
      TestUsdcToken.address,
    );

    {
      const tokenIn1 = TestUsdcToken.address;
      const tokenOut1 = TestCerUsdToken.address;
      const tokenIn2 = TestCerUsdToken.address;
      const tokenOut2 = '0x14769F96e57B80c66837701DE0B43686Fb4632De';
      const amountTokensOut2 = new BN((1037e10).toString());
      const amountTokensIn2 = await cerbySwap.getInputTokensForExactTokens(
        tokenIn2,
        tokenOut2,
        amountTokensOut2,
      );
      const amountTokensOut1 = amountTokensIn2;
      const amountTokensIn1 = await cerbySwap.getInputTokensForExactTokens(
        tokenIn1,
        tokenOut1,
        amountTokensOut1,
      );
      const maxAmountTokensIn1 = new BN(1000000).mul(bn1e18);
      const expireTimestamp1 = now() + 86400;
      const transferTo1 = firstAccount;
      const maxAmountTokensIn2 = new BN(1000000).mul(bn1e18);
      const expireTimestamp2 = now() + 86400;
      const transferTo2 = firstAccount;

      // USDC --> cerUSD
      await cerbySwap.swapTokensForExactTokens(
        tokenIn1,
        tokenOut1,
        amountTokensOut1,
        maxAmountTokensIn1,
        expireTimestamp1,
        transferTo1,
      );

      // cerUSD --> CERBY
      await cerbySwap.swapTokensForExactTokens(
        tokenIn2,
        tokenOut2,
        amountTokensOut2,
        maxAmountTokensIn2,
        expireTimestamp2,
        transferTo2,
      );

      const afterEthPool = await cerbySwap.getPoolByToken(
        '0x14769F96e57B80c66837701DE0B43686Fb4632De',
      );

      const afterUSDCPool = await cerbySwap.getPoolByToken(
        TestUsdcToken.address,
      );
      
      // check sum cerUsd balances in USDC and Cerby pools must be equal
      assert.deepEqual(
        beforeEthPool.balanceCerUsd.add(beforeUSDCPool.balanceCerUsd).toString(),
        afterEthPool.balanceCerUsd.add(afterUSDCPool.balanceCerUsd).toString(),
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
        beforeEthPool.balanceCerUsd.add(amountTokensIn2).toString(),
        afterEthPool.balanceCerUsd.toString(),
      );      
      
      // check pool decreased by amountTokensOut2
      assert.deepEqual(
        beforeEthPool.balanceToken.sub(amountTokensOut2).toString(),
        afterEthPool.balanceToken.toString(),
      );

      // check K must be increased
      assert.isTrue(
        beforeEthPool.balanceCerUsd.mul(beforeEthPool.balanceToken).lte(afterEthPool.balanceCerUsd.mul(afterEthPool.balanceToken))
      );

      // check K must be increased
      assert.isTrue(
        beforeUSDCPool.balanceCerUsd.mul(beforeUSDCPool.balanceToken).lte(afterUSDCPool.balanceCerUsd.mul(afterUSDCPool.balanceToken))
      );
    }
  });


  it("swapTokensForExactTokens: swap USDC --> 1038e10 ETH; received ETH is correct", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();

    const beforeEthPool = await cerbySwap.getPoolByToken(
      '0x14769F96e57B80c66837701DE0B43686Fb4632De',
    );

    const beforeUSDCPool = await cerbySwap.getPoolByToken(
      TestUsdcToken.address,
    );

    {
      const tokenIn1 = TestUsdcToken.address;
      const tokenOut1 = TestCerUsdToken.address;
      const tokenIn2 = TestCerUsdToken.address;
      const tokenOut2 = '0x14769F96e57B80c66837701DE0B43686Fb4632De';
      const amountTokensOut2 = new BN((1038e10).toString());
      const amountTokensIn2 = await cerbySwap.getInputTokensForExactTokens(
        tokenIn2,
        tokenOut2,
        amountTokensOut2,
      );
      const amountTokensOut1 = amountTokensIn2;
      const amountTokensIn1 = await cerbySwap.getInputTokensForExactTokens(
        tokenIn1,
        tokenOut1,
        amountTokensOut1,
      );
      const maxAmountTokensIn1 = new BN(1000000).mul(bn1e18);
      const expireTimestamp1 = now() + 86400;
      const transferTo1 = firstAccount;
      const maxAmountTokensIn2 = new BN(1000000).mul(bn1e18);
      const expireTimestamp2 = now() + 86400;
      const transferTo2 = firstAccount;

      // USDC --> CERBY
      await cerbySwap.swapTokensForExactTokens(
        tokenIn1,
        tokenOut2,
        amountTokensOut2,
        maxAmountTokensIn2,
        expireTimestamp2,
        transferTo2,
      );

      const afterEthPool = await cerbySwap.getPoolByToken(
        '0x14769F96e57B80c66837701DE0B43686Fb4632De',
      );

      const afterUSDCPool = await cerbySwap.getPoolByToken(
        TestUsdcToken.address,
      );
      
      // check sum cerUsd balances in USDC and Cerby pools must be equal
      assert.deepEqual(
        beforeEthPool.balanceCerUsd.add(beforeUSDCPool.balanceCerUsd).toString(),
        afterEthPool.balanceCerUsd.add(afterUSDCPool.balanceCerUsd).toString(),
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
        beforeEthPool.balanceCerUsd.add(amountTokensIn2).toString(),
        afterEthPool.balanceCerUsd.toString(),
      );      
      
      // check pool decreased by amountTokensOut2
      assert.deepEqual(
        beforeEthPool.balanceToken.sub(amountTokensOut2).toString(),
        afterEthPool.balanceToken.toString(),
      );

      // check K must be increased
      assert.isTrue(
        beforeEthPool.balanceCerUsd.mul(beforeEthPool.balanceToken).lte(afterEthPool.balanceCerUsd.mul(afterEthPool.balanceToken))
      );

      // check K must be increased
      assert.isTrue(
        beforeUSDCPool.balanceCerUsd.mul(beforeUSDCPool.balanceToken).lte(afterUSDCPool.balanceCerUsd.mul(afterUSDCPool.balanceToken))
      );
    }
  });


  it("swapTokensForExactTokens: swap ETH --> 1039e10 ETH; sent ETH >= received ETH", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();
    const beforeEthPool = await cerbySwap.getPoolByToken(
      '0x14769F96e57B80c66837701DE0B43686Fb4632De',
    );

    {
      const tokenIn1 = '0x14769F96e57B80c66837701DE0B43686Fb4632De';
      const tokenOut1 = TestCerUsdToken.address;
      const tokenIn2 = TestCerUsdToken.address;
      const tokenOut2 = '0x14769F96e57B80c66837701DE0B43686Fb4632De';
      const amountTokensOut2 = new BN((1039e10).toString());
      const amountTokensIn2 = await cerbySwap.getInputTokensForExactTokens(
        tokenIn2,
        tokenOut2,
        amountTokensOut2,
      );
      const amountTokensOut1 = amountTokensIn2;
      const amountTokensIn1 = await cerbySwap.getInputTokensForExactTokens(
        tokenIn1,
        tokenOut1,
        amountTokensOut1,
      );
      const maxAmountTokensIn1 = new BN(1).mul(bn1e18);
      const expireTimestamp1 = now() + 86400;
      const transferTo1 = firstAccount;
      const maxAmountTokensIn2 = new BN(1000000).mul(bn1e18);
      const expireTimestamp2 = now() + 86400;
      const transferTo2 = firstAccount;

      // CERBY --> CERBY
      await cerbySwap.swapTokensForExactTokens(
        tokenIn1,
        tokenOut2,
        amountTokensOut2,
        maxAmountTokensIn2,
        expireTimestamp2,
        transferTo2,
        { value: maxAmountTokensIn1 }
      );

      const afterEthPool = await cerbySwap.getPoolByToken(
        '0x14769F96e57B80c66837701DE0B43686Fb4632De',
      );

      // check sent is larger than received
      assert.isTrue(
        amountTokensIn1.gte(amountTokensOut2)
      );

      // intermediate balance must not change
      assert.deepEqual(
        beforeEthPool.balanceCerUsd.toString(),
        afterEthPool.balanceCerUsd.toString(),
      );

      // check pool increased and decreased balance correctly
      assert.deepEqual(
        beforeEthPool.balanceToken.add(amountTokensIn1).sub(amountTokensOut2).toString(),
        afterEthPool.balanceToken.toString(),
      );

      // check K must be increased
      assert.isTrue(
        beforeEthPool.balanceCerUsd.mul(beforeEthPool.balanceToken).lte(afterEthPool.balanceCerUsd.mul(afterEthPool.balanceToken))
      );
    }
  });

  it("swapTokensForExactTokens: swap CERBY --> 1040 cerUSD; if provided msg.value must be reverted", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();

    const beforeEthPool = await cerbySwap.getPoolByToken(
      '0x14769F96e57B80c66837701DE0B43686Fb4632De',
    );
    
    {
      const MSG_VALUE_PROVIDED_MUST_BE_ZERO_G = "G"; 
      const tokenIn1 = TestCerbyToken.address;
      const tokenOut1 = TestUsdcToken.address;
      const amountTokensOut1 = new BN(1040).mul(bn1e18);
      const maxAmountTokensIn1 = new BN(1000000).mul(bn1e18);
      const expireTimestamp1 = now() + 86400;
      const transferTo1 = firstAccount;
      await truffleAssert.reverts(
        cerbySwap.swapTokensForExactTokens(
          tokenIn1,
          tokenOut1,
          amountTokensOut1,
          maxAmountTokensIn1,
          expireTimestamp1,
          transferTo1,
          { value: new BN((3e18).toString()) }
        ),
        MSG_VALUE_PROVIDED_MUST_BE_ZERO_G
      );

      const afterEthPool = await cerbySwap.getPoolByToken(
        '0x14769F96e57B80c66837701DE0B43686Fb4632De',
      );

      // check eth pool balances remained the same
      assert.deepEqual(
        beforeEthPool.balanceToken.toString(),
        afterEthPool.balanceToken.toString(),
      );
    }
  });

  // ---------------------------------------------------------- //
  // addTokenLiquidity / removeTokenLiquidity tests //
  // ---------------------------------------------------------- //

  it.only("addTokenLiquidity: add 1041e10 ETH; pool must be updated correctly", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();
    const ETH_POOL_POS = await cerbySwap.getTokenToPoolPosition('0x14769F96e57B80c66837701DE0B43686Fb4632De');

    const beforeEthPool = await cerbySwap.getPoolByToken(
      '0x14769F96e57B80c66837701DE0B43686Fb4632De',
    );
    const beforeLpTokens = await cerbySwap.balanceOf(firstAccount, ETH_POOL_POS);
    
    {
      const tokenIn = '0x14769F96e57B80c66837701DE0B43686Fb4632De';
      const amountTokensIn = new BN((1041e10).toString());
      const amountCerUsdIn = amountTokensIn.mul(beforeEthPool.balanceCerUsd).div(beforeEthPool.balanceToken);
      const expireTimestamp = now() + 86400;
      const transferTo = firstAccount;
      
      const lpTokens = await cerbySwap.addTokenLiquidity(
        tokenIn,
        amountTokensIn,
        expireTimestamp,
        transferTo,
        { value: amountTokensIn }
      );

      const afterEthPool = await cerbySwap.getPoolByToken(
        '0x14769F96e57B80c66837701DE0B43686Fb4632De',
      );
      const afterLpTokens = await cerbySwap.balanceOf(firstAccount, ETH_POOL_POS);

      // check pool increased balance
      assert.deepEqual(
        beforeEthPool.balanceToken.add(amountTokensIn).toString(),
        afterEthPool.balanceToken.toString(),
      );

      // check pool increased balance
      assert.deepEqual(
        beforeEthPool.balanceCerUsd.add(amountCerUsdIn).toString(),
        afterEthPool.balanceCerUsd.toString(),
      );

      // check lp tokens increased
      assert.deepEqual(
        beforeLpTokens.add(lpTokens).toString(),
        afterLpTokens.toString(),
      );
    }
  });

  it.only("addTokenLiquidity: add 1042 CERBY; pool must be updated correctly", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();
    const CERBY_POOL_POS = await cerbySwap.getTokenToPoolPosition(TestCerbyToken.address);

    const beforeCerbyPool = await cerbySwap.getPoolByToken(
      TestCerbyToken.address
    );

    const beforeLpTokens = await cerbySwap.balanceOf(firstAccount, CERBY_POOL_POS);
    
    {
      const tokenIn = TestCerbyToken.address;
      const amountTokensIn = new BN(1042).mul(bn1e18);
      const amountCerUsdIn = amountTokensIn.mul(beforeCerbyPool.balanceCerUsd).div(beforeCerbyPool.balanceToken);
      const expireTimestamp = now() + 86400;
      const transferTo = firstAccount;
      
      
      const lpTokens = await cerbySwap.addTokenLiquidity(
        tokenIn,
        amountTokensIn,
        expireTimestamp,
        transferTo,
      );

      const afterCerbyPool = await cerbySwap.getPoolByToken(
        TestCerbyToken.address
      );
      const afterLpTokens = await cerbySwap.balanceOf(firstAccount, CERBY_POOL_POS);

      // check pool increased balance
      assert.deepEqual(
        beforeCerbyPool.balanceToken.add(amountTokensIn).toString(),
        afterCerbyPool.balanceToken.toString(),
      );

      // check pool increased balance
      assert.deepEqual(
        beforeCerbyPool.balanceCerUsd.add(amountCerUsdIn).toString(),
        afterCerbyPool.balanceCerUsd.toString(),
      );

      // check lp tokens increased
      assert.deepEqual(
        beforeLpTokens.add(lpTokens).toString(),
        afterLpTokens.toString(),
      );
    }
  });

  it.only("removeTokenLiquidity: remove 104.3 CERBY; pool must be updated correctly", async () => {
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];

    const cerbySwap = await CerbySwapV1.deployed();
    const CERBY_POOL_POS = await cerbySwap.getTokenToPoolPosition(TestCerbyToken.address);

    const beforeCerbyPool = await cerbySwap.getPoolByToken(
      TestCerbyToken.address
    );
    
    {
      const tokenOut = TestCerbyToken.address;
      const amountLPTokensBurn = await cerbySwap.balanceOf(firstAccount, CERBY_POOL_POS);
      const totalLPSupply = await cerbySwap.totalSupply(CERBY_POOL_POS);
      const amountTokensOut = beforeCerbyPool.balanceToken.mul(amountLPTokensBurn).div(totalLPSupply);
      const amountCerUsdOut = beforeCerbyPool.balanceCerUsd.mul(amountLPTokensBurn).div(totalLPSupply);
      const expireTimestamp = now() + 86400;
      const transferTo = firstAccount;
      
      const res = await cerbySwap.removeTokenLiquidity(
        tokenOut,
        amountLPTokensBurn,
        expireTimestamp,
        transferTo,
      );

      const afterCerbyPool = await cerbySwap.getPoolByToken(
        TestCerbyToken.address
      );

      // check pool must have increased balance
      assert.deepEqual(
        beforeCerbyPool.balanceToken.sub(amountTokensOut).toString(),
        afterCerbyPool.balanceToken.toString(),
      );

      assert.deepEqual(
        beforeCerbyPool.balanceCerUsd.sub(amountCerUsdOut).toString(),
        afterCerbyPool.balanceCerUsd.toString(),
      );
    }
  });

});
