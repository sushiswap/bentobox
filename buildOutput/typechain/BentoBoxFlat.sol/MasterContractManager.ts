/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import type {
  BaseContract,
  BigNumber,
  BigNumberish,
  BytesLike,
  CallOverrides,
  ContractTransaction,
  Overrides,
  PayableOverrides,
  PopulatedTransaction,
  Signer,
  utils,
} from "ethers";
import type {
  FunctionFragment,
  Result,
  EventFragment,
} from "@ethersproject/abi";
import type { Listener, Provider } from "@ethersproject/providers";
import type {
  TypedEventFilter,
  TypedEvent,
  TypedListener,
  OnEvent,
} from "../common";

export interface MasterContractManagerInterface extends utils.Interface {
  contractName: "MasterContractManager";

  functions: {
    "DOMAIN_SEPARATOR()": FunctionFragment;
    "claimOwnership()": FunctionFragment;
    "deploy(address,bytes,bool)": FunctionFragment;
    "masterContractApproved(address,address)": FunctionFragment;
    "masterContractOf(address)": FunctionFragment;
    "nonces(address)": FunctionFragment;
    "owner()": FunctionFragment;
    "pendingOwner()": FunctionFragment;
    "registerProtocol()": FunctionFragment;
    "setMasterContractApproval(address,address,bool,uint8,bytes32,bytes32)": FunctionFragment;
    "transferOwnership(address,bool,bool)": FunctionFragment;
    "whitelistMasterContract(address,bool)": FunctionFragment;
    "whitelistedMasterContracts(address)": FunctionFragment;
  };

  getFunction(
    nameOrSignatureOrTopic:
      | "DOMAIN_SEPARATOR"
      | "claimOwnership"
      | "deploy"
      | "masterContractApproved"
      | "masterContractOf"
      | "nonces"
      | "owner"
      | "pendingOwner"
      | "registerProtocol"
      | "setMasterContractApproval"
      | "transferOwnership"
      | "whitelistMasterContract"
      | "whitelistedMasterContracts"
  ): FunctionFragment;

  encodeFunctionData(
    functionFragment: "DOMAIN_SEPARATOR",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "claimOwnership",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "deploy",
    values: [string, BytesLike, boolean]
  ): string;
  encodeFunctionData(
    functionFragment: "masterContractApproved",
    values: [string, string]
  ): string;
  encodeFunctionData(
    functionFragment: "masterContractOf",
    values: [string]
  ): string;
  encodeFunctionData(functionFragment: "nonces", values: [string]): string;
  encodeFunctionData(functionFragment: "owner", values?: undefined): string;
  encodeFunctionData(
    functionFragment: "pendingOwner",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "registerProtocol",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "setMasterContractApproval",
    values: [string, string, boolean, BigNumberish, BytesLike, BytesLike]
  ): string;
  encodeFunctionData(
    functionFragment: "transferOwnership",
    values: [string, boolean, boolean]
  ): string;
  encodeFunctionData(
    functionFragment: "whitelistMasterContract",
    values: [string, boolean]
  ): string;
  encodeFunctionData(
    functionFragment: "whitelistedMasterContracts",
    values: [string]
  ): string;

  decodeFunctionResult(
    functionFragment: "DOMAIN_SEPARATOR",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "claimOwnership",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "deploy", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "masterContractApproved",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "masterContractOf",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "nonces", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "owner", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "pendingOwner",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "registerProtocol",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "setMasterContractApproval",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "transferOwnership",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "whitelistMasterContract",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "whitelistedMasterContracts",
    data: BytesLike
  ): Result;

  events: {
    "LogDeploy(address,bytes,address)": EventFragment;
    "LogRegisterProtocol(address)": EventFragment;
    "LogSetMasterContractApproval(address,address,bool)": EventFragment;
    "LogWhiteListMasterContract(address,bool)": EventFragment;
    "OwnershipTransferred(address,address)": EventFragment;
  };

  getEvent(nameOrSignatureOrTopic: "LogDeploy"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "LogRegisterProtocol"): EventFragment;
  getEvent(
    nameOrSignatureOrTopic: "LogSetMasterContractApproval"
  ): EventFragment;
  getEvent(nameOrSignatureOrTopic: "LogWhiteListMasterContract"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "OwnershipTransferred"): EventFragment;
}

export interface LogDeployEventObject {
  masterContract: string;
  data: string;
  cloneAddress: string;
}
export type LogDeployEvent = TypedEvent<
  [string, string, string],
  LogDeployEventObject
>;

export type LogDeployEventFilter = TypedEventFilter<LogDeployEvent>;

export interface LogRegisterProtocolEventObject {
  protocol: string;
}
export type LogRegisterProtocolEvent = TypedEvent<
  [string],
  LogRegisterProtocolEventObject
>;

