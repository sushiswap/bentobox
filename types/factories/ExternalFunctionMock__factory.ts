/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Signer } from "ethers";
import { Provider, TransactionRequest } from "@ethersproject/providers";
import { Contract, ContractFactory, Overrides } from "@ethersproject/contracts";

import type { ExternalFunctionMock } from "../ExternalFunctionMock";

export class ExternalFunctionMock__factory extends ContractFactory {
  constructor(signer?: Signer) {
    super(_abi, _bytecode, signer);
  }

  deploy(overrides?: Overrides): Promise<ExternalFunctionMock> {
    return super.deploy(overrides || {}) as Promise<ExternalFunctionMock>;
  }
  getDeployTransaction(overrides?: Overrides): TransactionRequest {
    return super.getDeployTransaction(overrides || {});
  }
  attach(address: string): ExternalFunctionMock {
    return super.attach(address) as ExternalFunctionMock;
  }
  connect(signer: Signer): ExternalFunctionMock__factory {
    return super.connect(signer) as ExternalFunctionMock__factory;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): ExternalFunctionMock {
    return new Contract(
      address,
      _abi,
      signerOrProvider
    ) as ExternalFunctionMock;
  }
}

const _abi = [
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "output",
        type: "uint256",
      },
    ],
    name: "Result",
    type: "event",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "a",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "b",
        type: "uint256",
      },
    ],
    name: "sum",
    outputs: [
      {
        internalType: "uint256",
        name: "c",
        type: "uint256",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
];

const _bytecode =
  "0x608060405234801561001057600080fd5b5061015c806100206000396000f3fe608060405234801561001057600080fd5b506004361061002b5760003560e01c8063cad0899b14610030575b600080fd5b6100536004803603604081101561004657600080fd5b5080359060200135610065565b60408051918252519081900360200190f35b600061007183836100ae565b6040805182815290519192507fa9bb0fa194e939eadb11be8d62dd4a16e0f5e89f37fb73fa7f0f8446f1abba61919081900360200190a192915050565b8181018181101561012057604080517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601860248201527f426f72696e674d6174683a20416464204f766572666c6f770000000000000000604482015290519081900360640190fd5b9291505056fea2646970667358221220e3c7b85d2c9477c573ff8e60d358c20ff5d236274262b73a92075a08402f329064736f6c634300060c0033";
