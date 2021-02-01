const {
  utils: { keccak256, defaultAbiCoder, toUtf8Bytes, solidityPack },
} = require("ethers")
const { ADDRESS_ZERO, addr, getBigNumber, getSignedMasterContractApprovalData } = require(".")
const ethers = require("ethers")
const { ecsign } = require("ethereumjs-util")

const ERC20abi = [
  {
    anonymous: false,
    inputs: [
      { indexed: true, internalType: "address", name: "_owner", type: "address" },
      { indexed: true, internalType: "address", name: "_spender", type: "address" },
      { indexed: false, internalType: "uint256", name: "_value", type: "uint256" },
    ],
    name: "Approval",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, internalType: "address", name: "_from", type: "address" },
      { indexed: true, internalType: "address", name: "_to", type: "address" },
      { indexed: false, internalType: "uint256", name: "_value", type: "uint256" },
    ],
    name: "Transfer",
    type: "event",
  },
  {
    inputs: [],
    name: "DOMAIN_SEPARATOR",
    outputs: [{ internalType: "bytes32", name: "", type: "bytes32" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      { internalType: "address", name: "", type: "address" },
      { internalType: "address", name: "", type: "address" },
    ],
    name: "allowance",
    outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      { internalType: "address", name: "spender", type: "address" },
      { internalType: "uint256", name: "amount", type: "uint256" },
    ],
    name: "approve",
    outputs: [{ internalType: "bool", name: "success", type: "bool" }],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [{ internalType: "address", name: "", type: "address" }],
    name: "balanceOf",
    outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [{ internalType: "address", name: "", type: "address" }],
    name: "nonces",
    outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      { internalType: "address", name: "owner_", type: "address" },
      { internalType: "address", name: "spender", type: "address" },
      { internalType: "uint256", name: "value", type: "uint256" },
      { internalType: "uint256", name: "deadline", type: "uint256" },
      { internalType: "uint8", name: "v", type: "uint8" },
      { internalType: "bytes32", name: "r", type: "bytes32" },
      { internalType: "bytes32", name: "s", type: "bytes32" },
    ],
    name: "permit",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      { internalType: "address", name: "to", type: "address" },
      { internalType: "uint256", name: "amount", type: "uint256" },
    ],
    name: "transfer",
    outputs: [{ internalType: "bool", name: "success", type: "bool" }],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      { internalType: "address", name: "from", type: "address" },
      { internalType: "address", name: "to", type: "address" },
      { internalType: "uint256", name: "amount", type: "uint256" },
    ],
    name: "transferFrom",
    outputs: [{ internalType: "bool", name: "success", type: "bool" }],
    stateMutability: "nonpayable",
    type: "function",
  },
]

const ACTION_ADD_COLLATERAL = 1
const ACTION_ADD_ASSET = 2
const ACTION_REPAY = 3
const ACTION_REMOVE_ASSET = 4
const ACTION_REMOVE_COLLATERAL = 5
const ACTION_BORROW = 6
const ACTION_CALL = 10
const ACTION_BENTO_DEPOSIT = 20
const ACTION_BENTO_WITHDRAW = 21
const ACTION_BENTO_TRANSFER = 22
const ACTION_BENTO_TRANSFER_MULTIPLE = 23
const ACTION_BENTO_SETAPPROVAL = 24
const ACTION_PERMIT = 30
const ACTION_GET_REPAY_AMOUNT = 40
const ACTION_GET_REPAY_PART = 41

class LendingPair {
  constructor(contract, helper) {
    this.contract = contract
    this.helper = helper
  }

  async init(bentoBox) {
    this.bentoBox = bentoBox
    this.asset = new ethers.Contract(await this.contract.asset(), ERC20abi, this.contract.signer)
    this.collateral = new ethers.Contract(await this.contract.collateral(), ERC20abi, this.contract.signer)
    await this.sync()
    return this
  }

