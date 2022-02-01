import BN from "bn.js";
import crypto from "crypto";

const truffleAssert = require("truffle-assertions");

const CerbyBridgeV2 = artifacts.require("CerbyBridgeV2");

const TestNamedToken = artifacts.require("TestNamedToken");

const now = () => Math.floor(+new Date() / 1000);
const bn1e18 = new BN((1e18).toString());

let evmCerCsprToken = "0xfF06B30A102A80d3d3C82C091317D1e82Bb4aCF5";
let evmCerEthToken = "0xB58FcB5D931AC11919462c3A7A812aFdb4c89D28";
let evmCerUsdcToken = "0xe2129472461b1b28ABcA079f72E3529eC24031cD";

const tokens = [
  ["CerbyCasper", "cerCSPR"],
  ["CerbyETH", "cerETH"],
  ["CerbyUSDC", "cerUSDC"],
] as const;

const nullBurnProofHash = "0x0000000000000000000000000000000000000000000000000000000000000000";

contract("CerbyBridgeV2", () => {
  it("deploy cross-chain-bridge and 3 test tokens", async () => {
    const address = await CerbyBridgeV2.deployed().then((_) => _.address);
    
    const deployed = await Promise.all(
      tokens.map(([name, symbol]) =>
        TestNamedToken.new(name, symbol).then((some) => some.address)
      )
    );

    evmCerCsprToken = deployed[0];
    evmCerEthToken = deployed[1];
    evmCerUsdcToken = deployed[2];

    console.log("CerbyBridgeV2: " + address);
    console.log("cerCSPR Token: " + evmCerCsprToken);
    console.log("cerETH Token: " + evmCerEthToken);
    console.log("cerUSDC Token: " + evmCerUsdcToken);
  });

  it("testSetAllowancesBulk: set allowance, check value is set correctly", async () => {
    const bridge = await CerbyBridgeV2.deployed();


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
    const evmChainIdTo = (await web3.eth.getChainId()).toString();
    const evmChainType = 1;

    // checking cerCSPR allowance set
    const allowanceAllowed = 1;
    let evmAllowance = {
      burnGenericToken: evmCerCsprGenericToken,
      burnChainType: evmChainType,
      burnChainId: evmChainIdFrom,
      mintGenericToken: evmCerCsprGenericToken,
      mintChainType: evmChainType,
      mintChainId: evmChainIdTo
    };
    await bridge.testSetAllowancesBulk([
      evmAllowance
    ], allowanceAllowed);
    let evmAllowanceHash = await bridge.getAllowanceHash(evmAllowance);
    let allowanceValue = await bridge.allowances(evmAllowanceHash);
    assert.deepEqual(allowanceValue.toString(), allowanceAllowed.toString());


    // checking cerETH allowance set
    evmAllowance = {
      burnGenericToken: evmCerEthGenericToken,
      burnChainType: evmChainType,
      burnChainId: evmChainIdFrom,
      mintGenericToken: evmCerEthGenericToken,
      mintChainType: evmChainType,
      mintChainId: evmChainIdTo
    };
    await bridge.testSetAllowancesBulk([
      evmAllowance
    ], allowanceAllowed);
    evmAllowanceHash = await bridge.getAllowanceHash(evmAllowance);
    allowanceValue = await bridge.allowances(evmAllowanceHash);
    assert.deepEqual(allowanceValue.toString(), allowanceAllowed.toString());


    // checking cerUSDC allowance set
    evmAllowance = {
      burnGenericToken: evmCerUsdcGenericToken,
      burnChainType: evmChainType,
      burnChainId: evmChainIdFrom,
      mintGenericToken: evmCerUsdcGenericToken,
      mintChainType: evmChainType,
      mintChainId: evmChainIdTo
    };
    await bridge.testSetAllowancesBulk([
      evmAllowance
    ], allowanceAllowed);
    evmAllowanceHash = await bridge.getAllowanceHash(evmAllowance);
    allowanceValue = await bridge.allowances(evmAllowanceHash);
    assert.deepEqual(allowanceValue.toString(), allowanceAllowed.toString());

    // checking not existing allowance
    evmAllowance = {
      burnGenericToken: "0x" + _20bytes + '0xfF06B30A102A80d3d3C82C091317D1e82Bb4aCF5'.substring(2),
      burnChainType: evmChainType,
      burnChainId: evmChainIdFrom,
      mintGenericToken: "0x" + _20bytes + '0xfF06B30A102A80d3d3C82C091317D1e82Bb4aCF5'.substring(2),
      mintChainType: evmChainType,
      mintChainId: evmChainIdTo
    };
    evmAllowanceHash = await bridge.getAllowanceHash(evmAllowance);
    allowanceValue = await bridge.allowances(evmAllowanceHash);
    const allowanceDisabled = 0;
    assert.deepEqual(allowanceValue.toString(), allowanceDisabled.toString());
  });

  it("approveBurnProof: approve hash, check value is set correctly", async () => {
    const bridge = await CerbyBridgeV2.deployed();
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];


    const casperCerCsprToken = "0x378bDF003f218b28dfCcFe5f21D7AA6b818D1D79aC4156eDE3F1c107d323f4ad";
    const casperCerEthToken = "0x4D292244FcF091aB7B15c4B62d86ed1f40C93Ef38CF9280725370aa99Fa700c";
    const casperCerUsdcToken = "0xaC1E4705239368F33B142fD19Aec51F73d57dEb398dF5D095A14c01AbE6Cb59B";

    const _20bytes = "0000000000000000000000000000000000000000";
    const evmCerCsprGenericToken = "0x" + _20bytes + evmCerCsprToken.substring(2);
    const evmCerEthGenericToken = "0x" + _20bytes + evmCerEthToken.substring(2);
    const evmCerUsdcGenericToken = "0x" + _20bytes + evmCerUsdcToken.substring(2);
    const evmGenericCaller = "0x" + _20bytes + firstAccount.substring(2);

    const _8bytes = "0000000000000000";
    const casperCerCsprGenericToken = "0x" + _8bytes + casperCerCsprToken.substring(2);
    const casperCerEthGenericToken = "0x" + _8bytes + casperCerEthToken.substring(2);
    const casperCerUsdcGenericToken = "0x" + _8bytes + casperCerUsdcToken.substring(2);

    const casperChainId = 1010;
    const evmChainIdFrom = 123;
    const evmChainIdTo = (await web3.eth.getChainId()).toString();
    const evmChainType = 1;

    // checking cerCSPR approval set
    const hashApproved = 2;
    let evmAllowance = {
      burnGenericToken: evmCerCsprGenericToken,
      burnChainType: evmChainType,
      burnChainId: evmChainIdFrom,
      mintGenericToken: evmCerCsprGenericToken,
      mintChainType: evmChainType,
      mintChainId: evmChainIdTo
    };
    let mintAmount = new BN(1000).mul(bn1e18).toString();
    let burnNonce = await bridge.burnNonceByToken(evmCerCsprToken);
    let evmProof = {
      burnProofHash: nullBurnProofHash,
      burnGenericCaller: evmGenericCaller,
      burnNonce: burnNonce,
      mintGenericCaller: evmGenericCaller,
      mintAmount: mintAmount,
      allowance: evmAllowance
    };
    let evmBurnProofHash = await bridge.computeBurnHash(evmProof);
    await bridge.approveBurnProof(evmBurnProofHash);
    let evmProofHashValue = await bridge.burnProofStorage(evmBurnProofHash);
    assert.deepEqual(evmProofHashValue.toString(), hashApproved.toString());
  });

  it("mintWithBurnProof: check hash updated correctly", async () => {
    const bridge = await CerbyBridgeV2.deployed();
    const accounts = await web3.eth.getAccounts();
    const firstAccount = accounts[0];


    const casperCerCsprToken = "0x378bDF003f218b28dfCcFe5f21D7AA6b818D1D79aC4156eDE3F1c107d323f4ad";
    const casperCerEthToken = "0x4D292244FcF091aB7B15c4B62d86ed1f40C93Ef38CF9280725370aa99Fa700c";
    const casperCerUsdcToken = "0xaC1E4705239368F33B142fD19Aec51F73d57dEb398dF5D095A14c01AbE6Cb59B";

    const _20bytes = "0000000000000000000000000000000000000000";
    const evmCerCsprGenericToken = "0x" + _20bytes + evmCerCsprToken.substring(2);
    const evmCerEthGenericToken = "0x" + _20bytes + evmCerEthToken.substring(2);
    const evmCerUsdcGenericToken = "0x" + _20bytes + evmCerUsdcToken.substring(2);
    const evmGenericCaller = "0x" + _20bytes + firstAccount.substring(2);

    const _8bytes = "0000000000000000";
    const casperCerCsprGenericToken = "0x" + _8bytes + casperCerCsprToken.substring(2);
    const casperCerEthGenericToken = "0x" + _8bytes + casperCerEthToken.substring(2);
    const casperCerUsdcGenericToken = "0x" + _8bytes + casperCerUsdcToken.substring(2);

    const casperChainId = 1010;
    const evmChainIdFrom = 123;
    const evmChainIdTo = (await web3.eth.getChainId()).toString();
    const evmChainType = 1;

    // minting cerCSPR
    const hashBurned = 2;
    let evmAllowance = {
      burnGenericToken: evmCerCsprGenericToken,
      burnChainType: evmChainType,
      burnChainId: evmChainIdFrom,
      mintGenericToken: evmCerCsprGenericToken,
      mintChainType: evmChainType,
      mintChainId: evmChainIdTo
    };
    let mintAmount = new BN(1000).mul(bn1e18).toString();
    let burnNonce = await bridge.burnNonceByToken(evmCerCsprToken);
    let evmProof = {
      burnProofHash: nullBurnProofHash,
      burnGenericCaller: evmGenericCaller,
      burnNonce: burnNonce,
      mintGenericCaller: evmGenericCaller,
      mintAmount: mintAmount,
      allowance: evmAllowance
    };
    let evmBurnProofHash = await bridge.computeBurnHash(evmProof);
    evmProof.burnProofHash = evmBurnProofHash;

    await bridge.mintWithBurnProof(
      evmProof.allowance.burnGenericToken,
      evmProof.burnGenericCaller,
      evmProof.allowance.burnChainType,
      evmProof.allowance.burnChainId,
      evmProof.burnProofHash,
      evmProof.burnNonce,
      evmCerCsprToken,
      evmProof.mintAmount
    );


    const hashExecuted = 3;
    let evmProofHashValue = await bridge.burnProofStorage(evmBurnProofHash);
    assert.deepEqual(evmProofHashValue.toString(), hashExecuted.toString());
  });

  
});
