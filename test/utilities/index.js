const {
    BigNumber,
    utils: { keccak256, defaultAbiCoder, toUtf8Bytes, solidityPack },
} = require("ethers")
const { ecsign } = require("ethereumjs-util")
const { deployments, ethers } = require("hardhat")
const { BN } = require("bn.js")

const ADDRESS_ZERO = "0x0000000000000000000000000000000000000000"
const BASE_TEN = 10
const PERMIT_TYPEHASH = keccak256(toUtf8Bytes("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"))
const BENTOBOX_MASTER_APPROVAL_TYPEHASH = keccak256(
    toUtf8Bytes("SetMasterContractApproval(string warning,address user,address masterContract,bool approved,uint256 nonce)")
)

const contracts = {}

function roundBN(number) {
    return new BN(number.toString()).divRound(new BN("10000000000000000")).toString()
}

function encodePrice(reserve0, reserve1) {
    return [reserve1.mul(getBigNumber(1)).div(reserve0), reserve0.mul(getBigNumber(1)).div(reserve1)]
}

function getDomainSeparator(tokenAddress, chainId) {
    return keccak256(
        defaultAbiCoder.encode(
            ["bytes32", "uint256", "address"],
            [keccak256(toUtf8Bytes("EIP712Domain(uint256 chainId,address verifyingContract)")), chainId, tokenAddress]
        )
    )
}

function getApprovalDigest(token, approve, nonce, deadline, chainId = 1) {
    const DOMAIN_SEPARATOR = getDomainSeparator(token.address, chainId)
    const msg = defaultAbiCoder.encode(
        ["bytes32", "address", "address", "uint256", "uint256", "uint256"],
        [PERMIT_TYPEHASH, approve.owner, approve.spender, approve.value, nonce, deadline]
    )
    const pack = solidityPack(["bytes1", "bytes1", "bytes32", "bytes32"], ["0x19", "0x01", DOMAIN_SEPARATOR, keccak256(msg)])
    return keccak256(pack)
}

function getApprovalMsg(tokenAddress, approve, nonce, deadline) {
    const DOMAIN_SEPARATOR = getDomainSeparator(tokenAddress)
    const msg = defaultAbiCoder.encode(
        ["bytes32", "address", "address", "uint256", "uint256", "uint256"],
        [PERMIT_TYPEHASH, approve.owner, approve.spender, approve.value, nonce, deadline]
    )
    const pack = solidityPack(["bytes1", "bytes1", "bytes32", "bytes32"], ["0x19", "0x01", DOMAIN_SEPARATOR, keccak256(msg)])
    return pack
}

function getBentoBoxDomainSeparator(address, chainId) {
    return keccak256(
        defaultAbiCoder.encode(
            ["bytes32", "bytes32", "uint256", "address"],
            [
                keccak256(toUtf8Bytes("EIP712Domain(string name,uint256 chainId,address verifyingContract)")),
                keccak256(toUtf8Bytes("BentoBox V1")),
                chainId,
                address,
            ]
        )
    )
}

function getBentoBoxApprovalDigest(bentoBox, user, masterContractAddress, approved, nonce, chainId = 1) {
    const DOMAIN_SEPARATOR = getBentoBoxDomainSeparator(bentoBox.address, chainId)
    const msg = defaultAbiCoder.encode(
        ["bytes32", "bytes32", "address", "address", "bool", "uint256"],
        [
            BENTOBOX_MASTER_APPROVAL_TYPEHASH,
            approved
                ? keccak256(toUtf8Bytes("Give FULL access to funds in (and approved to) BentoBox?"))
                : keccak256(toUtf8Bytes("Revoke access to BentoBox?")),
            user.address,
            masterContractAddress,
            approved,
            nonce,
        ]
    )
    const pack = solidityPack(["bytes1", "bytes1", "bytes32", "bytes32"], ["0x19", "0x01", DOMAIN_SEPARATOR, keccak256(msg)])
    return keccak256(pack)
}

function getSignedMasterContractApprovalData(bentoBox, user, privateKey, masterContractAddress, approved, nonce) {
    const digest = getBentoBoxApprovalDigest(bentoBox, user, masterContractAddress, approved, nonce, user.provider._network.chainId)
    const { v, r, s } = ecsign(Buffer.from(digest.slice(2), "hex"), Buffer.from(privateKey.replace("0x", ""), "hex"))
    return { v, r, s }
}

async function setMasterContractApproval(bentoBox, from, user, privateKey, masterContractAddress, approved, fallback) {
    if (!fallback) {
        const nonce = await bentoBox.nonces(user.address)

        const digest = getBentoBoxApprovalDigest(bentoBox, user, masterContractAddress, approved, nonce, user.provider._network.chainId)
        const { v, r, s } = ecsign(Buffer.from(digest.slice(2), "hex"), Buffer.from(privateKey.replace("0x", ""), "hex"))

        return await bentoBox.connect(user).setMasterContractApproval(from.address, masterContractAddress, approved, v, r, s)
    }
    return await bentoBox
        .connect(user)
        .setMasterContractApproval(
            from.address,
            masterContractAddress,
            approved,
            0,
            "0x0000000000000000000000000000000000000000000000000000000000000000",
            "0x0000000000000000000000000000000000000000000000000000000000000000"
        )
}

