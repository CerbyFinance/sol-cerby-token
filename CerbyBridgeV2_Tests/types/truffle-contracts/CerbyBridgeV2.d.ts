/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import BN from "bn.js";
import { EventData, PastEventOptions } from "web3-eth-contract";

export interface CerbyBridgeV2Contract
  extends Truffle.Contract<CerbyBridgeV2Instance> {
  "new"(meta?: Truffle.TransactionDetails): Promise<CerbyBridgeV2Instance>;
}

export interface ApprovedBurnProofHash {
  name: "ApprovedBurnProofHash";
  args: {
    burnProofHash: string;
    0: string;
  };
}

export interface ProofOfBurnOrMint {
  name: "ProofOfBurnOrMint";
  args: {
    isBurn: boolean;
    proof: {
      burnProofHash: string;
      burnGenericCaller: string;
      burnNonce: BN;
      mintGenericCaller: string;
      mintAmount: BN;
      allowance: {
        burnGenericToken: string;
        burnChainType: BN;
        burnChainId: BN;
        mintGenericToken: string;
        mintChainType: BN;
        mintChainId: BN;
      };
    };
    0: boolean;
    1: {
      burnProofHash: string;
      burnGenericCaller: string;
      burnNonce: BN;
      mintGenericCaller: string;
      mintAmount: BN;
      allowance: {
        burnGenericToken: string;
        burnChainType: BN;
        burnChainId: BN;
        mintGenericToken: string;
        mintChainType: BN;
        mintChainId: BN;
      };
    };
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

type AllEvents =
  | ApprovedBurnProofHash
  | ProofOfBurnOrMint
  | RoleAdminChanged
  | RoleGranted
  | RoleRevoked;

export interface CerbyBridgeV2Instance extends Truffle.ContractInstance {
  ROLE_ADMIN(txDetails?: Truffle.TransactionDetails): Promise<string>;

  ROLE_APPROVER(txDetails?: Truffle.TransactionDetails): Promise<string>;

  allowances(arg0: string, txDetails?: Truffle.TransactionDetails): Promise<BN>;

  approveBurnProof: {
    (proofHash: string, txDetails?: Truffle.TransactionDetails): Promise<
      Truffle.TransactionResponse<AllEvents>
    >;
    call(
      proofHash: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      proofHash: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      proofHash: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  burnAndCreateProof: {
    (
      burnAmount: number | BN | string,
      burnToken: string,
      mintGenericToken: string,
      mintGenericCaller: string,
      mintChainType: number | BN | string,
      mintChainId: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      burnAmount: number | BN | string,
      burnToken: string,
      mintGenericToken: string,
      mintGenericCaller: string,
      mintChainType: number | BN | string,
      mintChainId: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      burnAmount: number | BN | string,
      burnToken: string,
      mintGenericToken: string,
      mintGenericCaller: string,
      mintChainType: number | BN | string,
      mintChainId: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      burnAmount: number | BN | string,
      burnToken: string,
      mintGenericToken: string,
      mintGenericCaller: string,
      mintChainType: number | BN | string,
      mintChainId: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  burnNonceByToken(
    arg0: string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<BN>;

  burnProofStorage(
    arg0: string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<BN>;

  chainToFee(arg0: string, txDetails?: Truffle.TransactionDetails): Promise<BN>;

  computeBurnHash(
    proof: {
      burnProofHash: string;
      burnGenericCaller: string;
      burnNonce: number | BN | string;
      mintGenericCaller: string;
      mintAmount: number | BN | string;
      allowance: {
        burnGenericToken: string;
        burnChainType: number | BN | string;
        burnChainId: number | BN | string;
        mintGenericToken: string;
        mintChainType: number | BN | string;
        mintChainId: number | BN | string;
      };
    },
    txDetails?: Truffle.TransactionDetails
  ): Promise<string>;

  getAllowanceHash(
    _allowance: {
      burnGenericToken: string;
      burnChainType: number | BN | string;
      burnChainId: number | BN | string;
      mintGenericToken: string;
      mintChainType: number | BN | string;
      mintChainId: number | BN | string;
    },
    txDetails?: Truffle.TransactionDetails
  ): Promise<string>;

  getChainHash(
    chainType: number | BN | string,
    chainId: number | BN | string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<string>;

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

  mintWithBurnProof: {
    (
      burnGenericToken: string,
      burnGenericCaller: string,
      burnChainType: number | BN | string,
      burnChainId: number | BN | string,
      burnProofHash: string,
      burnNonce: number | BN | string,
      mintToken: string,
      mintAmount: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      burnGenericToken: string,
      burnGenericCaller: string,
      burnChainType: number | BN | string,
      burnChainId: number | BN | string,
      burnProofHash: string,
      burnNonce: number | BN | string,
      mintToken: string,
      mintAmount: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      burnGenericToken: string,
      burnGenericCaller: string,
      burnChainType: number | BN | string,
      burnChainId: number | BN | string,
      burnProofHash: string,
      burnNonce: number | BN | string,
      mintToken: string,
      mintAmount: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      burnGenericToken: string,
      burnGenericCaller: string,
      burnChainType: number | BN | string,
      burnChainId: number | BN | string,
      burnProofHash: string,
      burnNonce: number | BN | string,
      mintToken: string,
      mintAmount: number | BN | string,
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

  setAllowancesBulk: {
    (
      _allowances: {
        burnGenericToken: string;
        burnChainType: number | BN | string;
        burnChainId: number | BN | string;
        mintGenericToken: string;
        mintChainType: number | BN | string;
        mintChainId: number | BN | string;
      }[],
      _status: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      _allowances: {
        burnGenericToken: string;
        burnChainType: number | BN | string;
        burnChainId: number | BN | string;
        mintGenericToken: string;
        mintChainType: number | BN | string;
        mintChainId: number | BN | string;
      }[],
      _status: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      _allowances: {
        burnGenericToken: string;
        burnChainType: number | BN | string;
        burnChainId: number | BN | string;
        mintGenericToken: string;
        mintChainType: number | BN | string;
        mintChainId: number | BN | string;
      }[],
      _status: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      _allowances: {
        burnGenericToken: string;
        burnChainType: number | BN | string;
        burnChainId: number | BN | string;
        mintGenericToken: string;
        mintChainType: number | BN | string;
        mintChainId: number | BN | string;
      }[],
      _status: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  setChainsToFee: {
    (
      chainsHashes: string[],
      fee: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      chainsHashes: string[],
      fee: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      chainsHashes: string[],
      fee: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      chainsHashes: string[],
      fee: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  supportsInterface(
    interfaceId: string,
    txDetails?: Truffle.TransactionDetails
  ): Promise<boolean>;

  testSetAllowancesBulk: {
    (
      _allowances: {
        burnGenericToken: string;
        burnChainType: number | BN | string;
        burnChainId: number | BN | string;
        mintGenericToken: string;
        mintChainType: number | BN | string;
        mintChainId: number | BN | string;
      }[],
      _status: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<Truffle.TransactionResponse<AllEvents>>;
    call(
      _allowances: {
        burnGenericToken: string;
        burnChainType: number | BN | string;
        burnChainId: number | BN | string;
        mintGenericToken: string;
        mintChainType: number | BN | string;
        mintChainId: number | BN | string;
      }[],
      _status: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<void>;
    sendTransaction(
      _allowances: {
        burnGenericToken: string;
        burnChainType: number | BN | string;
        burnChainId: number | BN | string;
        mintGenericToken: string;
        mintChainType: number | BN | string;
        mintChainId: number | BN | string;
      }[],
      _status: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;
    estimateGas(
      _allowances: {
        burnGenericToken: string;
        burnChainType: number | BN | string;
        burnChainId: number | BN | string;
        mintGenericToken: string;
        mintChainType: number | BN | string;
        mintChainId: number | BN | string;
      }[],
      _status: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<number>;
  };

  methods: {
    ROLE_ADMIN(txDetails?: Truffle.TransactionDetails): Promise<string>;

    ROLE_APPROVER(txDetails?: Truffle.TransactionDetails): Promise<string>;

    allowances(
      arg0: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<BN>;

    approveBurnProof: {
      (proofHash: string, txDetails?: Truffle.TransactionDetails): Promise<
        Truffle.TransactionResponse<AllEvents>
      >;
      call(
        proofHash: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        proofHash: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        proofHash: string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    burnAndCreateProof: {
      (
        burnAmount: number | BN | string,
        burnToken: string,
        mintGenericToken: string,
        mintGenericCaller: string,
        mintChainType: number | BN | string,
        mintChainId: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        burnAmount: number | BN | string,
        burnToken: string,
        mintGenericToken: string,
        mintGenericCaller: string,
        mintChainType: number | BN | string,
        mintChainId: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        burnAmount: number | BN | string,
        burnToken: string,
        mintGenericToken: string,
        mintGenericCaller: string,
        mintChainType: number | BN | string,
        mintChainId: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        burnAmount: number | BN | string,
        burnToken: string,
        mintGenericToken: string,
        mintGenericCaller: string,
        mintChainType: number | BN | string,
        mintChainId: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    burnNonceByToken(
      arg0: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<BN>;

    burnProofStorage(
      arg0: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<BN>;

    chainToFee(
      arg0: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<BN>;

    computeBurnHash(
      proof: {
        burnProofHash: string;
        burnGenericCaller: string;
        burnNonce: number | BN | string;
        mintGenericCaller: string;
        mintAmount: number | BN | string;
        allowance: {
          burnGenericToken: string;
          burnChainType: number | BN | string;
          burnChainId: number | BN | string;
          mintGenericToken: string;
          mintChainType: number | BN | string;
          mintChainId: number | BN | string;
        };
      },
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;

    getAllowanceHash(
      _allowance: {
        burnGenericToken: string;
        burnChainType: number | BN | string;
        burnChainId: number | BN | string;
        mintGenericToken: string;
        mintChainType: number | BN | string;
        mintChainId: number | BN | string;
      },
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;

    getChainHash(
      chainType: number | BN | string,
      chainId: number | BN | string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<string>;

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

    mintWithBurnProof: {
      (
        burnGenericToken: string,
        burnGenericCaller: string,
        burnChainType: number | BN | string,
        burnChainId: number | BN | string,
        burnProofHash: string,
        burnNonce: number | BN | string,
        mintToken: string,
        mintAmount: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        burnGenericToken: string,
        burnGenericCaller: string,
        burnChainType: number | BN | string,
        burnChainId: number | BN | string,
        burnProofHash: string,
        burnNonce: number | BN | string,
        mintToken: string,
        mintAmount: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        burnGenericToken: string,
        burnGenericCaller: string,
        burnChainType: number | BN | string,
        burnChainId: number | BN | string,
        burnProofHash: string,
        burnNonce: number | BN | string,
        mintToken: string,
        mintAmount: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        burnGenericToken: string,
        burnGenericCaller: string,
        burnChainType: number | BN | string,
        burnChainId: number | BN | string,
        burnProofHash: string,
        burnNonce: number | BN | string,
        mintToken: string,
        mintAmount: number | BN | string,
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

    setAllowancesBulk: {
      (
        _allowances: {
          burnGenericToken: string;
          burnChainType: number | BN | string;
          burnChainId: number | BN | string;
          mintGenericToken: string;
          mintChainType: number | BN | string;
          mintChainId: number | BN | string;
        }[],
        _status: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        _allowances: {
          burnGenericToken: string;
          burnChainType: number | BN | string;
          burnChainId: number | BN | string;
          mintGenericToken: string;
          mintChainType: number | BN | string;
          mintChainId: number | BN | string;
        }[],
        _status: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        _allowances: {
          burnGenericToken: string;
          burnChainType: number | BN | string;
          burnChainId: number | BN | string;
          mintGenericToken: string;
          mintChainType: number | BN | string;
          mintChainId: number | BN | string;
        }[],
        _status: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        _allowances: {
          burnGenericToken: string;
          burnChainType: number | BN | string;
          burnChainId: number | BN | string;
          mintGenericToken: string;
          mintChainType: number | BN | string;
          mintChainId: number | BN | string;
        }[],
        _status: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    setChainsToFee: {
      (
        chainsHashes: string[],
        fee: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        chainsHashes: string[],
        fee: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        chainsHashes: string[],
        fee: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        chainsHashes: string[],
        fee: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<number>;
    };

    supportsInterface(
      interfaceId: string,
      txDetails?: Truffle.TransactionDetails
    ): Promise<boolean>;

    testSetAllowancesBulk: {
      (
        _allowances: {
          burnGenericToken: string;
          burnChainType: number | BN | string;
          burnChainId: number | BN | string;
          mintGenericToken: string;
          mintChainType: number | BN | string;
          mintChainId: number | BN | string;
        }[],
        _status: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<Truffle.TransactionResponse<AllEvents>>;
      call(
        _allowances: {
          burnGenericToken: string;
          burnChainType: number | BN | string;
          burnChainId: number | BN | string;
          mintGenericToken: string;
          mintChainType: number | BN | string;
          mintChainId: number | BN | string;
        }[],
        _status: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<void>;
      sendTransaction(
        _allowances: {
          burnGenericToken: string;
          burnChainType: number | BN | string;
          burnChainId: number | BN | string;
          mintGenericToken: string;
          mintChainType: number | BN | string;
          mintChainId: number | BN | string;
        }[],
        _status: number | BN | string,
        txDetails?: Truffle.TransactionDetails
      ): Promise<string>;
      estimateGas(
        _allowances: {
          burnGenericToken: string;
          burnChainType: number | BN | string;
          burnChainId: number | BN | string;
          mintGenericToken: string;
          mintChainType: number | BN | string;
          mintChainId: number | BN | string;
        }[],
        _status: number | BN | string,
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