export type LogRegisterProtocolEventFilter =
  TypedEventFilter<LogRegisterProtocolEvent>;

export interface LogSetMasterContractApprovalEventObject {
  masterContract: string;
  user: string;
  approved: boolean;
}
export type LogSetMasterContractApprovalEvent = TypedEvent<
  [string, string, boolean],
  LogSetMasterContractApprovalEventObject
>;

export type LogSetMasterContractApprovalEventFilter =
  TypedEventFilter<LogSetMasterContractApprovalEvent>;

export interface LogWhiteListMasterContractEventObject {
  masterContract: string;
  approved: boolean;
}
export type LogWhiteListMasterContractEvent = TypedEvent<
  [string, boolean],
  LogWhiteListMasterContractEventObject
>;

export type LogWhiteListMasterContractEventFilter =
  TypedEventFilter<LogWhiteListMasterContractEvent>;

export interface OwnershipTransferredEventObject {
  previousOwner: string;
  newOwner: string;
}
export type OwnershipTransferredEvent = TypedEvent<
  [string, string],
  OwnershipTransferredEventObject
>;

export type OwnershipTransferredEventFilter =
  TypedEventFilter<OwnershipTransferredEvent>;

export interface MasterContractManager extends BaseContract {
  contractName: "MasterContractManager";

  connect(signerOrProvider: Signer | Provider | string): this;
  attach(addressOrName: string): this;
  deployed(): Promise<this>;

  interface: MasterContractManagerInterface;

  queryFilter<TEvent extends TypedEvent>(
    event: TypedEventFilter<TEvent>,
    fromBlockOrBlockhash?: string | number | undefined,
    toBlock?: string | number | undefined
  ): Promise<Array<TEvent>>;

  listeners<TEvent extends TypedEvent>(
    eventFilter?: TypedEventFilter<TEvent>
  ): Array<TypedListener<TEvent>>;
  listeners(eventName?: string): Array<Listener>;
  removeAllListeners<TEvent extends TypedEvent>(
    eventFilter: TypedEventFilter<TEvent>
  ): this;
  removeAllListeners(eventName?: string): this;
  off: OnEvent<this>;
  on: OnEvent<this>;
  once: OnEvent<this>;
  removeListener: OnEvent<this>;

