/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import BN from "bn.js";
import { EventData, PastEventOptions } from "web3-eth-contract";

export interface CerbySwapV1Contract
  extends Truffle.Contract<CerbySwapV1Instance> {
  "new"(meta?: Truffle.TransactionDetails): Promise<CerbySwapV1Instance>;
}

export interface ApprovalForAll {
  name: "ApprovalForAll";
  args: {
    account: string;
    operator: string;
    approved: boolean;
    0: string;
    1: string;
    2: boolean;
  };
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

export interface TransferBatch {
  name: "TransferBatch";
  args: {
    operator: string;
    from: string;
    to: string;
    ids: BN[];
    values: BN[];
    0: string;
    1: string;
    2: string;
    3: BN[];
    4: BN[];
  };
}

export interface TransferSingle {
  name: "TransferSingle";
  args: {
    operator: string;
    from: string;
    to: string;
    id: BN;
    value: BN;
    0: string;
    1: string;
    2: string;
    3: BN;
    4: BN;
  };
}

export interface URI {
  name: "URI";
  args: {
    value: string;
    id: BN;
    0: string;
    1: BN;
  };
}

type AllEvents =
  | ApprovalForAll
  | RoleAdminChanged
  | RoleGranted
  | RoleRevoked
  | TransferBatch
  | TransferSingle
  | URI;

export interface CerbySwapV1Instance extends Truffle.ContractInstance {
  ROLE_ADMIN(txDetails?: Truffle.TransactionDetails): Promise<string>;