  as(from) {
    let connectedPair = new LendingPair(this.contract.connect(from))
    connectedPair.bentoBox = this.bentoBox.connect(from)
    connectedPair.helper = this.helper
    connectedPair.asset = this.asset.connect(from)
    connectedPair.collateral = this.collateral.connect(from)

    return connectedPair
  }

  async sync() {
    /*this.info = {
            totalAssetAmount: (await this.bentoBox.totals(this.asset.address)).elastic,
            totalAssetShare: (await this.bentoBox.totals(this.asset.address)).base,
            totalCollateralAmount: (await this.bentoBox.totals(this.collateral.address)).elastic,
            totalCollateralShare: (await this.bentoBox.totals(this.collateral.address)).base,
            pairAssetShare: (await this.contract.totalAsset()).elastic,
            pairAssetFraction: (await this.contract.totalAsset()).base,
            pairBorrowAmount: (await this.contract.totalBorrow()).elastic,
            pairBorrowPart: (await this.contract.totalBorrow()).base
        }*/
    return this
  }

  async syncAs(from) {
    return this.as(from).sync()
  }

  async run(commandsFunction) {
    const commands = commandsFunction(this.cmd)
    for (let i = 0; i < commands.length; i++) {
      if (typeof commands[i] == "object" && commands[i].type == "LendingPairCmd") {
        //console.log("RUN CMD: ", commands[i].method, commands[i].params, commands[i].as ? commands[i].as.address : "")
        let pair = commands[i].pair
        if (commands[i].as) {
          pair = await pair.as(commands[i].as)
        }
        await pair.sync()
        let tx = await pair[commands[i].method](...commands[i].params)
        let receipt = await tx.wait()
        //console.log("Gas used: ", receipt.gasUsed.toString());
      } else if (typeof commands[i] == "object" && commands[i].type == "LendingPairDo") {
        //console.log("RUN DO: ", commands[i].method, commands[i].params)
        await commands[i].method(...commands[i].params)
      } else {
        //console.log("RUN: ", commands[i])
        await commands[i]
      }
    }
  }

  getDomainSeparator(tokenAddress, chainId) {
    return keccak256(
      defaultAbiCoder.encode(
        ["bytes32", "uint256", "address"],
        [keccak256(toUtf8Bytes("EIP712Domain(uint256 chainId,address verifyingContract)")), chainId, tokenAddress]
      )
    )
  }

  getApprovalDigest(token, approve, nonce, deadline, chainId = 1) {
    const PERMIT_TYPEHASH = keccak256(toUtf8Bytes("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"))
    const DOMAIN_SEPARATOR = this.getDomainSeparator(token.address, chainId)
    const msg = defaultAbiCoder.encode(
      ["bytes32", "address", "address", "uint256", "uint256", "uint256"],
      [PERMIT_TYPEHASH, approve.owner, approve.spender, approve.value, nonce, deadline]
    )
    const pack = solidityPack(["bytes1", "bytes1", "bytes32", "bytes32"], ["0x19", "0x01", DOMAIN_SEPARATOR, keccak256(msg)])
    return keccak256(pack)
  }

  tokenPermit(token, owner, owner_key, amount, nonce, deadline) {
    const digest = this.getApprovalDigest(
      token,
      {
        owner: addr(owner),
        spender: addr(this.bentoBox),
        value: amount,
      },
      nonce,
      deadline,
      owner.provider._network.chainId
    )
    const { v, r, s } = ecsign(Buffer.from(digest.slice(2), "hex"), Buffer.from(owner_key.replace("0x", ""), "hex"))

    //return token.permit(addr(owner), addr(this.bentoBox), amount, deadline, v, r, s);
    let data = token.interface.encodeFunctionData("permit", [addr(owner), addr(this.bentoBox), amount, deadline, v, r, s])
    return this.contract.cook(
      [ACTION_CALL],
      [0],
      [defaultAbiCoder.encode(["address", "bytes", "bool", "bool", "uint8"], [addr(token), data, false, false, 0])]
    )
  }

