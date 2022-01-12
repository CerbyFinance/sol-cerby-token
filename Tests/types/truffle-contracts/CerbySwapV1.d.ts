/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import BN from "bn.js";
import { EventData, PastEventOptions } from "web3-eth-contract";

export interface CerbySwapV1Contract
  extends Truffle.Contract<CerbySwapV1Instance> {
  "new"(meta?: Truffle.TransactionDetails): Promise<CerbySwapV1Instance>;
}

export interface RoleAdminChanged {
  name: "RoleAdminChanged";
  args: {
    role: string;
    previousAdminRole: string;
    newAdminRole: string;
    0: string;
    1: string;
    2: string;
  };
}

export interface RoleGranted {
  name: "RoleGranted";
  args: {
    role: string;
    account: string;
    sender: string;
    0: string;
    1: string;
    2: string;
  };
}

export interface RoleRevoked {
  name: "RoleRevoked";
  args: {
    role: string;
    account: string;
    sender: string;
    0: string;
    1: string;
    2: string;
  };
}

type AllEvents = RoleAdminChanged | RoleGranted | RoleRevoked;

export interface CerbySwapV1Instance extends Truffle.ContractInstance {
  ROLE_ADMIN(txDetails?: Truffle.TransactionDetails): Promise<string>;

  addNativeLiquidity: {
    (transferTo: string, txDetails?: Truffle.TransactionDetails): Promise<
      Truffle.TransactionResponse<AllEvents>
    >;
    call(
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  addTokenLiquidity: {
    (
      token: string,
      amountTokensIn: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      token: string,
      amountTokensIn: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      token: string,
      amountTokensIn: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      token: string,
      amountTokensIn: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  adminCreatePool: {
    (
      token: string,
      amountTokensIn: number | BN | string,
      amountCerUsdIn: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      token: string,
      amountTokensIn: number | BN | string,
      amountCerUsdIn: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      token: string,
      amountTokensIn: number | BN | string,
      amountCerUsdIn: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      token: string,
      amountTokensIn: number | BN | string,
      amountCerUsdIn: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  adminInitialize: {
    (txDetails?: Truffle.TransactionDetails): Promise<
      Truffle.TransactionResponse<AllEvents>
    >;
    call(txDetails?: Truffle.TransactionDetails): Promise<void>;
    sendTransaction(txDetails?: Truffle.TransactionDetails): Promise<string>;
    estimateGas(txDetails?: Truffle.TransactionDetails): Promise<number>;
  };

  adminUpdateFeeToBeneficiary: {
    (
      newFeeToBeneficiary: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      newFeeToBeneficiary: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      newFeeToBeneficiary: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      newFeeToBeneficiary: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  feeToBeneficiary(txDetails?: Truffle.TransactionDetails): Promise<string>;

  getCurrent4Hour(txDetails?: Truffle.TransactionDetails): Promise<BN>;

  getInputCerUsdForExactTokens(
    poolPos: number | BN | string,
    amountTokensOut: number | BN | string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<BN>;

  getInputTokensForExactCerUsd(
    poolPos: number | BN | string,
    amountCerUsdOut: number | BN | string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<BN>;

  getOutputExactCerUsdForTokens(
    poolPos: number | BN | string,
    amountCerUsdIn: number | BN | string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<BN>;

  getOutputExactTokensForCerUsd(
    poolPos: number | BN | string,
    amountTokensIn: number | BN | string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<BN>;

  getPoolByPosition(
    pos: number | BN | string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<{
    token: string;
    balanceToken: BN;
    balanceCerUsd: BN;
    lastSqrtKValue: BN;
    hourlyTradeVolumeInCerUsd: BN[];
  }>;

  getPoolByToken(
    token: string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<{
    token: string;
    balanceToken: BN;
    balanceCerUsd: BN;
    lastSqrtKValue: BN;
    hourlyTradeVolumeInCerUsd: BN[];
  }>;

  getRoleAdmin(
    role: string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<string>;

  getRoleMember(
    role: string,
    index: number | BN | string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<string>;

  getRoleMemberCount(
    role: string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<BN>;

  getUtilsContractAtPos(
    pos: number | BN | string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<string>;

  grantRole: {
    (
      role: string,
      account: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      role: string,
      account: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      role: string,
      account: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      role: string,
      account: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  grantRolesBulk: {
    (
      roles: { role: string; addr: string }[],
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      roles: { role: string; addr: string }[],
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      roles: { role: string; addr: string }[],
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      roles: { role: string; addr: string }[],
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  hasRole(
    role: string,
    account: string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<boolean>;

  removeNativeLiquidity: {
    (
      amountLpTokensBalanceToBurn: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      amountLpTokensBalanceToBurn: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      amountLpTokensBalanceToBurn: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      amountLpTokensBalanceToBurn: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  removeTokenLiquidity: {
    (
      token: string,
      amountLpTokensBalanceToBurn: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      token: string,
      amountLpTokensBalanceToBurn: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<BN>;
    sendTransaction(
      token: string,
      amountLpTokensBalanceToBurn: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      token: string,
      amountLpTokensBalanceToBurn: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  renounceRole: {
    (
      role: string,
      account: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      role: string,
      account: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      role: string,
      account: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      role: string,
      account: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  revokeRole: {
    (
      role: string,
      account: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      role: string,
      account: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      role: string,
      account: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      role: string,
      account: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  supportsInterface(
    interfaceId: string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<boolean>;

  swapExactNativeForTokens: {
    (
      tokenOut: string,
      minAmountTokensOut: number | BN | string,
      expireTimestamp: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      tokenOut: string,
      minAmountTokensOut: number | BN | string,
      expireTimestamp: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<BN>;
    sendTransaction(
      tokenOut: string,
      minAmountTokensOut: number | BN | string,
      expireTimestamp: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      tokenOut: string,
      minAmountTokensOut: number | BN | string,
      expireTimestamp: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  swapExactTokensForNative: {
    (
      tokenIn: string,
      amountTokensIn: number | BN | string,
      minAmountTokensOut: number | BN | string,
      expireTimestamp: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      tokenIn: string,
      amountTokensIn: number | BN | string,
      minAmountTokensOut: number | BN | string,
      expireTimestamp: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<BN>;
    sendTransaction(
      tokenIn: string,
      amountTokensIn: number | BN | string,
      minAmountTokensOut: number | BN | string,
      expireTimestamp: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      tokenIn: string,
      amountTokensIn: number | BN | string,
      minAmountTokensOut: number | BN | string,
      expireTimestamp: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  swapExactTokensForTokens: {
    (
      tokenIn: string,
      tokenOut: string,
      amountTokensIn: number | BN | string,
      minAmountTokensOut: number | BN | string,
      expireTimestamp: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      tokenIn: string,
      tokenOut: string,
      amountTokensIn: number | BN | string,
      minAmountTokensOut: number | BN | string,
      expireTimestamp: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<BN>;
    sendTransaction(
      tokenIn: string,
      tokenOut: string,
      amountTokensIn: number | BN | string,
      minAmountTokensOut: number | BN | string,
      expireTimestamp: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      tokenIn: string,
      tokenOut: string,
      amountTokensIn: number | BN | string,
      minAmountTokensOut: number | BN | string,
      expireTimestamp: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  swapNativeForExactTokens: {
    (
      tokenOut: string,
      amountTokensOut: number | BN | string,
      expireTimestamp: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      tokenOut: string,
      amountTokensOut: number | BN | string,
      expireTimestamp: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<BN>;
    sendTransaction(
      tokenOut: string,
      amountTokensOut: number | BN | string,
      expireTimestamp: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      tokenOut: string,
      amountTokensOut: number | BN | string,
      expireTimestamp: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  swapTokensForExactNative: {
    (
      tokenIn: string,
      maxAmountTokensIn: number | BN | string,
      amountTokensOut: number | BN | string,
      expireTimestamp: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      tokenIn: string,
      maxAmountTokensIn: number | BN | string,
      amountTokensOut: number | BN | string,
      expireTimestamp: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<BN>;
    sendTransaction(
      tokenIn: string,
      maxAmountTokensIn: number | BN | string,
      amountTokensOut: number | BN | string,
      expireTimestamp: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      tokenIn: string,
      maxAmountTokensIn: number | BN | string,
      amountTokensOut: number | BN | string,
      expireTimestamp: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  swapTokensForExactTokens: {
    (
      tokenIn: string,
      tokenOut: string,
      maxAmountTokensIn: number | BN | string,
      amountTokensOut: number | BN | string,
      expireTimestamp: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      tokenIn: string,
      tokenOut: string,
      maxAmountTokensIn: number | BN | string,
      amountTokensOut: number | BN | string,
      expireTimestamp: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<BN>;
    sendTransaction(
      tokenIn: string,
      tokenOut: string,
      maxAmountTokensIn: number | BN | string,
      amountTokensOut: number | BN | string,
      expireTimestamp: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      tokenIn: string,
      tokenOut: string,
      maxAmountTokensIn: number | BN | string,
      amountTokensOut: number | BN | string,
      expireTimestamp: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  syncTokenBalanceInPool: {
    (token: string, txDetails?: Truffle.TransactionDetails): Promise<
      Truffle.TransactionResponse<AllEvents>
    >;
    call(token: string, txDetails?: Truffle.TransactionDetails): Promise<void>;
    sendTransaction(
      token: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      token: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  testGetBalances(
    txDetails?: Truffle.TransactionDetails
  ): Promise<{ 0: BN; 1: BN; 2: BN }>;

  testGetPools(
    txDetails?: Truffle.TransactionDetails
  ): Promise<{
    0: {
      token: string;
      balanceToken: BN;
      balanceCerUsd: BN;
      lastSqrtKValue: BN;
      hourlyTradeVolumeInCerUsd: BN[];
    };
    1: {
      token: string;
      balanceToken: BN;
      balanceCerUsd: BN;
      lastSqrtKValue: BN;
      hourlyTradeVolumeInCerUsd: BN[];
    };
  }>;

  testGetPrices(
    txDetails?: Truffle.TransactionDetails
  ): Promise<{ 0: BN; 1: BN }>;

  testGetTokenToPoolPosition(
    token: string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<BN>;

  testSetupTokens: {
    (
      _lpErc1155V1: string,
      _testCerbyToken: string,
      _cerUsdToken: string,
      _testUsdcToken: string,
      _nativeToken: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      _lpErc1155V1: string,
      _testCerbyToken: string,
      _cerUsdToken: string,
      _testUsdcToken: string,
      _nativeToken: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      _lpErc1155V1: string,
      _testCerbyToken: string,
      _cerUsdToken: string,
      _testUsdcToken: string,
      _nativeToken: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      _lpErc1155V1: string,
      _testCerbyToken: string,
      _cerUsdToken: string,
      _testUsdcToken: string,
      _nativeToken: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  methods: {
    ROLE_ADMIN(txDetails?: Truffle.TransactionDetails): Promise<string>;

    addNativeLiquidity: {
      (transferTo: string, txDetails?: Truffle.TransactionDetails): Promise<
        Truffle.TransactionResponse<AllEvents>
      >;
      call(
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    addTokenLiquidity: {
      (
        token: string,
        amountTokensIn: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        token: string,
        amountTokensIn: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        token: string,
        amountTokensIn: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        token: string,
        amountTokensIn: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    adminCreatePool: {
      (
        token: string,
        amountTokensIn: number | BN | string,
        amountCerUsdIn: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        token: string,
        amountTokensIn: number | BN | string,
        amountCerUsdIn: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        token: string,
        amountTokensIn: number | BN | string,
        amountCerUsdIn: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        token: string,
        amountTokensIn: number | BN | string,
        amountCerUsdIn: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    adminInitialize: {
      (txDetails?: Truffle.TransactionDetails): Promise<
        Truffle.TransactionResponse<AllEvents>
      >;
      call(txDetails?: Truffle.TransactionDetails): Promise<void>;
      sendTransaction(txDetails?: Truffle.TransactionDetails): Promise<string>;
      estimateGas(txDetails?: Truffle.TransactionDetails): Promise<number>;
    };

    adminUpdateFeeToBeneficiary: {
      (
        newFeeToBeneficiary: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        newFeeToBeneficiary: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        newFeeToBeneficiary: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        newFeeToBeneficiary: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    feeToBeneficiary(txDetails?: Truffle.TransactionDetails): Promise<string>;

    getCurrent4Hour(txDetails?: Truffle.TransactionDetails): Promise<BN>;

    getInputCerUsdForExactTokens(
      poolPos: number | BN | string,
      amountTokensOut: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<BN>;

    getInputTokensForExactCerUsd(
      poolPos: number | BN | string,
      amountCerUsdOut: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<BN>;

    getOutputExactCerUsdForTokens(
      poolPos: number | BN | string,
      amountCerUsdIn: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<BN>;

    getOutputExactTokensForCerUsd(
      poolPos: number | BN | string,
      amountTokensIn: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<BN>;

    getPoolByPosition(
      pos: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<{
      token: string;
      balanceToken: BN;
      balanceCerUsd: BN;
      lastSqrtKValue: BN;
      hourlyTradeVolumeInCerUsd: BN[];
    }>;

    getPoolByToken(
      token: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<{
      token: string;
      balanceToken: BN;
      balanceCerUsd: BN;
      lastSqrtKValue: BN;
      hourlyTradeVolumeInCerUsd: BN[];
    }>;

    getRoleAdmin(
      role: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;

    getRoleMember(
      role: string,
      index: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;

    getRoleMemberCount(
      role: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<BN>;

    getUtilsContractAtPos(
      pos: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;

    grantRole: {
      (
        role: string,
        account: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        role: string,
        account: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        role: string,
        account: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        role: string,
        account: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    grantRolesBulk: {
      (
        roles: { role: string; addr: string }[],
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        roles: { role: string; addr: string }[],
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        roles: { role: string; addr: string }[],
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        roles: { role: string; addr: string }[],
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    hasRole(
      role: string,
      account: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<boolean>;

    removeNativeLiquidity: {
      (
        amountLpTokensBalanceToBurn: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        amountLpTokensBalanceToBurn: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        amountLpTokensBalanceToBurn: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        amountLpTokensBalanceToBurn: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    removeTokenLiquidity: {
      (
        token: string,
        amountLpTokensBalanceToBurn: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        token: string,
        amountLpTokensBalanceToBurn: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<BN>;
      sendTransaction(
        token: string,
        amountLpTokensBalanceToBurn: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        token: string,
        amountLpTokensBalanceToBurn: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    renounceRole: {
      (
        role: string,
        account: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        role: string,
        account: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        role: string,
        account: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        role: string,
        account: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    revokeRole: {
      (
        role: string,
        account: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        role: string,
        account: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        role: string,
        account: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        role: string,
        account: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    supportsInterface(
      interfaceId: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<boolean>;

    swapExactNativeForTokens: {
      (
        tokenOut: string,
        minAmountTokensOut: number | BN | string,
        expireTimestamp: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        tokenOut: string,
        minAmountTokensOut: number | BN | string,
        expireTimestamp: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<BN>;
      sendTransaction(
        tokenOut: string,
        minAmountTokensOut: number | BN | string,
        expireTimestamp: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        tokenOut: string,
        minAmountTokensOut: number | BN | string,
        expireTimestamp: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    swapExactTokensForNative: {
      (
        tokenIn: string,
        amountTokensIn: number | BN | string,
        minAmountTokensOut: number | BN | string,
        expireTimestamp: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        tokenIn: string,
        amountTokensIn: number | BN | string,
        minAmountTokensOut: number | BN | string,
        expireTimestamp: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<BN>;
      sendTransaction(
        tokenIn: string,
        amountTokensIn: number | BN | string,
        minAmountTokensOut: number | BN | string,
        expireTimestamp: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        tokenIn: string,
        amountTokensIn: number | BN | string,
        minAmountTokensOut: number | BN | string,
        expireTimestamp: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    swapExactTokensForTokens: {
      (
        tokenIn: string,
        tokenOut: string,
        amountTokensIn: number | BN | string,
        minAmountTokensOut: number | BN | string,
        expireTimestamp: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        tokenIn: string,
        tokenOut: string,
        amountTokensIn: number | BN | string,
        minAmountTokensOut: number | BN | string,
        expireTimestamp: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<BN>;
      sendTransaction(
        tokenIn: string,
        tokenOut: string,
        amountTokensIn: number | BN | string,
        minAmountTokensOut: number | BN | string,
        expireTimestamp: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        tokenIn: string,
        tokenOut: string,
        amountTokensIn: number | BN | string,
        minAmountTokensOut: number | BN | string,
        expireTimestamp: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    swapNativeForExactTokens: {
      (
        tokenOut: string,
        amountTokensOut: number | BN | string,
        expireTimestamp: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        tokenOut: string,
        amountTokensOut: number | BN | string,
        expireTimestamp: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<BN>;
      sendTransaction(
        tokenOut: string,
        amountTokensOut: number | BN | string,
        expireTimestamp: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        tokenOut: string,
        amountTokensOut: number | BN | string,
        expireTimestamp: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    swapTokensForExactNative: {
      (
        tokenIn: string,
        maxAmountTokensIn: number | BN | string,
        amountTokensOut: number | BN | string,
        expireTimestamp: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        tokenIn: string,
        maxAmountTokensIn: number | BN | string,
        amountTokensOut: number | BN | string,
        expireTimestamp: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<BN>;
      sendTransaction(
        tokenIn: string,
        maxAmountTokensIn: number | BN | string,
        amountTokensOut: number | BN | string,
        expireTimestamp: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        tokenIn: string,
        maxAmountTokensIn: number | BN | string,
        amountTokensOut: number | BN | string,
        expireTimestamp: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    swapTokensForExactTokens: {
      (
        tokenIn: string,
        tokenOut: string,
        maxAmountTokensIn: number | BN | string,
        amountTokensOut: number | BN | string,
        expireTimestamp: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        tokenIn: string,
        tokenOut: string,
        maxAmountTokensIn: number | BN | string,
        amountTokensOut: number | BN | string,
        expireTimestamp: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<BN>;
      sendTransaction(
        tokenIn: string,
        tokenOut: string,
        maxAmountTokensIn: number | BN | string,
        amountTokensOut: number | BN | string,
        expireTimestamp: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        tokenIn: string,
        tokenOut: string,
        maxAmountTokensIn: number | BN | string,
        amountTokensOut: number | BN | string,
        expireTimestamp: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    syncTokenBalanceInPool: {
      (token: string, txDetails?: Truffle.TransactionDetails): Promise<
        Truffle.TransactionResponse<AllEvents>
      >;
      call(
        token: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        token: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        token: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    testGetBalances(
      txDetails?: Truffle.TransactionDetails
    ): Promise<{ 0: BN; 1: BN; 2: BN }>;

    testGetPools(
      txDetails?: Truffle.TransactionDetails
    ): Promise<{
      0: {
        token: string;
        balanceToken: BN;
        balanceCerUsd: BN;
        lastSqrtKValue: BN;
        hourlyTradeVolumeInCerUsd: BN[];
      };
      1: {
        token: string;
        balanceToken: BN;
        balanceCerUsd: BN;
        lastSqrtKValue: BN;
        hourlyTradeVolumeInCerUsd: BN[];
      };
    }>;

    testGetPrices(
      txDetails?: Truffle.TransactionDetails
    ): Promise<{ 0: BN; 1: BN }>;

    testGetTokenToPoolPosition(
      token: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<BN>;

    testSetupTokens: {
      (
        _lpErc1155V1: string,
        _testCerbyToken: string,
        _cerUsdToken: string,
        _testUsdcToken: string,
        _nativeToken: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        _lpErc1155V1: string,
        _testCerbyToken: string,
        _cerUsdToken: string,
        _testUsdcToken: string,
        _nativeToken: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        _lpErc1155V1: string,
        _testCerbyToken: string,
        _cerUsdToken: string,
        _testUsdcToken: string,
        _nativeToken: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        _lpErc1155V1: string,
        _testCerbyToken: string,
        _cerUsdToken: string,
        _testUsdcToken: string,
        _nativeToken: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    "getCurrentFeeBasedOnTrades(uint256)"(
      poolPos: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<BN>;

    "getCurrentFeeBasedOnTrades(address)"(
      token: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<BN>;
  };

  getPastEvents(event: string): Promise<EventData[]>;
  getPastEvents(
    event: string,
    options: PastEventOptions,
    callback: (error: Error, event: EventData) => void
  ): Promise<EventData[]>;
  getPastEvents(event: string, options: PastEventOptions): Promise<EventData[]>;
  getPastEvents(
    event: string,
    callback: (error: Error, event: EventData) => void
  ): Promise<EventData[]>;
}