function sansSafetyAmount(amount) {
    return amount.sub(BigNumber.from(100000))
}

async function advanceTimeAndBlock(time, ethers) {
    await advanceTime(time, ethers)
    await advanceBlock(ethers)
}

async function advanceTime(time, ethers) {
    await ethers.provider.send("evm_increaseTime", [time])
}

async function advanceBlock(ethers) {
    await ethers.provider.send("evm_mine")
}

// Defaults to e18 using amount * 10^18
function getBigNumber(amount, decimals = 18) {
    return BigNumber.from(amount).mul(BigNumber.from(BASE_TEN).pow(decimals))
}

function addContract(thisObject, name, contract) {
    thisObject[name] = contract
    contract.thisName = name
    contracts[contract.address] = contract
}

async function getContract(thisObject, var_name, name) {
    const contract = await ethers.getContract(name)
    addContract(thisObject, var_name, contract)
    return contract
}

async function analyse(thisObject, tx_promise) {
    let tx
    try {
        tx = await tx_promise
    } catch (e) {
        const revertMsg = e.message.replace("VM Exception while processing transaction: revert ", "")
        if (revertMsg) {
            console.log('.to.be.revertedWith("' + revertMsg + '")')
        } else {
            console.log(".to.be.reverted")
        }
        return
    }
    const rx = await thisObject.alice.provider.getTransactionReceipt(tx.hash)
    const logs = decodeLogs(rx.logs)
    for (var i in logs) {
        var log = logs[i]
        console.log(".to.emit(this." + log.contract_name + ', "' + log.name + '")')
        console.log(".withArgs(" + log.args.join(", ") + ")")
    }
}

function weth(chainId) {
    return {
        1: "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2", // Mainnet
        3: "0xc778417E063141139Fce010982780140Aa0cD5Ab", // Ropsten
        4: "0xc778417E063141139Fce010982780140Aa0cD5Ab", // Rinkeby
        5: "0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6", // Gorli
        42: "0xd0A1E359811322d97991E03f863a0C30C2cF029C", // Kovan
        56: "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c", // Binance
        88: "0xB1f66997A5760428D3a87D68b90BfE0aE64121cC", // TomoChain
        89: "0xB837c744A16A7f133A750254270Dce792dBBAE77", // TomoChain Testnet
        97: "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd", // Binance Testnet
        128: "0x5545153ccfca01fbd7dd11c0b23ba694d9509a6f", // Huobi ECO Chain
        137: "0x084666322d3ee89aAbDBBCd084323c9AF705C7f5", // Matic
        250: "0x21be370d5312f44cb42ce377bc9b8a0cef1a4c83", // Fantom
        256: "0x7af326b6351c8a9b8fb8cd205cbe11d4ac5fa836", // Huobi ECO Testnet
        4002: "0xf1277d1ed8ad466beddf92ef448a132661956621", // Fantom Testnet
        1287: "0x1Ff68A3621C17a38E689E5332Efcab9e6bE88b5D", // Moonbeam Testnet
        31337: "", // Hardhat
        43113: "0xd00ae08403B9bbb9124bB305C09058E32C39A48c", // Fuji Testnet (Avalanche)
        43114: "0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7", // Avalanche
        80001: "0x5B67676a984807a212b1c59eBFc9B3568a474F0a", // Mumbai Testnet (MATIC)
        79377087078960: "0xf8456e5e6A225C2C1D74D8C9a4cB2B1d5dc1153b", // Arbitrum Testnet
    }[chainId.toString()]
}

function nativeTokenSymbol(chainId) {
    return {
        1: "ETH", // Mainnet
        3: "ETH", // Ropsten
        4: "ETH", // Rinkeby
        5: "ETH", // Goerli
        42: "ETH", // Kovan
        56: "BNB", // Binance
        88: "TOMO", //TomoChain
        89: "TOMO", // TomoChain Testnet
        97: "BNB", // Binance Testnet
        128: "HT", // Huobi ECO Chain
        137: "MATIC", // Matic
        250: "FTM", // Fantom
        256: "HT", // Huobi ECO Testnet
        4002: "FTM", // Fantom Testnet
        1287: "ETH", // Moonbeam Testnet
        43113: "AVAX", // Fuji Testnet (Avalanche)
        43114: "AVAX", // Avalanche
        80001: "MATIC", // Mumbai Testnet (MATIC)
        79377087078960: "ETH", // Arbitrum Testnet
    }[chainId.toString()]
}