  functions: {
    DOMAIN_SEPARATOR(overrides?: CallOverrides): Promise<[string]>;

    claimOwnership(
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;

    deploy(
      masterContract: string,
      data: BytesLike,
      useCreate2: boolean,
      overrides?: PayableOverrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;

    masterContractApproved(
      arg0: string,
      arg1: string,
      overrides?: CallOverrides
    ): Promise<[boolean]>;

    masterContractOf(
      arg0: string,
      overrides?: CallOverrides
    ): Promise<[string]>;

    nonces(arg0: string, overrides?: CallOverrides): Promise<[BigNumber]>;

    owner(overrides?: CallOverrides): Promise<[string]>;

    pendingOwner(overrides?: CallOverrides): Promise<[string]>;

    registerProtocol(
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;

    setMasterContractApproval(
      user: string,
      masterContract: string,
      approved: boolean,
      v: BigNumberish,
      r: BytesLike,
      s: BytesLike,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;

    transferOwnership(
      newOwner: string,
      direct: boolean,
      renounce: boolean,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;

    whitelistMasterContract(
      masterContract: string,
      approved: boolean,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;

    whitelistedMasterContracts(
      arg0: string,
      overrides?: CallOverrides
    ): Promise<[boolean]>;
  };

  DOMAIN_SEPARATOR(overrides?: CallOverrides): Promise<string>;

  claimOwnership(
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  deploy(
    masterContract: string,
    data: BytesLike,
    useCreate2: boolean,
    overrides?: PayableOverrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  masterContractApproved(
    arg0: string,
    arg1: string,
    overrides?: CallOverrides
  ): Promise<boolean>;

  masterContractOf(arg0: string, overrides?: CallOverrides): Promise<string>;

  nonces(arg0: string, overrides?: CallOverrides): Promise<BigNumber>;

  owner(overrides?: CallOverrides): Promise<string>;

  pendingOwner(overrides?: CallOverrides): Promise<string>;

  registerProtocol(
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  setMasterContractApproval(
    user: string,
    masterContract: string,
    approved: boolean,
    v: BigNumberish,
    r: BytesLike,
    s: BytesLike,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  transferOwnership(
    newOwner: string,
    direct: boolean,
    renounce: boolean,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  whitelistMasterContract(
    masterContract: string,
    approved: boolean,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  whitelistedMasterContracts(
    arg0: string,
    overrides?: CallOverrides
  ): Promise<boolean>;

  callStatic: {
    DOMAIN_SEPARATOR(overrides?: CallOverrides): Promise<string>;

    claimOwnership(overrides?: CallOverrides): Promise<void>;

    deploy(
      masterContract: string,
      data: BytesLike,
      useCreate2: boolean,
      overrides?: CallOverrides
    ): Promise<string>;

    masterContractApproved(
      arg0: string,
      arg1: string,
      overrides?: CallOverrides
    ): Promise<boolean>;

    masterContractOf(arg0: string, overrides?: CallOverrides): Promise<string>;

    nonces(arg0: string, overrides?: CallOverrides): Promise<BigNumber>;

    owner(overrides?: CallOverrides): Promise<string>;

    pendingOwner(overrides?: CallOverrides): Promise<string>;

    registerProtocol(overrides?: CallOverrides): Promise<void>;

    setMasterContractApproval(
      user: string,
      masterContract: string,
      approved: boolean,
      v: BigNumberish,
      r: BytesLike,
      s: BytesLike,
      overrides?: CallOverrides
    ): Promise<void>;

    transferOwnership(
      newOwner: string,
      direct: boolean,
      renounce: boolean,
      overrides?: CallOverrides
    ): Promise<void>;

    whitelistMasterContract(
      masterContract: string,
      approved: boolean,
      overrides?: CallOverrides
    ): Promise<void>;

    whitelistedMasterContracts(
      arg0: string,
      overrides?: CallOverrides
    ): Promise<boolean>;
  };

  filters: {
    "LogDeploy(address,bytes,address)"(
      masterContract?: string | null,
      data?: null,
      cloneAddress?: string | null
    ): LogDeployEventFilter;
    LogDeploy(
      masterContract?: string | null,
      data?: null,
      cloneAddress?: string | null
    ): LogDeployEventFilter;

    "LogRegisterProtocol(address)"(
      protocol?: string | null
    ): LogRegisterProtocolEventFilter;
    LogRegisterProtocol(
      protocol?: string | null
    ): LogRegisterProtocolEventFilter;

    "LogSetMasterContractApproval(address,address,bool)"(
      masterContract?: string | null,
      user?: string | null,
      approved?: null
    ): LogSetMasterContractApprovalEventFilter;
    LogSetMasterContractApproval(
      masterContract?: string | null,
      user?: string | null,
      approved?: null
    ): LogSetMasterContractApprovalEventFilter;

    "LogWhiteListMasterContract(address,bool)"(
      masterContract?: string | null,
      approved?: null
    ): LogWhiteListMasterContractEventFilter;
    LogWhiteListMasterContract(
      masterContract?: string | null,
      approved?: null
    ): LogWhiteListMasterContractEventFilter;

    "OwnershipTransferred(address,address)"(
      previousOwner?: string | null,
      newOwner?: string | null
    ): OwnershipTransferredEventFilter;
    OwnershipTransferred(
      previousOwner?: string | null,
      newOwner?: string | null
    ): OwnershipTransferredEventFilter;
  };

  estimateGas: {
    DOMAIN_SEPARATOR(overrides?: CallOverrides): Promise<BigNumber>;

    claimOwnership(
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;

    deploy(
      masterContract: string,
      data: BytesLike,
      useCreate2: boolean,
      overrides?: PayableOverrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;

    masterContractApproved(
      arg0: string,
      arg1: string,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    masterContractOf(
      arg0: string,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    nonces(arg0: string, overrides?: CallOverrides): Promise<BigNumber>;

    owner(overrides?: CallOverrides): Promise<BigNumber>;

    pendingOwner(overrides?: CallOverrides): Promise<BigNumber>;

    registerProtocol(
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;

    setMasterContractApproval(
      user: string,
      masterContract: string,
      approved: boolean,
      v: BigNumberish,
      r: BytesLike,
      s: BytesLike,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;

    transferOwnership(
      newOwner: string,
      direct: boolean,
      renounce: boolean,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;

    whitelistMasterContract(
      masterContract: string,
      approved: boolean,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;

    whitelistedMasterContracts(
      arg0: string,
      overrides?: CallOverrides
    ): Promise<BigNumber>;
  };

  populateTransaction: {
    DOMAIN_SEPARATOR(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    claimOwnership(
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;

    deploy(
      masterContract: string,
      data: BytesLike,
      useCreate2: boolean,
      overrides?: PayableOverrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;

    masterContractApproved(
      arg0: string,
      arg1: string,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    masterContractOf(
      arg0: string,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    nonces(
      arg0: string,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    owner(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    pendingOwner(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    registerProtocol(
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;

    setMasterContractApproval(
      user: string,
      masterContract: string,
      approved: boolean,
      v: BigNumberish,
      r: BytesLike,
      s: BytesLike,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;

    transferOwnership(
      newOwner: string,
      direct: boolean,
      renounce: boolean,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;

    whitelistMasterContract(
      masterContract: string,
      approved: boolean,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;

    whitelistedMasterContracts(
      arg0: string,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;
  };
}
