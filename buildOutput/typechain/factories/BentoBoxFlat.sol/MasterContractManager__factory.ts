/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import type { Provider, TransactionRequest } from "@ethersproject/providers";
import type {
  MasterContractManager,
  MasterContractManagerInterface,
} from "../../BentoBoxFlat.sol/MasterContractManager";

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
        name: "masterContract",
        type: "address",
      },
      {
        indexed: false,
        internalType: "bytes",
        name: "data",
        type: "bytes",
      },
      {
        indexed: true,
        internalType: "address",
        name: "cloneAddress",
        type: "address",
      },
    ],
    name: "LogDeploy",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "protocol",
        type: "address",
      },
    ],
    name: "LogRegisterProtocol",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "masterContract",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "user",
        type: "address",
      },
      {
        indexed: false,
        internalType: "bool",
        name: "approved",
        type: "bool",
      },
    ],
    name: "LogSetMasterContractApproval",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "masterContract",
        type: "address",
      },
      {
        indexed: false,
        internalType: "bool",
        name: "approved",
        type: "bool",
      },
    ],
    name: "LogWhiteListMasterContract",
    type: "event",
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
    inputs: [],
    name: "claimOwnership",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "masterContract",
        type: "address",
      },
      {
        internalType: "bytes",
        name: "data",
        type: "bytes",
      },
      {
        internalType: "bool",
        name: "useCreate2",
        type: "bool",
      },
    ],
    name: "deploy",
    outputs: [
      {
        internalType: "address",
        name: "cloneAddress",
        type: "address",
      },
    ],
    stateMutability: "payable",
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
    name: "masterContractApproved",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
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
    name: "masterContractOf",
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
    inputs: [],
    name: "registerProtocol",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "user",
        type: "address",
      },
      {
        internalType: "address",
        name: "masterContract",
        type: "address",
      },
      {
        internalType: "bool",
        name: "approved",
        type: "bool",
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
    name: "setMasterContractApproval",
    outputs: [],
    stateMutability: "nonpayable",
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
  {
    inputs: [
      {
        internalType: "address",
        name: "masterContract",
        type: "address",
      },
      {
        internalType: "bool",
        name: "approved",
        type: "bool",
      },
    ],
    name: "whitelistMasterContract",
    outputs: [],
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
    name: "whitelistedMasterContracts",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
];

const _bytecode =
  "0x60c060405234801561001057600080fd5b50600080546001600160a01b0319163390811782556040519091907f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0908290a34660a081905261005f81610068565b60805250610102565b60007f8cad95687ba82c2ce50e74f7b754645e5117c3a5bec8151c0726d5857980a8667fd7df266aff736d415a9dc14b4158201d612e70d75b9c7f4e375ccfd20aa5166f83306040516020016100c194939291906100de565b604051602081830303815290604052805190602001209050919050565b938452602084019290925260408301526001600160a01b0316606082015260800190565b60805160a0516111e4610125600039806105b95250806105ee52506111e46000f3fe6080604052600436106100d25760003560e01c80637ecebe001161007f578063aee4d1b211610059578063aee4d1b2146101fb578063bafe4f1414610210578063c0a47c9314610230578063e30c397814610250576100d2565b80637ecebe00146101a65780638da5cb5b146101c657806391e0eab5146101db576100d2565b80633644e515116100b05780633644e5151461014f5780634e71e0c814610171578063733a9d7c14610186576100d2565b8063078dfbe7146100d757806312a90c8a146100f95780631f54245b1461012f575b600080fd5b3480156100e357600080fd5b506100f76100f2366004610d2c565b610265565b005b34801561010557600080fd5b50610119610114366004610c3c565b610384565b6040516101269190610e6f565b60405180910390f35b61014261013d366004610d75565b610399565b6040516101269190610e5b565b34801561015b57600080fd5b506101646105b4565b6040516101269190610e7a565b34801561017d57600080fd5b506100f7610614565b34801561019257600080fd5b506100f76101a1366004610d01565b6106b9565b3480156101b257600080fd5b506101646101c1366004610c3c565b610787565b3480156101d257600080fd5b50610142610799565b3480156101e757600080fd5b506101196101f6366004610c5e565b6107a8565b34801561020757600080fd5b506100f76107c8565b34801561021c57600080fd5b5061014261022b366004610c3c565b610827565b34801561023c57600080fd5b506100f761024b366004610c92565b610842565b34801561025c57600080fd5b50610142610b8a565b6000546001600160a01b031633146102985760405162461bcd60e51b815260040161028f90610feb565b60405180910390fd5b811561034b576001600160a01b0383161515806102b25750805b6102ce5760405162461bcd60e51b815260040161028f90610fb4565b600080546040516001600160a01b03808716939216917f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e091a3600080546001600160a01b0385167fffffffffffffffffffffffff00000000000000000000000000000000000000009182161790915560018054909116905561037f565b600180547fffffffffffffffffffffffff0000000000000000000000000000000000000000166001600160a01b0385161790555b505050565b60046020526000908152604090205460ff1681565b60006001600160a01b0385166103c15760405162461bcd60e51b815260040161028f906110c3565b606085901b821561044a57600085856040516103de929190610e07565b604051809103902090506040517f3d602d80600a3d3981f3363d3d373d3d3d363d7300000000000000000000000081528260148201527f5af43d82803e903d91602b57fd5bf300000000000000000000000000000000006028820152816037826000f5935050506104a6565b6040517f3d602d80600a3d3981f3363d3d373d3d3d363d7300000000000000000000000081528160148201527f5af43d82803e903d91602b57fd5bf3000000000000000000000000000000000060288201526037816000f09250505b6001600160a01b038281166000818152600260205260409081902080547fffffffffffffffffffffffff000000000000000000000000000000000000000016938a169390931790925590517f4ddf47d4000000000000000000000000000000000000000000000000000000008152634ddf47d490349061052c9089908990600401610ef9565b6000604051808303818588803b15801561054557600080fd5b505af1158015610559573d6000803e3d6000fd5b5050505050816001600160a01b0316866001600160a01b03167fd62166f3c2149208e51788b1401cc356bf5da1fc6c7886a32e18570f57d88b3b87876040516105a3929190610ef9565b60405180910390a350949350505050565b6000467f000000000000000000000000000000000000000000000000000000000000000081146105ec576105e781610b99565b61060e565b7f00000000000000000000000000000000000000000000000000000000000000005b91505090565b6001546001600160a01b031633811461063f5760405162461bcd60e51b815260040161028f90611020565b600080546040516001600160a01b03808516939216917f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e091a3600080546001600160a01b039092167fffffffffffffffffffffffff0000000000000000000000000000000000000000928316179055600180549091169055565b6000546001600160a01b031633146106e35760405162461bcd60e51b815260040161028f90610feb565b6001600160a01b0382166107095760405162461bcd60e51b815260040161028f90610f46565b6001600160a01b0382166000818152600460205260409081902080547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0016841515179055517f31a1e0eac44b54ac6c2a2efa87e92c83405ffcf33fceef02a7bca695130e26009061077b908490610e6f565b60405180910390a25050565b60056020526000908152604090205481565b6000546001600160a01b031681565b600360209081526000928352604080842090915290825290205460ff1681565b3360008181526002602052604080822080547fffffffffffffffffffffffff00000000000000000000000000000000000000001684179055517fdfb44ffabf0d3a8f650d3ce43eff98f6d050e7ea1a396d5794f014e7dadabacb9190a2565b6002602052600090815260409020546001600160a01b031681565b6001600160a01b0385166108685760405162461bcd60e51b815260040161028f906110f8565b81158015610874575080155b8015610881575060ff8316155b15610923576001600160a01b03861633146108ae5760405162461bcd60e51b815260040161028f90610f7d565b6001600160a01b0386811660009081526002602052604090205416156108e65760405162461bcd60e51b815260040161028f90611055565b6001600160a01b03851660009081526004602052604090205460ff1661091e5760405162461bcd60e51b815260040161028f90611166565b610af8565b6001600160a01b0386166109495760405162461bcd60e51b815260040161028f9061112f565b60006040518060400160405280600281526020017f19010000000000000000000000000000000000000000000000000000000000008152506109896105b4565b7f1962bc9f5484cb7a998701b81090e966ee1fce5771af884cceee7c081b14ade2876109d5577fb426802f1f7dc850a7b6b38805edea2442f3992878a9ab985abfe8091d95d0b16109f7565b7f422ac5323fe049241dee67716229a1cc1bc7b313b23dfe3ef6d42ab177a3b2845b6001600160a01b038b166000908152600560209081526040918290208054600181019091559151610a319493928e928e928e929101610e83565b60405160208183030381529060405280519060200120604051602001610a5993929190610e17565b604051602081830303815290604052805190602001209050600060018286868660405160008152602001604052604051610a969493929190610edb565b6020604051602081039080840390855afa158015610ab8573d6000803e3d6000fd5b505050602060405103519050876001600160a01b0316816001600160a01b031614610af55760405162461bcd60e51b815260040161028f9061108c565b50505b6001600160a01b038581166000818152600360209081526040808320948b16808452949091529081902080547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0016881515179055517f5f6ebb64ba012a851c6f014e6cad458ddf213d1512049b31cd06365c2b05925790610b7a908890610e6f565b60405180910390a3505050505050565b6001546001600160a01b031681565b60007f8cad95687ba82c2ce50e74f7b754645e5117c3a5bec8151c0726d5857980a8667fd7df266aff736d415a9dc14b4158201d612e70d75b9c7f4e375ccfd20aa5166f8330604051602001610bf29493929190610eb7565b604051602081830303815290604052805190602001209050919050565b80356001600160a01b0381168114610c2657600080fd5b92915050565b80358015158114610c2657600080fd5b600060208284031215610c4d578081fd5b610c578383610c0f565b9392505050565b60008060408385031215610c70578081fd5b610c7a8484610c0f565b9150610c898460208501610c0f565b90509250929050565b60008060008060008060c08789031215610caa578182fd5b610cb48888610c0f565b9550610cc38860208901610c0f565b9450610cd28860408901610c2c565b9350606087013560ff81168114610ce7578283fd5b9598949750929560808101359460a0909101359350915050565b60008060408385031215610d13578182fd5b610d1d8484610c0f565b9150610c898460208501610c2c565b600080600060608486031215610d40578283fd5b610d4a8585610c0f565b92506020840135610d5a8161119d565b91506040840135610d6a8161119d565b809150509250925092565b60008060008060608587031215610d8a578384fd5b610d948686610c0f565b9350602085013567ffffffffffffffff80821115610db0578485fd5b818701915087601f830112610dc3578485fd5b813581811115610dd1578586fd5b886020828501011115610de2578586fd5b6020830195508094505050506040850135610dfc8161119d565b939692955090935050565b6000828483379101908152919050565b60008451815b81811015610e375760208188018101518583015201610e1d565b81811115610e455782828501525b5091909101928352506020820152604001919050565b6001600160a01b0391909116815260200190565b901515815260200190565b90815260200190565b95865260208601949094526001600160a01b039283166040860152911660608401521515608083015260a082015260c00190565b938452602084019290925260408301526001600160a01b0316606082015260800190565b93845260ff9290921660208401526040830152606082015260800190565b60006020825282602083015282846040840137818301604090810191909152601f9092017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0160101919050565b6020808252601c908201527f4d6173746572434d67723a2043616e6e6f7420617070726f7665203000000000604082015260600190565b6020808252601b908201527f4d6173746572434d67723a2075736572206e6f742073656e6465720000000000604082015260600190565b60208082526015908201527f4f776e61626c653a207a65726f20616464726573730000000000000000000000604082015260600190565b6020808252818101527f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e6572604082015260600190565b6020808252818101527f4f776e61626c653a2063616c6c657220213d2070656e64696e67206f776e6572604082015260600190565b60208082526019908201527f4d6173746572434d67723a207573657220697320636c6f6e6500000000000000604082015260600190565b6020808252601d908201527f4d6173746572434d67723a20496e76616c6964205369676e6174757265000000604082015260600190565b6020808252818101527f426f72696e67466163746f72793a204e6f206d6173746572436f6e7472616374604082015260600190565b6020808252601b908201527f4d6173746572434d67723a206d617374657243206e6f74207365740000000000604082015260600190565b6020808252601c908201527f4d6173746572434d67723a20557365722063616e6e6f74206265203000000000604082015260600190565b6020808252601b908201527f4d6173746572434d67723a206e6f742077686974656c69737465640000000000604082015260600190565b80151581146111ab57600080fd5b5056fea2646970667358221220abe0a94e063abf3fda315f397c37a27c6550557d8a6008b9e2a1cb30bbd920e064736f6c634300060c0033";

type MasterContractManagerConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: MasterContractManagerConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class MasterContractManager__factory extends ContractFactory {
  constructor(...args: MasterContractManagerConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
    this.contractName = "MasterContractManager";
  }

  override deploy(
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<MasterContractManager> {
    return super.deploy(overrides || {}) as Promise<MasterContractManager>;
  }
  override getDeployTransaction(
    overrides?: Overrides & { from?: string | Promise<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(overrides || {});
  }
  override attach(address: string): MasterContractManager {
    return super.attach(address) as MasterContractManager;
  }
  override connect(signer: Signer): MasterContractManager__factory {
    return super.connect(signer) as MasterContractManager__factory;
  }
  static readonly contractName: "MasterContractManager";

  public readonly contractName: "MasterContractManager";

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): MasterContractManagerInterface {
    return new utils.Interface(_abi) as MasterContractManagerInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): MasterContractManager {
    return new Contract(
      address,
      _abi,
      signerOrProvider
    ) as MasterContractManager;
  }
}