function explorer(chainId) {
    return {
        1: "https://etherscan.io", // Mainnet
        3: "https://ropsten.etherscan.io", // Ropsten
        4: "https://rinkeby.etherscan.io", // Rinkeby
        5: "https://goerli.etherscan.io", // Goerli
        42: "https://kovan.etherscan.io", // Kovan
        56: "https://bscscan.com", // Binance
        88: "https://scan.tomochain.com", //TomoChain
        89: "https://scan.testnet.tomochain.com", // TomoChain Testnet
        97: "https://testnet.bscscan.com", // Binance Testnet
        128: "https://hecoinfo.com", // Huobi ECO Chain
        137: "https://explorer-mainnet.maticvigil.com", // Matic
        250: "https://ftmscan.com", // Fantom
        256: "", // Huobi ECO Testnet
        4002: "https://explorer.testnet.fantom.network", // Fantom Testnet
        1287: "https://moonbeam-explorer.netlify.app", // Moonbeam Testnet
        43113: "https://cchain.explorer.avax-test.network", // Fuji Testnet (Avalanche)
        43114: "https://cchain.explorer.avax.network", // Avalanche
        80001: "https://explorer-mumbai.maticvigil.com", // Mumbai Testnet (MATIC)
        79377087078960: "https://explorer.offchainlabs.com/#", // Arbitrum Testnet
    }[chainId.toString()]
}

async function createFixture(deployments, thisObject, stepsFunction) {
    return deployments.createFixture(async ({ deployments, getNamedAccounts, ethers }, options) => {
        const { deployer } = await getNamedAccounts()

        await deployments.fixture()

        thisObject.signers = await ethers.getSigners()
        addContract(thisObject, "alice", thisObject.signers[0])
        addContract(thisObject, "bob", thisObject.signers[1])
        addContract(thisObject, "carol", thisObject.signers[2])
        addContract(thisObject, "dirk", thisObject.signers[3])
        addContract(thisObject, "erin", thisObject.signers[4])
        addContract(thisObject, "fred", thisObject.signers[5])
        thisObject.alicePrivateKey = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
        thisObject.bobPrivateKey = "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
        thisObject.carolPrivateKey = "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"

        const getContractFunction = async function (contract_name) {
            thisObject[contract_name] = await ethers.getContractFactory(contract_name)
            thisObject[contract_name].thisObject = thisObject
            thisObject[contract_name].new = async function (name, ...params) {
                let newContract = await thisObject[contract_name].deploy(...params)
                await newContract.deployed()
                newContract.factory = thisObject[contract_name]
                addContract(thisObject, name, newContract)
                return newContract
            }
            return thisObject[contract_name]
        }

        const deployFunction = async function (var_name, contract_name, ...params) {
            await getContractFunction(contract_name)
            const contract = await thisObject[contract_name].new(var_name, ...params)
            return contract
        }

        const cmd = {
            getContract: getContractFunction,
            deploy: deployFunction,
            addToken: async function (var_name, name, symbol, decimals, tokenClassName) {
                tokenClassName = tokenClassName || "ReturnFalseERC20Mock"
                if (!thisObject[tokenClassName]) {
                    await getContractFunction(tokenClassName)
                }
                const token = await thisObject[tokenClassName].new(var_name, name, symbol, decimals, getBigNumber(1000000, decimals))
                await token.transfer(thisObject.bob.address, getBigNumber(1000, decimals))
                await token.transfer(thisObject.carol.address, getBigNumber(1000, decimals))
                await token.transfer(thisObject.fred.address, getBigNumber(1000, decimals))
                return token
            },
        }

        await stepsFunction(cmd)
        return cmd
    })
}

function decodeLogs(logs) {
    const decoded = []
    for (let i in logs) {
        const log = logs[i]
        let contract = contracts[log.address]
        if (contract) {
            let decodedLog = contract.interface.parseLog(log)
            const easyArgs = []
            for (var j in decodedLog.args) {
                if (!isNaN(j)) {
                    const arg = decodedLog.args[j]
                    //console.log(typeof arg, arg, arg.toString())
                    if (typeof arg == "string" && contracts[arg]) {
                        easyArgs.push("this." + contracts[arg].thisName + ".address")
                    } else {
                        easyArgs.push('"' + arg.toString() + '"')
                    }
                }
            }

            decoded.push({
                address: contract.address,
                name: decodedLog.name,
                args: easyArgs,
                contract: contract,
                contract_name: contract.thisName,
                raw: log,
                decoded: decodedLog,
            })
        } else {
            console.log("Cannot decode log")
        }
    }
    return decoded
}

function addr(address) {
    if (typeof address == "object" && address.address) {
        address = address.address
    }
    return address
}

module.exports = {
    ADDRESS_ZERO,
    addr,
    getDomainSeparator,
    getApprovalDigest,
    getApprovalMsg,
    getBentoBoxDomainSeparator,
    getBentoBoxApprovalDigest,
    getSignedMasterContractApprovalData,
    setMasterContractApproval,
    sansSafetyAmount,
    encodePrice,
    roundBN,
    advanceTime,
    advanceBlock,
    advanceTimeAndBlock,
    getBigNumber,
    decodeLogs,
    weth,
    createFixture,
}
