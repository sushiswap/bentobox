/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Signer } from "ethers";
import { Provider, TransactionRequest } from "@ethersproject/providers";
import { Contract, ContractFactory, Overrides } from "@ethersproject/contracts";

import type { HelloWorld } from "../HelloWorld";

export class HelloWorld__factory extends ContractFactory {
  constructor(signer?: Signer) {
    super(_abi, _bytecode, signer);
  }

  deploy(
    _bentoBox: string,
    _token: string,
    overrides?: Overrides
  ): Promise<HelloWorld> {
    return super.deploy(
      _bentoBox,
      _token,
      overrides || {}
    ) as Promise<HelloWorld>;
  }
  getDeployTransaction(
    _bentoBox: string,
    _token: string,
    overrides?: Overrides
  ): TransactionRequest {
    return super.getDeployTransaction(_bentoBox, _token, overrides || {});
  }
  attach(address: string): HelloWorld {
    return super.attach(address) as HelloWorld;
  }
  connect(signer: Signer): HelloWorld__factory {
    return super.connect(signer) as HelloWorld__factory;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): HelloWorld {
    return new Contract(address, _abi, signerOrProvider) as HelloWorld;
  }
}

const _abi = [
  {
    inputs: [
      {
        internalType: "contract BentoBox",
        name: "_bentoBox",
        type: "address",
      },
      {
        internalType: "contract IERC20",
        name: "_token",
        type: "address",
      },
    ],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    inputs: [],
    name: "balance",
    outputs: [
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "bentoBox",
    outputs: [
      {
        internalType: "contract BentoBox",
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
        name: "",
        type: "address",
      },
    ],
    name: "bentoBoxShares",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "deposit",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "token",
    outputs: [
      {
        internalType: "contract IERC20",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "withdraw",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
];

const _bytecode =
  "0x608060405234801561001057600080fd5b5060405161041b38038061041b8339818101604052604081101561003357600080fd5b508051602090910151600080546001600160a01b038085166001600160a01b031992831617808455600180548387169416939093179092556040805163577268d960e11b81529051929091169263aee4d1b29260048084019382900301818387803b1580156100a157600080fd5b505af11580156100b5573d6000803e3d6000fd5b505050505050610351806100ca6000396000f3fe608060405234801561001057600080fd5b50600436106100625760003560e01c80633ccfd60b146100675780636b2ace8714610071578063b69ef8a814610095578063b6b55f25146100af578063faff58fd146100cc578063fc0c546a146100f2575b600080fd5b61006f6100fa565b005b6100796101a2565b604080516001600160a01b039092168252519081900360200190f35b61009d6101b1565b60408051918252519081900360200190f35b61006f600480360360208110156100c557600080fd5b503561024c565b61009d600480360360208110156100e257600080fd5b50356001600160a01b03166102fa565b61007961030c565b60008054600154338084526002602052604080852054815163097da6d360e41b81526001600160a01b0394851660048201523060248201526044810193909352606483018690526084830152805192909316936397da6d309360a48084019491939192918390030190829087803b15801561017457600080fd5b505af1158015610188573d6000803e3d6000fd5b505050506040513d604081101561019e57600080fd5b5050565b6000546001600160a01b031681565b60008054600154338352600260209081526040808520548151630acc462360e31b81526001600160a01b0394851660048201526024810191909152604481018690529051929093169263566231189260648083019392829003018186803b15801561021b57600080fd5b505afa15801561022f573d6000803e3d6000fd5b505050506040513d602081101561024557600080fd5b5051905090565b600080546001546040805162ae511b60e21b81526001600160a01b0392831660048201523360248201523060448201526064810186905260848101859052815192909316936302b9446c9360a48082019492918390030190829087803b1580156102b557600080fd5b505af11580156102c9573d6000803e3d6000fd5b505050506040513d60408110156102df57600080fd5b50602090810151336000908152600290925260409091205550565b60026020526000908152604090205481565b6001546001600160a01b03168156fea2646970667358221220bff415f0cc3cb9b5a32af1a15baaeb7e767371d3e7d712931b6b8654a2261ea164736f6c634300060c0033";
