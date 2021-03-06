/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import BN from "bn.js";
import { EventData, PastEventOptions } from "web3-eth-contract";

export interface CerbyBotDetectionContract
  extends Truffle.Contract<CerbyBotDetectionInstance> {
  "new"(meta?: Truffle.TransactionDetails): Promise<CerbyBotDetectionInstance>;
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

export interface CerbyBotDetectionInstance extends Truffle.ContractInstance {
  ROLE_ADMIN(txDetails?: Truffle.TransactionDetails): Promise<string>;

  bulkMarkAddressAsBot: {
    (addrs: string[], txDetails?: Truffle.TransactionDetails): Promise<
      Truffle.TransactionResponse<AllEvents>
    >;
    call(
      addrs: string[],
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      addrs: string[],
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      addrs: string[],
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  bulkMarkAddressAsBotBool: {
    (
      addrs: string[],
      value: boolean,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      addrs: string[],
      value: boolean,
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      addrs: string[],
      value: boolean,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      addrs: string[],
      value: boolean,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  bulkMarkAddressAsHuman: {
    (
      addrs: string[],
      value: boolean,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      addrs: string[],
      value: boolean,
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      addrs: string[],
      value: boolean,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      addrs: string[],
      value: boolean,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  bulkMarkAsUniswapPair: {
    (
      addrs: string[],
      value: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      addrs: string[],
      value: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      addrs: string[],
      value: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      addrs: string[],
      value: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  checkTransaction: {
    (
      tokenAddr: string,
      addr: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      tokenAddr: string,
      addr: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<boolean>;
    sendTransaction(
      tokenAddr: string,
      addr: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      tokenAddr: string,
      addr: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  checkTransactionInfo: {
    (
      tokenAddr: string,
      sender: string,
      recipient: string,
      recipientBalance: number | BN | string,
      transferAmount: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      tokenAddr: string,
      sender: string,
      recipient: string,
      recipientBalance: number | BN | string,
      transferAmount: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<{ isBuy: boolean; isSell: boolean }>;
    sendTransaction(
      tokenAddr: string,
      sender: string,
      recipient: string,
      recipientBalance: number | BN | string,
      transferAmount: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      tokenAddr: string,
      sender: string,
      recipient: string,
      recipientBalance: number | BN | string,
      transferAmount: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  cronJobs(
    arg0: number | BN | string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<{ 0: string; 1: string }>;

  executeCronJobs: {
    (txDetails?: Truffle.TransactionDetails): Promise<
      Truffle.TransactionResponse<AllEvents>
    >;
    call(txDetails?: Truffle.TransactionDetails): Promise<void>;
    sendTransaction(txDetails?: Truffle.TransactionDetails): Promise<string>;
    estimateGas(txDetails?: Truffle.TransactionDetails): Promise<number>;
  };

  getCooldownPeriodSell(
    tokenAddr: string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<BN>;

  getCronJobsLength(txDetails?: Truffle.TransactionDetails): Promise<BN>;

  getReceiveTimestamp(
    tokenAddr: string,
    addr: string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<BN>;

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

  isBotAddress(
    addr: string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<boolean>;

  isContract(
    addr: string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<boolean>;

  isMarkedAsBotStorage(
    addr: string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<boolean>;

  isMarkedAsBotStorageBulk(
    addrs: string[],
    txDetails?: Truffle.TransactionDetails
  ): Promise<string[]>;

  isMarkedAsHumanStorage(
    addr: string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<boolean>;

  isMarkedAsHumanStorageBulk(
    addrs: string[],
    txDetails?: Truffle.TransactionDetails
  ): Promise<string[]>;

  isUniswapPair(
    addr: string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<BN>;

  markAddressAsBot: {
    (addr: string, txDetails?: Truffle.TransactionDetails): Promise<
      Truffle.TransactionResponse<AllEvents>
    >;
    call(addr: string, txDetails?: Truffle.TransactionDetails): Promise<void>;
    sendTransaction(
      addr: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      addr: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  markAddressAsHuman: {
    (
      addr: string,
      value: boolean,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      addr: string,
      value: boolean,
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      addr: string,
      value: boolean,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      addr: string,
      value: boolean,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  markAddressAsNotBot: {
    (addr: string, txDetails?: Truffle.TransactionDetails): Promise<
      Truffle.TransactionResponse<AllEvents>
    >;
    call(addr: string, txDetails?: Truffle.TransactionDetails): Promise<void>;
    sendTransaction(
      addr: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      addr: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  markAsUniswapPair: {
    (
      addr: string,
      value: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      addr: string,
      value: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      addr: string,
      value: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      addr: string,
      value: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  registerJob: {
    (
      targetContract: string,
      abiCall: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      targetContract: string,
      abiCall: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      targetContract: string,
      abiCall: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      targetContract: string,
      abiCall: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  registerTransaction: {
    (
      tokenAddr: string,
      addr: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      tokenAddr: string,
      addr: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      tokenAddr: string,
      addr: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      tokenAddr: string,
      addr: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  removeJobs: {
    (targetContract: string, txDetails?: Truffle.TransactionDetails): Promise<
      Truffle.TransactionResponse<AllEvents>
    >;
    call(
      targetContract: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      targetContract: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      targetContract: string,
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

  updateCooldownPeriodSell: {
    (
      tokenAddr: string,
      newCooldownSellPeriod: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      tokenAddr: string,
      newCooldownSellPeriod: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      tokenAddr: string,
      newCooldownSellPeriod: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      tokenAddr: string,
      newCooldownSellPeriod: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  methods: {
    ROLE_ADMIN(txDetails?: Truffle.TransactionDetails): Promise<string>;

    bulkMarkAddressAsBot: {
      (addrs: string[], txDetails?: Truffle.TransactionDetails): Promise<
        Truffle.TransactionResponse<AllEvents>
      >;
      call(
        addrs: string[],
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        addrs: string[],
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        addrs: string[],
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    bulkMarkAddressAsBotBool: {
      (
        addrs: string[],
        value: boolean,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        addrs: string[],
        value: boolean,
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        addrs: string[],
        value: boolean,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        addrs: string[],
        value: boolean,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    bulkMarkAddressAsHuman: {
      (
        addrs: string[],
        value: boolean,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        addrs: string[],
        value: boolean,
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        addrs: string[],
        value: boolean,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        addrs: string[],
        value: boolean,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    bulkMarkAsUniswapPair: {
      (
        addrs: string[],
        value: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        addrs: string[],
        value: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        addrs: string[],
        value: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        addrs: string[],
        value: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    checkTransaction: {
      (
        tokenAddr: string,
        addr: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        tokenAddr: string,
        addr: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<boolean>;
      sendTransaction(
        tokenAddr: string,
        addr: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        tokenAddr: string,
        addr: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    checkTransactionInfo: {
      (
        tokenAddr: string,
        sender: string,
        recipient: string,
        recipientBalance: number | BN | string,
        transferAmount: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        tokenAddr: string,
        sender: string,
        recipient: string,
        recipientBalance: number | BN | string,
        transferAmount: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<{ isBuy: boolean; isSell: boolean }>;
      sendTransaction(
        tokenAddr: string,
        sender: string,
        recipient: string,
        recipientBalance: number | BN | string,
        transferAmount: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        tokenAddr: string,
        sender: string,
        recipient: string,
        recipientBalance: number | BN | string,
        transferAmount: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    cronJobs(
      arg0: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<{ 0: string; 1: string }>;

    executeCronJobs: {
      (txDetails?: Truffle.TransactionDetails): Promise<
        Truffle.TransactionResponse<AllEvents>
      >;
      call(txDetails?: Truffle.TransactionDetails): Promise<void>;
      sendTransaction(txDetails?: Truffle.TransactionDetails): Promise<string>;
      estimateGas(txDetails?: Truffle.TransactionDetails): Promise<number>;
    };

    getCooldownPeriodSell(
      tokenAddr: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<BN>;

    getCronJobsLength(txDetails?: Truffle.TransactionDetails): Promise<BN>;

    getReceiveTimestamp(
      tokenAddr: string,
      addr: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<BN>;

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

    isBotAddress(
      addr: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<boolean>;

    isContract(
      addr: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<boolean>;

    isMarkedAsBotStorage(
      addr: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<boolean>;

    isMarkedAsBotStorageBulk(
      addrs: string[],
      txDetails?: Truffle.TransactionDetails
    ): Promise<string[]>;

    isMarkedAsHumanStorage(
      addr: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<boolean>;

    isMarkedAsHumanStorageBulk(
      addrs: string[],
      txDetails?: Truffle.TransactionDetails
    ): Promise<string[]>;

    isUniswapPair(
      addr: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<BN>;

    markAddressAsBot: {
      (addr: string, txDetails?: Truffle.TransactionDetails): Promise<
        Truffle.TransactionResponse<AllEvents>
      >;
      call(addr: string, txDetails?: Truffle.TransactionDetails): Promise<void>;
      sendTransaction(
        addr: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        addr: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    markAddressAsHuman: {
      (
        addr: string,
        value: boolean,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        addr: string,
        value: boolean,
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        addr: string,
        value: boolean,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        addr: string,
        value: boolean,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    markAddressAsNotBot: {
      (addr: string, txDetails?: Truffle.TransactionDetails): Promise<
        Truffle.TransactionResponse<AllEvents>
      >;
      call(addr: string, txDetails?: Truffle.TransactionDetails): Promise<void>;
      sendTransaction(
        addr: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        addr: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    markAsUniswapPair: {
      (
        addr: string,
        value: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        addr: string,
        value: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        addr: string,
        value: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        addr: string,
        value: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    registerJob: {
      (
        targetContract: string,
        abiCall: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        targetContract: string,
        abiCall: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        targetContract: string,
        abiCall: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        targetContract: string,
        abiCall: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    registerTransaction: {
      (
        tokenAddr: string,
        addr: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        tokenAddr: string,
        addr: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        tokenAddr: string,
        addr: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        tokenAddr: string,
        addr: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    removeJobs: {
      (targetContract: string, txDetails?: Truffle.TransactionDetails): Promise<
        Truffle.TransactionResponse<AllEvents>
      >;
      call(
        targetContract: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        targetContract: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        targetContract: string,
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

    updateCooldownPeriodSell: {
      (
        tokenAddr: string,
        newCooldownSellPeriod: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        tokenAddr: string,
        newCooldownSellPeriod: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        tokenAddr: string,
        newCooldownSellPeriod: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        tokenAddr: string,
        newCooldownSellPeriod: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };
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
