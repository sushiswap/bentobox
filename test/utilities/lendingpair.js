const { ADDRESS_ZERO, addr, getBigNumber } = require(".")
const {
    utils: { defaultAbiCoder},
  } = require("ethers")
const ethers = require('ethers')

const ERC20abi = [{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"_owner","type":"address"},{"indexed":true,"internalType":"address","name":"_spender","type":"address"},{"indexed":false,"internalType":"uint256","name":"_value","type":"uint256"}],"name":"Approval","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"_from","type":"address"},{"indexed":true,"internalType":"address","name":"_to","type":"address"},{"indexed":false,"internalType":"uint256","name":"_value","type":"uint256"}],"name":"Transfer","type":"event"},{"inputs":[],"name":"DOMAIN_SEPARATOR","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"","type":"address"},{"internalType":"address","name":"","type":"address"}],"name":"allowance","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"spender","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"approve","outputs":[{"internalType":"bool","name":"success","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"","type":"address"}],"name":"balanceOf","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"","type":"address"}],"name":"nonces","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"owner_","type":"address"},{"internalType":"address","name":"spender","type":"address"},{"internalType":"uint256","name":"value","type":"uint256"},{"internalType":"uint256","name":"deadline","type":"uint256"},{"internalType":"uint8","name":"v","type":"uint8"},{"internalType":"bytes32","name":"r","type":"bytes32"},{"internalType":"bytes32","name":"s","type":"bytes32"}],"name":"permit","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"transfer","outputs":[{"internalType":"bool","name":"success","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"from","type":"address"},{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"transferFrom","outputs":[{"internalType":"bool","name":"success","type":"bool"}],"stateMutability":"nonpayable","type":"function"}]

const ACTION_ADD_COLLATERAL = 1;
const ACTION_ADD_ASSET = 2;
const ACTION_REPAY = 3;
const ACTION_REMOVE_ASSET = 4;
const ACTION_REMOVE_COLLATERAL = 5;
const ACTION_BORROW = 6;
const ACTION_CALL = 10;
const ACTION_BENTO_DEPOSIT = 20;
const ACTION_BENTO_WITHDRAW = 21;
const ACTION_BENTO_TRANSFER = 22;
const ACTION_BENTO_TRANSFER_MULTIPLE = 23;
const ACTION_BENTO_SETAPPROVAL = 24;
const ACTION_GET_REPAY_SHARE = 30;

class LendingPair {
    constructor(contract, helper) {
        this.contract = contract;
        this.helper = helper;
    }

    async init(bentoBox) {
        this.bentoBox = bentoBox;
        this.asset = new ethers.Contract(await this.contract.asset(), ERC20abi, this.contract.signer)
        this.collateral = new ethers.Contract(await this.contract.collateral(), ERC20abi, this.contract.signer)
        await this.sync();
        return this;
    }

    as(from) {
        let connectedPair = new LendingPair(this.contract.connect(from));
        connectedPair.bentoBox = this.bentoBox.connect(from);
        connectedPair.helper = this.helper;
        connectedPair.asset = this.asset.connect(from);
        connectedPair.collateral = this.collateral.connect(from);

        return connectedPair;
    }

    async sync() {
        this.info = {
            totalAssetAmount: (await this.bentoBox.totals(this.asset.address)).elastic,
            totalAssetShare: (await this.bentoBox.totals(this.asset.address)).base,
            totalCollateralAmount: (await this.bentoBox.totals(this.collateral.address)).elastic,
            totalCollateralShare: (await this.bentoBox.totals(this.collateral.address)).base,
            pairAssetShare: (await this.contract.totalAsset()).elastic,
            pairAssetFraction: (await this.contract.totalAsset()).base,
            pairBorrowAmount: (await this.contract.totalBorrow()).elastic,
            pairBorrowPart: (await this.contract.totalBorrow()).base
        }
        return this;
    }

    async syncAs(from) {
        return this.as(from).sync();
    }

    async run(commandsFunction) {
        const commands = commandsFunction(this.cmd);
        for (let i=0; i < commands.length; i++) {
            if (typeof(commands[i]) == "object" && commands[i].type == "LendingPairCmd") {
                //console.log("RUN CMD: ", commands[i].method, commands[i].params, commands[i].as ? commands[i].as.address : "")
                let pair = commands[i].pair;
                if (commands[i].as) {
                    pair = await pair.as(commands[i].as);
                }
                await pair.sync();
                let tx = await pair[commands[i].method](...commands[i].params);
                let receipt = await tx.wait();
                console.log("Gas used: ", receipt.gasUsed.toString());
            } else if (typeof(commands[i]) == "object" && commands[i].type == "LendingPairDo") {
                //console.log("RUN DO: ", commands[i].method, commands[i].params)
                await commands[i].method(...commands[i].params);
            } else {
                //console.log("RUN: ", commands[i])
                await commands[i];
            }
        }
    }

    approveAsset(amount) {
        return this.asset.approve(this.bentoBox.address, amount)
    }
    
    approveCollateral(amount) {
        return this.collateral.approve(this.bentoBox.address, amount)
    }
    
    depositCollateral(amount) {
        return this.contract.cook( [ACTION_BENTO_DEPOSIT, ACTION_ADD_COLLATERAL], [0, 0], [defaultAbiCoder.encode(
            ["address", "address", "int256", "int256"],
            [this.collateral.address, addr(this.contract.signer), amount, 0]
          ), defaultAbiCoder.encode(
            ["int256", "address", "bool"],
            [-2, addr(this.contract.signer), false]
          ), ]
        );
    }

    withdrawCollateral(share) {
        return this.contract.cook([ACTION_REMOVE_COLLATERAL, ACTION_BENTO_WITHDRAW], [0, 0], [
                defaultAbiCoder.encode(["int256", "address"], [share, addr(this.contract.signer)]),
                defaultAbiCoder.encode(["address", "address", "int256", "int256"], [this.collateral.address, addr(this.contract.signer), 0, share])
            ]
        );
    }

    depositAsset(amount) {
        return this.contract.cook( [ACTION_BENTO_DEPOSIT, ACTION_ADD_ASSET], [0, 0], [defaultAbiCoder.encode(
            ["address", "address", "int256", "int256"],
            [this.asset.address, addr(this.contract.signer), amount, 0]
          ), defaultAbiCoder.encode(
            ["int256", "address", "bool"],
            [-2, addr(this.contract.signer), false]
          ), ]
        );
    }

    withdrawAsset(fraction) {
        return this.contract.cook(
            [ACTION_REMOVE_ASSET, ACTION_BENTO_WITHDRAW], [0, 0], [
                defaultAbiCoder.encode(
                    ["int256", "address"],
                    [fraction, addr(this.contract.signer)]
                  ),
                defaultAbiCoder.encode(
                ["address", "address", "int256", "int256"],
                [this.asset.address, addr(this.contract.signer), 0, -1]
              ),  ]
        );
    }

    repay(part) {
        return this.contract.cook( [ACTION_GET_REPAY_SHARE, ACTION_BENTO_DEPOSIT, ACTION_REPAY], [0, 0], [
            defaultAbiCoder.encode(["uint256"], [part]),
            defaultAbiCoder.encode(["address", "address", "int256", "int256"], [this.asset.address, addr(this.contract.signer), -1, 0]),
            defaultAbiCoder.encode(["int256", "address", "bool"], [part, addr(this.contract.signer), false])
        ]);
    }

    repayFromBento(part) {
        return this.contract.repay(addr(this.contract.signer), false, part)
    }

    borrow(amount) {
        return this.contract.cook( [ACTION_BORROW, ACTION_BENTO_WITHDRAW], [0, 0], [
            defaultAbiCoder.encode(["uint256", "address"], [amount, addr(this.contract.signer)]),
            defaultAbiCoder.encode(["address", "address", "int256", "int256"], [this.asset.address, addr(this.contract.signer), 0, -2])
        ])
    }

    short(swapper, part, minimumAmount) {
        let data = swapper.interface.encodeFunctionData("swap", [this.asset.address, this.collateral.address, addr(this.contract.signer), minimumAmount, "115792089237316195423570985008687907853269984665640564039457584007913129639935"]);
        console.log(data.slice(0, -64));
        return this.contract.cook( [ACTION_GET_REPAY_SHARE, ACTION_BORROW, ACTION_BENTO_TRANSFER, ACTION_CALL, ACTION_ADD_COLLATERAL], [0, 0], [
            defaultAbiCoder.encode(["uint256"], [part]),
            defaultAbiCoder.encode(["int256", "address"], [-1, addr(this.contract.signer)]),
            defaultAbiCoder.encode(["address", "address", "int256"], [this.asset.address, swapper.address, -2]),
            defaultAbiCoder.encode(["address", "bytes", "bool", "bool", "uint8"], [swapper.address, data.slice(0, -64), false, true, 2]),
            defaultAbiCoder.encode(["int256", "address", "bool"], [-2, addr(this.contract.signer), false]),
        ])
    }

    unwind(swapper, fraction, minimumAmount) {
        let data = swapper.interface.encodeFunctionData("swap", [this.collateral.address, this.asset.address, addr(this.contract.signer), minimumAmount, "115792089237316195423570985008687907853269984665640564039457584007913129639935"]);
        console.log(data.slice(0, -64));
        return this.contract.cook( [ACTION_REMOVE_COLLATERAL, ACTION_BENTO_TRANSFER, ACTION_CALL, ACTION_REPAY], [0, 0], [
            defaultAbiCoder.encode(["int256", "address"], [share, addr(this.contract.signer)]),
            defaultAbiCoder.encode(["address", "address", "int256"], [this.asset.address, swapper.address, -2]),
            defaultAbiCoder.encode(["int256", "address"], [-1, addr(this.contract.signer)]),
            defaultAbiCoder.encode(["int256", "address", "bool"], [part, addr(this.contract.signer), false])
        ])
    }

    accrue() {
        return this.contract.accrue();
    }

    updateExchangeRate() {
        return this.contract.updateExchangeRate();
    }
}

Object.defineProperty(LendingPair.prototype, "cmd", {
    get: function () {
        function proxy(pair, as) {
            return new Proxy(pair, {
                get: function (target, method) {
                    return function(...params) {
                        if (method == "do") {
                            return {
                                type: "LendingPairDo",
                                method: params[0],
                                params: params.slice(1)
                            }
                        }
                        if (method == "as") {
                            return proxy(pair, params[0]);
                        }
                        return {
                            type: "LendingPairCmd",
                            pair: target,
                            method: method,
                            params: params,
                            as: as
                        }
                    }
                }
            });
        }

        return proxy(this);
    }
});

LendingPair.deploy = async function(bentoBox, masterContract, masterContractClass, asset, collateral, oracle) {
    await oracle.set(getBigNumber(1))
    const oracleData = await oracle.getDataParameter()
    const initData = await masterContract.getInitData(addr(asset), addr(collateral), oracle.address, oracleData)
    const deployTx = await bentoBox.deploy(masterContract.address, initData)
    const cloneAddress = (await deployTx.wait()).events[1].args.cloneAddress
    const pair = await masterContractClass.attach(cloneAddress)
    const pairHelper = new LendingPair(pair);
    pairHelper.initData = initData;
    await pairHelper.init(bentoBox);
    return pairHelper;
}

module.exports = {
    LendingPair
}