  addTokenLiquidity: {
    (
      token: string,
      amountTokensIn: number | BN | string,
      expireTimestamp: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      token: string,
      amountTokensIn: number | BN | string,
      expireTimestamp: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      token: string,
      amountTokensIn: number | BN | string,
      expireTimestamp: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      token: string,
      amountTokensIn: number | BN | string,
      expireTimestamp: number | BN | string,
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

  adminSetURI: {
    (newUrlPrefix: string, txDetails?: Truffle.TransactionDetails): Promise<
      Truffle.TransactionResponse<AllEvents>
    >;
    call(
      newUrlPrefix: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      newUrlPrefix: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      newUrlPrefix: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
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

  adminUpdateNameAndSymbol: {
    (
      newName: string,
      newSymbol: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      newName: string,
      newSymbol: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      newName: string,
      newSymbol: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      newName: string,
      newSymbol: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  balanceOf(
    account: string,
    id: number | BN | string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<BN>;

  balanceOfBatch(
    accounts: string[],
    ids: (number | BN | string)[],
    txDetails?: Truffle.TransactionDetails
  ): Promise<BN[]>;

  burn: {
    (
      id: number | BN | string,
      amount: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      id: number | BN | string,
      amount: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      id: number | BN | string,
      amount: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      id: number | BN | string,
      amount: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  decimals(txDetails?: Truffle.TransactionDetails): Promise<BN>;

  exists(
    id: number | BN | string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<boolean>;

  feeToBeneficiary(txDetails?: Truffle.TransactionDetails): Promise<string>;

  getCurrentFeeBasedOnTrades(
    token: string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<BN>;

  getInputTokensForExactTokens(
    tokenIn: string,
    tokenOut: string,
    amountTokensOut: number | BN | string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<BN>;

  getOutputExactTokensForTokens(
    tokenIn: string,
    tokenOut: string,
    amountTokensIn: number | BN | string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<BN>;

  getPoolByPosition(
    pos: number | BN | string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<{
    token: string;
    hourlyTradeVolumeInCerUsd: BN[];
    balanceToken: BN;
    balanceCerUsd: BN;
    lastSqrtKValue: BN;
  }>;

  getPoolByToken(
    token: string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<{
    token: string;
    hourlyTradeVolumeInCerUsd: BN[];
    balanceToken: BN;
    balanceCerUsd: BN;
    lastSqrtKValue: BN;
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

  getTokenToPoolPosition(
    token: string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<BN>;

  getTotalCerUsdBalance(txDetails?: Truffle.TransactionDetails): Promise<BN>;

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

  isApprovedForAll(
    account: string,
    operator: string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<boolean>;

  name(txDetails?: Truffle.TransactionDetails): Promise<string>;

  removeTokenLiquidity: {
    (
      token: string,
      amountLpTokensBalanceToBurn: number | BN | string,
      expireTimestamp: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      token: string,
      amountLpTokensBalanceToBurn: number | BN | string,
      expireTimestamp: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<BN>;
    sendTransaction(
      token: string,
      amountLpTokensBalanceToBurn: number | BN | string,
      expireTimestamp: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      token: string,
      amountLpTokensBalanceToBurn: number | BN | string,
      expireTimestamp: number | BN | string,
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

  safeBatchTransferFrom: {
    (
      from: string,
      to: string,
      ids: (number | BN | string)[],
      amounts: (number | BN | string)[],
      data: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      from: string,
      to: string,
      ids: (number | BN | string)[],
      amounts: (number | BN | string)[],
      data: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      from: string,
      to: string,
      ids: (number | BN | string)[],
      amounts: (number | BN | string)[],
      data: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      from: string,
      to: string,
      ids: (number | BN | string)[],
      amounts: (number | BN | string)[],
      data: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  safeTransferFrom: {
    (
      from: string,
      to: string,
      id: number | BN | string,
      amount: number | BN | string,
      data: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      from: string,
      to: string,
      id: number | BN | string,
      amount: number | BN | string,
      data: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      from: string,
      to: string,
      id: number | BN | string,
      amount: number | BN | string,
      data: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      from: string,
      to: string,
      id: number | BN | string,
      amount: number | BN | string,
      data: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  setApprovalForAll: {
    (
      operator: string,
      approved: boolean,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      operator: string,
      approved: boolean,
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      operator: string,
      approved: boolean,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      operator: string,
      approved: boolean,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  supportsInterface(
    interfaceId: string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<boolean>;

  swap: {
    (
      token: string,
      amountTokensOut: number | BN | string,
      amountCerUsdOut: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      token: string,
      amountTokensOut: number | BN | string,
      amountCerUsdOut: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      token: string,
      amountTokensOut: number | BN | string,
      amountCerUsdOut: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      token: string,
      amountTokensOut: number | BN | string,
      amountCerUsdOut: number | BN | string,
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
    ): Promise<{ 0: BN; 1: BN }>;
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

  swapTokensForExactTokens: {
    (
      tokenIn: string,
      tokenOut: string,
      amountTokensOut: number | BN | string,
      maxAmountTokensIn: number | BN | string,
      expireTimestamp: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      tokenIn: string,
      tokenOut: string,
      amountTokensOut: number | BN | string,
      maxAmountTokensIn: number | BN | string,
      expireTimestamp: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<{ 0: BN; 1: BN }>;
    sendTransaction(
      tokenIn: string,
      tokenOut: string,
      amountTokensOut: number | BN | string,
      maxAmountTokensIn: number | BN | string,
      expireTimestamp: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      tokenIn: string,
      tokenOut: string,
      amountTokensOut: number | BN | string,
      maxAmountTokensIn: number | BN | string,
      expireTimestamp: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  symbol(txDetails?: Truffle.TransactionDetails): Promise<string>;

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

  testInit: {
    (txDetails?: Truffle.TransactionDetails): Promise<
      Truffle.TransactionResponse<AllEvents>
    >;
    call(txDetails?: Truffle.TransactionDetails): Promise<void>;
    sendTransaction(txDetails?: Truffle.TransactionDetails): Promise<string>;
    estimateGas(txDetails?: Truffle.TransactionDetails): Promise<number>;
  };

  testSetupTokens: {
    (
      arg0: string,
      _testCerbyToken: string,
      _cerUsdToken: string,
      _testUsdcToken: string,
      arg4: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      arg0: string,
      _testCerbyToken: string,
      _cerUsdToken: string,
      _testUsdcToken: string,
      arg4: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      arg0: string,
      _testCerbyToken: string,
      _cerUsdToken: string,
      _testUsdcToken: string,
      arg4: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      arg0: string,
      _testCerbyToken: string,
      _cerUsdToken: string,
      _testUsdcToken: string,
      arg4: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  uri(
    id: number | BN | string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<string>;

  methods: {
    ROLE_ADMIN(txDetails?: Truffle.TransactionDetails): Promise<string>;

    addTokenLiquidity: {
      (
        token: string,
        amountTokensIn: number | BN | string,
        expireTimestamp: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        token: string,
        amountTokensIn: number | BN | string,
        expireTimestamp: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        token: string,
        amountTokensIn: number | BN | string,
        expireTimestamp: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        token: string,
        amountTokensIn: number | BN | string,
        expireTimestamp: number | BN | string,
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

    adminSetURI: {
      (newUrlPrefix: string, txDetails?: Truffle.TransactionDetails): Promise<
        Truffle.TransactionResponse<AllEvents>
      >;
      call(
        newUrlPrefix: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        newUrlPrefix: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        newUrlPrefix: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
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

    adminUpdateNameAndSymbol: {
      (
        newName: string,
        newSymbol: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        newName: string,
        newSymbol: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        newName: string,
        newSymbol: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        newName: string,
        newSymbol: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    balanceOf(
      account: string,
      id: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<BN>;

    balanceOfBatch(
      accounts: string[],
      ids: (number | BN | string)[],
      txDetails?: Truffle.TransactionDetails
    ): Promise<BN[]>;

    burn: {
      (
        id: number | BN | string,
        amount: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        id: number | BN | string,
        amount: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        id: number | BN | string,
        amount: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        id: number | BN | string,
        amount: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    decimals(txDetails?: Truffle.TransactionDetails): Promise<BN>;

    exists(
      id: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<boolean>;

    feeToBeneficiary(txDetails?: Truffle.TransactionDetails): Promise<string>;

    getCurrentFeeBasedOnTrades(
      token: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<BN>;

    getInputTokensForExactTokens(
      tokenIn: string,
      tokenOut: string,
      amountTokensOut: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<BN>;

    getOutputExactTokensForTokens(
      tokenIn: string,
      tokenOut: string,
      amountTokensIn: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<BN>;

    getPoolByPosition(
      pos: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<{
      token: string;
      hourlyTradeVolumeInCerUsd: BN[];
      balanceToken: BN;
      balanceCerUsd: BN;
      lastSqrtKValue: BN;
    }>;

    getPoolByToken(
      token: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<{
      token: string;
      hourlyTradeVolumeInCerUsd: BN[];
      balanceToken: BN;
      balanceCerUsd: BN;
      lastSqrtKValue: BN;
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

    getTokenToPoolPosition(
      token: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<BN>;

    getTotalCerUsdBalance(txDetails?: Truffle.TransactionDetails): Promise<BN>;

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

    isApprovedForAll(
      account: string,
      operator: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<boolean>;

    name(txDetails?: Truffle.TransactionDetails): Promise<string>;

    removeTokenLiquidity: {
      (
        token: string,
        amountLpTokensBalanceToBurn: number | BN | string,
        expireTimestamp: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        token: string,
        amountLpTokensBalanceToBurn: number | BN | string,
        expireTimestamp: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<BN>;
      sendTransaction(
        token: string,
        amountLpTokensBalanceToBurn: number | BN | string,
        expireTimestamp: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        token: string,
        amountLpTokensBalanceToBurn: number | BN | string,
        expireTimestamp: number | BN | string,
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

    safeBatchTransferFrom: {
      (
        from: string,
        to: string,
        ids: (number | BN | string)[],
        amounts: (number | BN | string)[],
        data: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        from: string,
        to: string,
        ids: (number | BN | string)[],
        amounts: (number | BN | string)[],
        data: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        from: string,
        to: string,
        ids: (number | BN | string)[],
        amounts: (number | BN | string)[],
        data: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        from: string,
        to: string,
        ids: (number | BN | string)[],
        amounts: (number | BN | string)[],
        data: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    safeTransferFrom: {
      (
        from: string,
        to: string,
        id: number | BN | string,
        amount: number | BN | string,
        data: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        from: string,
        to: string,
        id: number | BN | string,
        amount: number | BN | string,
        data: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        from: string,
        to: string,
        id: number | BN | string,
        amount: number | BN | string,
        data: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        from: string,
        to: string,
        id: number | BN | string,
        amount: number | BN | string,
        data: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    setApprovalForAll: {
      (
        operator: string,
        approved: boolean,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        operator: string,
        approved: boolean,
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        operator: string,
        approved: boolean,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        operator: string,
        approved: boolean,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    supportsInterface(
      interfaceId: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<boolean>;

    swap: {
      (
        token: string,
        amountTokensOut: number | BN | string,
        amountCerUsdOut: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        token: string,
        amountTokensOut: number | BN | string,
        amountCerUsdOut: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        token: string,
        amountTokensOut: number | BN | string,
        amountCerUsdOut: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        token: string,
        amountTokensOut: number | BN | string,
        amountCerUsdOut: number | BN | string,
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
      ): Promise<{ 0: BN; 1: BN }>;
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

    swapTokensForExactTokens: {
      (
        tokenIn: string,
        tokenOut: string,
        amountTokensOut: number | BN | string,
        maxAmountTokensIn: number | BN | string,
        expireTimestamp: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        tokenIn: string,
        tokenOut: string,
        amountTokensOut: number | BN | string,
        maxAmountTokensIn: number | BN | string,
        expireTimestamp: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<{ 0: BN; 1: BN }>;
      sendTransaction(
        tokenIn: string,
        tokenOut: string,
        amountTokensOut: number | BN | string,
        maxAmountTokensIn: number | BN | string,
        expireTimestamp: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        tokenIn: string,
        tokenOut: string,
        amountTokensOut: number | BN | string,
        maxAmountTokensIn: number | BN | string,
        expireTimestamp: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    symbol(txDetails?: Truffle.TransactionDetails): Promise<string>;

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

    testInit: {
      (txDetails?: Truffle.TransactionDetails): Promise<
        Truffle.TransactionResponse<AllEvents>
      >;
      call(txDetails?: Truffle.TransactionDetails): Promise<void>;
      sendTransaction(txDetails?: Truffle.TransactionDetails): Promise<string>;
      estimateGas(txDetails?: Truffle.TransactionDetails): Promise<number>;
    };

    testSetupTokens: {
      (
        arg0: string,
        _testCerbyToken: string,
        _cerUsdToken: string,
        _testUsdcToken: string,
        arg4: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        arg0: string,
        _testCerbyToken: string,
        _cerUsdToken: string,
        _testUsdcToken: string,
        arg4: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        arg0: string,
        _testCerbyToken: string,
        _cerUsdToken: string,
        _testUsdcToken: string,
        arg4: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        arg0: string,
        _testCerbyToken: string,
        _cerUsdToken: string,
        _testUsdcToken: string,
        arg4: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    uri(
      id: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;

    "totalSupply()"(txDetails?: Truffle.TransactionDetails): Promise<BN>;

    "totalSupply(uint256)"(
      id: number | BN | string,
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