  approveAsset(amount) {
    return this.asset.approve(this.bentoBox.address, amount)
  }

  approveCollateral(amount) {
    return this.collateral.approve(this.bentoBox.address, amount)
  }

  depositCollateral(amount) {
    return this.contract.cook(
      [ACTION_BENTO_DEPOSIT, ACTION_ADD_COLLATERAL],
      [0, 0],
      [
        defaultAbiCoder.encode(["address", "address", "int256", "int256"], [this.collateral.address, addr(this.contract.signer), amount, 0]),
        defaultAbiCoder.encode(["int256", "address", "bool"], [-2, addr(this.contract.signer), false]),
      ]
    )
  }

  withdrawCollateral(share) {
    return this.contract.cook(
      [ACTION_REMOVE_COLLATERAL, ACTION_BENTO_WITHDRAW],
      [0, 0],
      [
        defaultAbiCoder.encode(["int256", "address"], [share, addr(this.contract.signer)]),
        defaultAbiCoder.encode(["address", "address", "int256", "int256"], [this.collateral.address, addr(this.contract.signer), 0, share]),
      ]
    )
  }

  depositAssetWithApproval(amount, masterContract, privateKey, nonce) {
    const { v, r, s } = getSignedMasterContractApprovalData(this.bentoBox, this.contract.signer, privateKey, addr(masterContract), true, nonce)
    return this.contract.cook(
      [ACTION_BENTO_SETAPPROVAL, ACTION_BENTO_DEPOSIT, ACTION_ADD_ASSET],
      [0, 0, 0],
      [
        defaultAbiCoder.encode(
          ["address", "address", "bool", "uint8", "bytes32", "bytes32"],
          [addr(this.contract.signer), addr(masterContract), true, v, r, s]
        ),
        defaultAbiCoder.encode(["address", "address", "int256", "int256"], [this.asset.address, addr(this.contract.signer), amount, 0]),
        defaultAbiCoder.encode(["int256", "address", "bool"], [-2, addr(this.contract.signer), false]),
      ]
    )
  }

  depositAsset(amount) {
    return this.contract.cook(
      [ACTION_BENTO_DEPOSIT, ACTION_ADD_ASSET],
      [0, 0],
      [
        defaultAbiCoder.encode(["address", "address", "int256", "int256"], [this.asset.address, addr(this.contract.signer), amount, 0]),
        defaultAbiCoder.encode(["int256", "address", "bool"], [-2, addr(this.contract.signer), false]),
      ]
    )
  }

  withdrawAsset(fraction) {
    return this.contract.cook(
      [ACTION_REMOVE_ASSET, ACTION_BENTO_WITHDRAW],
      [0, 0],
      [
        defaultAbiCoder.encode(["int256", "address"], [fraction, addr(this.contract.signer)]),
        defaultAbiCoder.encode(["address", "address", "int256", "int256"], [this.asset.address, addr(this.contract.signer), 0, -1]),
      ]
    )
  }

  repay(part) {
    return this.contract.cook(
      [ACTION_GET_REPAY_AMOUNT, ACTION_BENTO_DEPOSIT, ACTION_REPAY],
      [0, 0, 0],
      [
        defaultAbiCoder.encode(["int256"], [part]),
        defaultAbiCoder.encode(["address", "address", "int256", "int256"], [this.asset.address, addr(this.contract.signer), -1, 0]),
        defaultAbiCoder.encode(["int256", "address", "bool"], [part, addr(this.contract.signer), false]),
      ]
    )
  }

  repayFromBento(part) {
    return this.contract.repay(addr(this.contract.signer), false, part)
  }

  borrow(amount) {
    return this.contract.cook(
      [ACTION_BORROW, ACTION_BENTO_WITHDRAW],
      [0, 0],
      [
        defaultAbiCoder.encode(["uint256", "address"], [amount, addr(this.contract.signer)]),
        defaultAbiCoder.encode(["address", "address", "int256", "int256"], [this.asset.address, addr(this.contract.signer), 0, -2]),
      ]
    )
  }

