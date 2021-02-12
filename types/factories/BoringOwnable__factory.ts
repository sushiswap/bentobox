/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Signer } from "ethers";
import { Provider, TransactionRequest } from "@ethersproject/providers";
import { Contract, ContractFactory, Overrides } from "@ethersproject/contracts";

import type { BoringOwnable } from "../BoringOwnable";

export class BoringOwnable__factory extends ContractFactory {
  constructor(signer?: Signer) {
    super(_abi, _bytecode, signer);
  }

  deploy(overrides?: Overrides): Promise<BoringOwnable> {
    return super.deploy(overrides || {}) as Promise<BoringOwnable>;
  }
  getDeployTransaction(overrides?: Overrides): TransactionRequest {
    return super.getDeployTransaction(overrides || {});
  }
  attach(address: string): BoringOwnable {
    return super.attach(address) as BoringOwnable;
  }
  connect(signer: Signer): BoringOwnable__factory {
    return super.connect(signer) as BoringOwnable__factory;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): BoringOwnable {
    return new Contract(address, _abi, signerOrProvider) as BoringOwnable;
  }
}

const _abi = [
  {
    inputs: [],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "previousOwner",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "newOwner",
        type: "address",
      },
    ],
    name: "OwnershipTransferred",
    type: "event",
  },
  {
    inputs: [],
    name: "claimOwnership",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "owner",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "pendingOwner",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "newOwner",
        type: "address",
      },
      {
        internalType: "bool",
        name: "direct",
        type: "bool",
      },
      {
        internalType: "bool",
        name: "renounce",
        type: "bool",
      },
    ],
    name: "transferOwnership",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
];

const _bytecode =
  "0x608060405234801561001057600080fd5b50600080546001600160a01b0319163390811782556040519091907f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0908290a36104b18061005f6000396000f3fe608060405234801561001057600080fd5b506004361061004c5760003560e01c8063078dfbe7146100515780634e71e0c8146100665780638da5cb5b1461006e578063e30c39781461008c575b600080fd5b61006461005f366004610346565b610094565b005b610064610228565b61007661030e565b60405161008391906103a8565b60405180910390f35b61007661032a565b60005473ffffffffffffffffffffffffffffffffffffffff1633146100ee576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004016100e590610400565b60405180910390fd5b81156101e25773ffffffffffffffffffffffffffffffffffffffff83161515806101155750805b61014b576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004016100e5906103c9565b6000805460405173ffffffffffffffffffffffffffffffffffffffff808716939216917f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e091a36000805473ffffffffffffffffffffffffffffffffffffffff85167fffffffffffffffffffffffff000000000000000000000000000000000000000091821617909155600180549091169055610223565b600180547fffffffffffffffffffffffff00000000000000000000000000000000000000001673ffffffffffffffffffffffffffffffffffffffff85161790555b505050565b60015473ffffffffffffffffffffffffffffffffffffffff1633811461027a576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004016100e590610435565b6000805460405173ffffffffffffffffffffffffffffffffffffffff808516939216917f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e091a36000805473ffffffffffffffffffffffffffffffffffffffff9092167fffffffffffffffffffffffff0000000000000000000000000000000000000000928316179055600180549091169055565b60005473ffffffffffffffffffffffffffffffffffffffff1681565b60015473ffffffffffffffffffffffffffffffffffffffff1681565b60008060006060848603121561035a578283fd5b833573ffffffffffffffffffffffffffffffffffffffff8116811461037d578384fd5b9250602084013561038d8161046a565b9150604084013561039d8161046a565b809150509250925092565b73ffffffffffffffffffffffffffffffffffffffff91909116815260200190565b60208082526015908201527f4f776e61626c653a207a65726f20616464726573730000000000000000000000604082015260600190565b6020808252818101527f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e6572604082015260600190565b6020808252818101527f4f776e61626c653a2063616c6c657220213d2070656e64696e67206f776e6572604082015260600190565b801515811461047857600080fd5b5056fea2646970667358221220e82685db8aa6855ca661c07d6bf2c602b6da254dfa82f3e333b56941b60dfc8e64736f6c634300060c0033";
