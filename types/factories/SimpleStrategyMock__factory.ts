/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Signer } from "ethers";
import { Provider, TransactionRequest } from "@ethersproject/providers";
import { Contract, ContractFactory, Overrides } from "@ethersproject/contracts";

import type { SimpleStrategyMock } from "../SimpleStrategyMock";

export class SimpleStrategyMock__factory extends ContractFactory {
  constructor(signer?: Signer) {
    super(_abi, _bytecode, signer);
  }

  deploy(
    bentoBox_: string,
    token_: string,
    overrides?: Overrides
  ): Promise<SimpleStrategyMock> {
    return super.deploy(
      bentoBox_,
      token_,
      overrides || {}
    ) as Promise<SimpleStrategyMock>;
  }
  getDeployTransaction(
    bentoBox_: string,
    token_: string,
    overrides?: Overrides
  ): TransactionRequest {
    return super.getDeployTransaction(bentoBox_, token_, overrides || {});
  }
  attach(address: string): SimpleStrategyMock {
    return super.attach(address) as SimpleStrategyMock;
  }
  connect(signer: Signer): SimpleStrategyMock__factory {
    return super.connect(signer) as SimpleStrategyMock__factory;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): SimpleStrategyMock {
    return new Contract(address, _abi, signerOrProvider) as SimpleStrategyMock;
  }
}

const _abi = [
  {
    inputs: [
      {
        internalType: "address",
        name: "bentoBox_",
        type: "address",
      },
      {
        internalType: "contract IERC20",
        name: "token_",
        type: "address",
      },
    ],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "balance",
        type: "uint256",
      },
    ],
    name: "exit",
    outputs: [
      {
        internalType: "int256",
        name: "amountAdded",
        type: "int256",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "balance",
        type: "uint256",
      },
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    name: "harvest",
    outputs: [
      {
        internalType: "int256",
        name: "amountAdded",
        type: "int256",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    name: "skim",
    outputs: [],
    stateMutability: "nonpayable",
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
    name: "withdraw",
    outputs: [
      {
        internalType: "uint256",
        name: "actualAmount",
        type: "uint256",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
];

const _bytecode =
  "0x60c060405234801561001057600080fd5b506040516108b23803806108b28339818101604052604081101561003357600080fd5b5080516020909101516001600160601b0319606092831b811660a052911b1660805260805160601c60a05160601c6108076100ab6000398061010f528061029652806102db52806103a352806103e4528061048d52806105585250806101a152806102745280610381528061053652506108076000f3fe608060405234801561001057600080fd5b506004361061004c5760003560e01c806318fccc76146100515780632e1a7d4d1461009c5780636939aaf5146100b95780637f8661a1146100d8575b600080fd5b61008a6004803603604081101561006757600080fd5b508035906020013573ffffffffffffffffffffffffffffffffffffffff166100f5565b60408051918252519081900360200190f35b61008a600480360360208110156100b257600080fd5b50356102c1565b6100d6600480360360208110156100cf57600080fd5b50356103cc565b005b61008a600480360360208110156100ee57600080fd5b5035610473565b60003373ffffffffffffffffffffffffffffffffffffffff7f0000000000000000000000000000000000000000000000000000000000000000161461019b57604080517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820181905260248201527f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e6572604482015290519081900360640190fd5b610258837f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff166370a08231306040518263ffffffff1660e01b8152600401808273ffffffffffffffffffffffffffffffffffffffff16815260200191505060206040518083038186803b15801561022657600080fd5b505afa15801561023a573d6000803e3d6000fd5b505050506040513d602081101561025057600080fd5b505190610582565b90506102bb73ffffffffffffffffffffffffffffffffffffffff7f0000000000000000000000000000000000000000000000000000000000000000167f0000000000000000000000000000000000000000000000000000000000000000836105f4565b92915050565b60003373ffffffffffffffffffffffffffffffffffffffff7f0000000000000000000000000000000000000000000000000000000000000000161461036757604080517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820181905260248201527f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e6572604482015290519081900360640190fd5b6103c873ffffffffffffffffffffffffffffffffffffffff7f0000000000000000000000000000000000000000000000000000000000000000167f0000000000000000000000000000000000000000000000000000000000000000846105f4565b5090565b3373ffffffffffffffffffffffffffffffffffffffff7f0000000000000000000000000000000000000000000000000000000000000000161461047057604080517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820181905260248201527f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e6572604482015290519081900360640190fd5b50565b60003373ffffffffffffffffffffffffffffffffffffffff7f0000000000000000000000000000000000000000000000000000000000000000161461051957604080517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820181905260248201527f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e6572604482015290519081900360640190fd5b50600061057d73ffffffffffffffffffffffffffffffffffffffff7f0000000000000000000000000000000000000000000000000000000000000000167f0000000000000000000000000000000000000000000000000000000000000000846105f4565b919050565b808203828111156102bb57604080517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601560248201527f426f72696e674d6174683a20556e646572666c6f770000000000000000000000604482015290519081900360640190fd5b6040805173ffffffffffffffffffffffffffffffffffffffff8481166024830152604480830185905283518084039091018152606490920183526020820180517bffffffffffffffffffffffffffffffffffffffffffffffffffffffff167fa9059cbb00000000000000000000000000000000000000000000000000000000178152925182516000946060949389169392918291908083835b602083106106ca57805182527fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0909201916020918201910161068d565b6001836020036101000a0380198251168184511680821785525050505050509050019150506000604051808303816000865af19150503d806000811461072c576040519150601f19603f3d011682016040523d82523d6000602084013e610731565b606091505b509150915081801561075f57508051158061075f575080806020019051602081101561075c57600080fd5b50515b6107ca57604080517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601c60248201527f426f72696e6745524332303a205472616e73666572206661696c656400000000604482015290519081900360640190fd5b505050505056fea26469706673582212207518b0fbe840da16142cce2d24102177b490255445ff984bf14349c1d6ac550f64736f6c634300060c0033";