  short(swapper, share, minAmount) {
    let data = swapper.interface.encodeFunctionData("swap", [
      this.asset.address,
      this.collateral.address,
      addr(this.contract.signer),
      minAmount,
      "0",
    ])
    return this.contract.cook(
      [ACTION_BORROW, ACTION_BENTO_TRANSFER, ACTION_CALL, ACTION_ADD_COLLATERAL],
      [0, 0, 0, 0, 0],
      [
        defaultAbiCoder.encode(["int256", "address"], [share, addr(this.contract.signer)]),
        defaultAbiCoder.encode(["address", "address", "int256"], [this.asset.address, swapper.address, -2]),
        defaultAbiCoder.encode(["address", "bytes", "bool", "bool", "uint8"], [swapper.address, data.slice(0, -64), false, true, 2]),
        defaultAbiCoder.encode(["int256", "address", "bool"], [-2, addr(this.contract.signer), false]),
      ]
    )
  }

  unwind(swapper, part, maxShare) {
    let data = swapper.interface.encodeFunctionData("swapExact", [
      this.collateral.address,
      this.asset.address,
      addr(this.contract.signer),
      addr(this.contract.signer),
      maxShare,
      0,
    ])
    return this.contract.cook(
      [ACTION_REMOVE_COLLATERAL, ACTION_GET_REPAY_AMOUNT, ACTION_CALL, ACTION_REPAY, ACTION_ADD_COLLATERAL],
      [0, 0, 0, 0, 0],
      [
        // Remove collateral for user to Swapper contract (maxShare)
        defaultAbiCoder.encode(["int256", "address"], [maxShare, addr(swapper)]),
        // Convert part to amount
        defaultAbiCoder.encode(["int256"], [part]),
        // Swap collateral less than maxShare to exactly part (converted to amount) asset, deliver asset to user and deliver unused collateral back to user
        defaultAbiCoder.encode(["address", "bytes", "bool", "bool", "uint8"], [swapper.address, data.slice(0, -64), true, false, 2]),
        // Repay part
        defaultAbiCoder.encode(["int256", "address", "bool"], [part, addr(this.contract.signer), false]),
        // Add unused collateral back
        defaultAbiCoder.encode(["int256", "address", "bool"], [-2, addr(this.contract.signer), false]),
      ]
    )
  }

  accrue() {
    return this.contract.accrue()
  }

  updateExchangeRate() {
    return this.contract.updateExchangeRate()
  }
}

Object.defineProperty(LendingPair.prototype, "cmd", {
  get: function () {
    function proxy(pair, as) {
      return new Proxy(pair, {
        get: function (target, method) {
          return function (...params) {
            if (method == "do") {
              return {
                type: "LendingPairDo",
                method: params[0],
                params: params.slice(1),
              }
            }
            if (method == "as") {
              return proxy(pair, params[0])
            }
            return {
              type: "LendingPairCmd",
              pair: target,
              method: method,
              params: params,
              as: as,
            }
          }
        },
      })
    }

    return proxy(this)
  },
})

LendingPair.deploy = async function (bentoBox, masterContract, masterContractClass, asset, collateral, oracle) {
  await oracle.set(getBigNumber(1))
  const oracleData = await oracle.getDataParameter()
  const initData = await masterContract.getInitData(addr(asset), addr(collateral), oracle.address, oracleData)
  const deployTx = await bentoBox.deploy(masterContract.address, initData)
  const cloneAddress = (await deployTx.wait()).events[1].args.cloneAddress
  const pair = await masterContractClass.attach(cloneAddress)
  const pairHelper = new LendingPair(pair)
  pairHelper.initData = initData
  await pairHelper.init(bentoBox)
  return pairHelper
}

module.exports = {
  LendingPair,
}
