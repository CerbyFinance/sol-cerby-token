/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import BN from "bn.js";
import { EventData, PastEventOptions } from "web3-eth-contract";

export interface CerbySwapV1AdminFunctionsContract
  extends Truffle.Contract<CerbySwapV1AdminFunctionsInstance> {
  "new"(
    meta?: Truffle.TransactionDetails
  ): Promise<CerbySwapV1AdminFunctionsInstance>;
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

export interface LiquidityAdded {
  name: "LiquidityAdded";
  args: {
    token: string;
    amountTokensIn: BN;
    amountCerUsdToMint: BN;
    lpAmount: BN;
    0: string;
    1: BN;
    2: BN;
    3: BN;
  };
}

export interface LiquidityRemoved {
  name: "LiquidityRemoved";
  args: {
    token: string;
    amountTokensOut: BN;
    amountCerUsdToBurn: BN;
    amountLpTokensBalanceToBurn: BN;
    0: string;
    1: BN;
    2: BN;
    3: BN;
  };
}

export interface OwnershipTransferred {
  name: "OwnershipTransferred";
  args: {
    previousOwner: string;
    newOwner: string;
    0: string;
    1: string;
  };
}

export interface PairCreated {
  name: "PairCreated";
  args: {
    token: string;
    poolId: BN;
    0: string;
    1: BN;
  };
}

export interface Swap {
  name: "Swap";
  args: {
    token: string;
    sender: string;
    amountTokensIn: BN;
    amountCerUsdIn: BN;
    amountTokensOut: BN;
    amountCerUsdOut: BN;
    currentFee: BN;
    transferTo: string;
    0: string;
    1: string;
    2: BN;
    3: BN;
    4: BN;
    5: BN;
    6: BN;
    7: string;
  };
}

export interface Sync {
  name: "Sync";
  args: {
    token: string;
    newBalanceToken: BN;
    newBalanceCerUsd: BN;
    newCreditCerUsd: BN;
    0: string;
    1: BN;
    2: BN;
    3: BN;
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
  | LiquidityAdded
  | LiquidityRemoved
  | OwnershipTransferred
  | PairCreated
  | Swap
  | Sync
  | TransferBatch
  | TransferSingle
  | URI;

export interface CerbySwapV1AdminFunctionsInstance
  extends Truffle.ContractInstance {
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
    ): Promise<BN>;
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

  adminChangeCerUsdCreditInPool: {
    (
      token: string,
      amountCerUsdCredit: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      token: string,
      amountCerUsdCredit: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      token: string,
      amountCerUsdCredit: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      token: string,
      amountCerUsdCredit: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  adminCreatePool: {
    (
      token: string,
      amountTokensIn: number | BN | string,
      amountCerUsdToMint: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      token: string,
      amountTokensIn: number | BN | string,
      amountCerUsdToMint: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      token: string,
      amountTokensIn: number | BN | string,
      amountCerUsdToMint: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      token: string,
      amountTokensIn: number | BN | string,
      amountCerUsdToMint: number | BN | string,
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

  adminUpdateFeesAndTvlMultipliers: {
    (
      _settings: {
        mintFeeBeneficiary: string;
        mintFeeMultiplier: number | BN | string;
        feeMinimum: number | BN | string;
        feeMaximum: number | BN | string;
        tvlMultiplierMinimum: number | BN | string;
        tvlMultiplierMaximum: number | BN | string;
      },
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      _settings: {
        mintFeeBeneficiary: string;
        mintFeeMultiplier: number | BN | string;
        feeMinimum: number | BN | string;
        feeMaximum: number | BN | string;
        tvlMultiplierMinimum: number | BN | string;
        tvlMultiplierMaximum: number | BN | string;
      },
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      _settings: {
        mintFeeBeneficiary: string;
        mintFeeMultiplier: number | BN | string;
        feeMinimum: number | BN | string;
        feeMaximum: number | BN | string;
        tvlMultiplierMinimum: number | BN | string;
        tvlMultiplierMaximum: number | BN | string;
      },
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      _settings: {
        mintFeeBeneficiary: string;
        mintFeeMultiplier: number | BN | string;
        feeMinimum: number | BN | string;
        feeMaximum: number | BN | string;
        tvlMultiplierMinimum: number | BN | string;
        tvlMultiplierMaximum: number | BN | string;
      },
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

  createPool: {
    (
      token: string,
      amountTokensIn: number | BN | string,
      amountCerUsdToMint: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      token: string,
      amountTokensIn: number | BN | string,
      amountCerUsdToMint: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      token: string,
      amountTokensIn: number | BN | string,
      amountCerUsdToMint: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      token: string,
      amountTokensIn: number | BN | string,
      amountCerUsdToMint: number | BN | string,
      transferTo: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  decimals(txDetails?: Truffle.TransactionDetails): Promise<BN>;

  exists(
    id: number | BN | string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<boolean>;

  getUtilsContractAtPos(
    pos: number | BN | string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<string>;

  increaseCerUsdCreditInPool: {
    (
      token: string,
      amountCerUsdCredit: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      token: string,
      amountCerUsdCredit: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      token: string,
      amountCerUsdCredit: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      token: string,
      amountCerUsdCredit: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  isApprovedForAll(
    account: string,
    operator: string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<boolean>;

  name(txDetails?: Truffle.TransactionDetails): Promise<string>;

  owner(txDetails?: Truffle.TransactionDetails): Promise<string>;

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

  renounceOwnership: {
    (txDetails?: Truffle.TransactionDetails): Promise<
      Truffle.TransactionResponse<AllEvents>
    >;
    call(txDetails?: Truffle.TransactionDetails): Promise<void>;
    sendTransaction(txDetails?: Truffle.TransactionDetails): Promise<string>;
    estimateGas(txDetails?: Truffle.TransactionDetails): Promise<number>;
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

  skimPool: {
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

  supportsInterface(
    interfaceId: string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<boolean>;

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

  transferOwnership: {
    (newOwner: string, txDetails?: Truffle.TransactionDetails): Promise<
      Truffle.TransactionResponse<AllEvents>
    >;
    call(
      newOwner: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      newOwner: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      newOwner: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  uri(
    id: number | BN | string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<string>;

  methods: {
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
      ): Promise<BN>;
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

    adminChangeCerUsdCreditInPool: {
      (
        token: string,
        amountCerUsdCredit: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        token: string,
        amountCerUsdCredit: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        token: string,
        amountCerUsdCredit: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        token: string,
        amountCerUsdCredit: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    adminCreatePool: {
      (
        token: string,
        amountTokensIn: number | BN | string,
        amountCerUsdToMint: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        token: string,
        amountTokensIn: number | BN | string,
        amountCerUsdToMint: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        token: string,
        amountTokensIn: number | BN | string,
        amountCerUsdToMint: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        token: string,
        amountTokensIn: number | BN | string,
        amountCerUsdToMint: number | BN | string,
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

    adminUpdateFeesAndTvlMultipliers: {
      (
        _settings: {
          mintFeeBeneficiary: string;
          mintFeeMultiplier: number | BN | string;
          feeMinimum: number | BN | string;
          feeMaximum: number | BN | string;
          tvlMultiplierMinimum: number | BN | string;
          tvlMultiplierMaximum: number | BN | string;
        },
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        _settings: {
          mintFeeBeneficiary: string;
          mintFeeMultiplier: number | BN | string;
          feeMinimum: number | BN | string;
          feeMaximum: number | BN | string;
          tvlMultiplierMinimum: number | BN | string;
          tvlMultiplierMaximum: number | BN | string;
        },
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        _settings: {
          mintFeeBeneficiary: string;
          mintFeeMultiplier: number | BN | string;
          feeMinimum: number | BN | string;
          feeMaximum: number | BN | string;
          tvlMultiplierMinimum: number | BN | string;
          tvlMultiplierMaximum: number | BN | string;
        },
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        _settings: {
          mintFeeBeneficiary: string;
          mintFeeMultiplier: number | BN | string;
          feeMinimum: number | BN | string;
          feeMaximum: number | BN | string;
          tvlMultiplierMinimum: number | BN | string;
          tvlMultiplierMaximum: number | BN | string;
        },
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

    createPool: {
      (
        token: string,
        amountTokensIn: number | BN | string,
        amountCerUsdToMint: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        token: string,
        amountTokensIn: number | BN | string,
        amountCerUsdToMint: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        token: string,
        amountTokensIn: number | BN | string,
        amountCerUsdToMint: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        token: string,
        amountTokensIn: number | BN | string,
        amountCerUsdToMint: number | BN | string,
        transferTo: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    decimals(txDetails?: Truffle.TransactionDetails): Promise<BN>;

    exists(
      id: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<boolean>;

    getUtilsContractAtPos(
      pos: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;

    increaseCerUsdCreditInPool: {
      (
        token: string,
        amountCerUsdCredit: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        token: string,
        amountCerUsdCredit: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        token: string,
        amountCerUsdCredit: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        token: string,
        amountCerUsdCredit: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    isApprovedForAll(
      account: string,
      operator: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<boolean>;

    name(txDetails?: Truffle.TransactionDetails): Promise<string>;

    owner(txDetails?: Truffle.TransactionDetails): Promise<string>;

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

    renounceOwnership: {
      (txDetails?: Truffle.TransactionDetails): Promise<
        Truffle.TransactionResponse<AllEvents>
      >;
      call(txDetails?: Truffle.TransactionDetails): Promise<void>;
      sendTransaction(txDetails?: Truffle.TransactionDetails): Promise<string>;
      estimateGas(txDetails?: Truffle.TransactionDetails): Promise<number>;
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

    skimPool: {
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

    supportsInterface(
      interfaceId: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<boolean>;

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

    transferOwnership: {
      (newOwner: string, txDetails?: Truffle.TransactionDetails): Promise<
        Truffle.TransactionResponse<AllEvents>
      >;
      call(
        newOwner: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        newOwner: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        newOwner: string,
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
