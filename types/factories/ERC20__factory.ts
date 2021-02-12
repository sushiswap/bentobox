/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Signer } from "ethers";
import { Provider, TransactionRequest } from "@ethersproject/providers";
import { Contract, ContractFactory, Overrides } from "@ethersproject/contracts";

import type { ERC20 } from "../ERC20";

export class ERC20__factory extends ContractFactory {
  constructor(signer?: Signer) {
    super(_abi, _bytecode, signer);
  }

  deploy(overrides?: Overrides): Promise<ERC20> {
    return super.deploy(overrides || {}) as Promise<ERC20>;
  }
  getDeployTransaction(overrides?: Overrides): TransactionRequest {
    return super.getDeployTransaction(overrides || {});
  }
  attach(address: string): ERC20 {
    return super.attach(address) as ERC20;
  }
  connect(signer: Signer): ERC20__factory {
    return super.connect(signer) as ERC20__factory;
  }
  static connect(address: string, signerOrProvider: Signer | Provider): ERC20 {
    return new Contract(address, _abi, signerOrProvider) as ERC20;
  }
}

const _abi = [
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "_owner",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "_spender",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "_value",
        type: "uint256",
      },
    ],
    name: "Approval",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "_from",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "_to",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "_value",
        type: "uint256",
      },
    ],
    name: "Transfer",
    type: "event",
  },
  {
    inputs: [],
    name: "DOMAIN_SEPARATOR",
    outputs: [
      {
        internalType: "bytes32",
        name: "",
        type: "bytes32",
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
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    name: "allowance",
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
        internalType: "address",
        name: "spender",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "approve",
    outputs: [
      {
        internalType: "bool",
        name: "success",
        type: "bool",
      },
    ],
    stateMutability: "nonpayable",
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
    name: "balanceOf",
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
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    name: "nonces",
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
        internalType: "address",
        name: "owner_",
        type: "address",
      },
      {
        internalType: "address",
        name: "spender",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "value",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "deadline",
        type: "uint256",
      },
      {
        internalType: "uint8",
        name: "v",
        type: "uint8",
      },
      {
        internalType: "bytes32",
        name: "r",
        type: "bytes32",
      },
      {
        internalType: "bytes32",
        name: "s",
        type: "bytes32",
      },
    ],
    name: "permit",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "transfer",
    outputs: [
      {
        internalType: "bool",
        name: "success",
        type: "bool",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "from",
        type: "address",
      },
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "transferFrom",
    outputs: [
      {
        internalType: "bool",
        name: "success",
        type: "bool",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
];

const _bytecode =
  "0x608060405234801561001057600080fd5b50610d58806100206000396000f3fe608060405234801561001057600080fd5b50600436106100885760003560e01c80637ecebe001161005b5780637ecebe001461016a578063a9059cbb1461019d578063d505accf146101d6578063dd62ed3e1461023657610088565b8063095ea7b31461008d57806323b872dd146100da5780633644e5151461011d57806370a0823114610137575b600080fd5b6100c6600480360360408110156100a357600080fd5b5073ffffffffffffffffffffffffffffffffffffffff8135169060200135610271565b604080519115158252519081900360200190f35b6100c6600480360360608110156100f057600080fd5b5073ffffffffffffffffffffffffffffffffffffffff8135811691602081013590911690604001356102e4565b61012561066e565b60408051918252519081900360200190f35b6101256004803603602081101561014d57600080fd5b503573ffffffffffffffffffffffffffffffffffffffff166106c5565b6101256004803603602081101561018057600080fd5b503573ffffffffffffffffffffffffffffffffffffffff166106d7565b6100c6600480360360408110156101b357600080fd5b5073ffffffffffffffffffffffffffffffffffffffff81351690602001356106e9565b610234600480360360e08110156101ec57600080fd5b5073ffffffffffffffffffffffffffffffffffffffff813581169160208101359091169060408101359060608101359060ff6080820135169060a08101359060c001356108fa565b005b6101256004803603604081101561024c57600080fd5b5073ffffffffffffffffffffffffffffffffffffffff81358116916020013516610d05565b33600081815260016020908152604080832073ffffffffffffffffffffffffffffffffffffffff8716808552908352818420869055815186815291519394909390927f8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925928290030190a350600192915050565b600073ffffffffffffffffffffffffffffffffffffffff831661036857604080517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601660248201527f45524332303a206e6f207a65726f206164647265737300000000000000000000604482015290519081900360640190fd5b73ffffffffffffffffffffffffffffffffffffffff84166000908152602081905260409020548211156103fc57604080517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601660248201527f45524332303a2062616c616e636520746f6f206c6f7700000000000000000000604482015290519081900360640190fd5b73ffffffffffffffffffffffffffffffffffffffff8416600090815260016020908152604080832033845290915290205482111561049b57604080517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601860248201527f45524332303a20616c6c6f77616e636520746f6f206c6f770000000000000000604482015290519081900360640190fd5b73ffffffffffffffffffffffffffffffffffffffff8316600090815260208190526040902054828101101561053157604080517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601860248201527f45524332303a206f766572666c6f772064657465637465640000000000000000604482015290519081900360640190fd5b73ffffffffffffffffffffffffffffffffffffffff841660009081526020818152604080832080548690039055600182528083203384529091529020547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff81146105ff5773ffffffffffffffffffffffffffffffffffffffff85166000908152600160209081526040808320338085529083529281902086850390558051868152905183927f8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925928290030190a35b73ffffffffffffffffffffffffffffffffffffffff808516600081815260208181526040918290208054880190558151878152915192938916927fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef9281900390910190a3506001949350505050565b604080517f47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218602080830191909152468284015230606080840191909152835180840390910181526080909201909252805191012090565b60006020819052908152604090205481565b60026020526000908152604090205481565b600073ffffffffffffffffffffffffffffffffffffffff831661076d57604080517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601660248201527f45524332303a206e6f207a65726f206164647265737300000000000000000000604482015290519081900360640190fd5b336000908152602081905260409020548211156107eb57604080517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601660248201527f45524332303a2062616c616e636520746f6f206c6f7700000000000000000000604482015290519081900360640190fd5b73ffffffffffffffffffffffffffffffffffffffff8316600090815260208190526040902054828101101561088157604080517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601860248201527f45524332303a206f766572666c6f772064657465637465640000000000000000604482015290519081900360640190fd5b336000818152602081815260408083208054879003905573ffffffffffffffffffffffffffffffffffffffff871680845292819020805487019055805186815290519293927fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef929181900390910190a350600192915050565b73ffffffffffffffffffffffffffffffffffffffff871661097c57604080517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601860248201527f45524332303a204f776e65722063616e6e6f7420626520300000000000000000604482015290519081900360640190fd5b8342106109ea57604080517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152600e60248201527f45524332303a2045787069726564000000000000000000000000000000000000604482015290519081900360640190fd5b60006040518060400160405280600281526020017f1901000000000000000000000000000000000000000000000000000000000000815250610a2a61066e565b73ffffffffffffffffffffffffffffffffffffffff808b1660008181526002602090815260409182902080546001810190915582517f6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c98184015280840194909452938d166060840152608083018c905260a083019390935260c08083018b90528151808403909101815260e0830190915280519083012084519092610100909201918291908601908083835b60208310610b1357805182527fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe09092019160209182019101610ad6565b51815160209384036101000a7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0180199092169116179052920194855250838101929092525060408051808403830181528184018083528151918401919091206000918290526060850180845281905260ff8a16608086015260a0850189905260c085018890529151919550935060019260e080820193927fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe081019281900390910190855afa158015610bea573d6000803e3d6000fd5b5050506020604051035190508873ffffffffffffffffffffffffffffffffffffffff168173ffffffffffffffffffffffffffffffffffffffff1614610c9057604080517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601860248201527f45524332303a20496e76616c6964205369676e61747572650000000000000000604482015290519081900360640190fd5b73ffffffffffffffffffffffffffffffffffffffff808a166000818152600160209081526040808320948d16808452948252918290208b905581518b815291517f8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b9259281900390910190a3505050505050505050565b60016020908152600092835260408084209091529082529020548156fea2646970667358221220045e27545e1b805150abf7e8f2b43f508708585b4b0fcb93e21cc3c6efde90f164736f6c634300060c0033";
