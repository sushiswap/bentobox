const { ADDRESS_ZERO, addr, getBigNumber } = require(".")
const ethers = require('ethers')

const ERC20abi = [{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"_owner","type":"address"},{"indexed":true,"internalType":"address","name":"_spender","type":"address"},{"indexed":false,"internalType":"uint256","name":"_value","type":"uint256"}],"name":"Approval","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"_from","type":"address"},{"indexed":true,"internalType":"address","name":"_to","type":"address"},{"indexed":false,"internalType":"uint256","name":"_value","type":"uint256"}],"name":"Transfer","type":"event"},{"inputs":[],"name":"DOMAIN_SEPARATOR","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"","type":"address"},{"internalType":"address","name":"","type":"address"}],"name":"allowance","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"spender","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"approve","outputs":[{"internalType":"bool","name":"success","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"","type":"address"}],"name":"balanceOf","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"","type":"address"}],"name":"nonces","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"owner_","type":"address"},{"internalType":"address","name":"spender","type":"address"},{"internalType":"uint256","name":"value","type":"uint256"},{"internalType":"uint256","name":"deadline","type":"uint256"},{"internalType":"uint8","name":"v","type":"uint8"},{"internalType":"bytes32","name":"r","type":"bytes32"},{"internalType":"bytes32","name":"s","type":"bytes32"}],"name":"permit","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"transfer","outputs":[{"internalType":"bool","name":"success","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"from","type":"address"},{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"transferFrom","outputs":[{"internalType":"bool","name":"success","type":"bool"}],"stateMutability":"nonpayable","type":"function"}]

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
                console.log("RUN CMD: ", commands[i].method, commands[i].params)
                await this.sync();
                await commands[i].pair[commands[i].method](...commands[i].params);
            } else if (typeof(commands[i]) == "object" && commands[i].type == "LendingPairDo") {
                console.log("RUN DO: ", commands[i].method, commands[i].params)
                await commands[i].method(...commands[i].params);
            } else {
                console.log("RUN: ", commands[i])
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
        let share = this.info.totalCollateralAmount == 0 ? amount : amount.mul(this.info.totalCollateralShare).div(this.info.totalCollateralAmount);
        return this.contract.batch(
            [this.contract.interface.encodeFunctionData("deposit", [this.collateral.address, addr(this.contract.signer), amount, 0]),
            this.contract.interface.encodeFunctionData("addCollateral", [share, addr(this.contract.signer), false])], true
        );
    }

    withdrawCollateral(share) {
        return this.contract.batch(
            [
                this.contract.interface.encodeFunctionData("removeCollateral", [share, addr(this.contract.signer)]),
                this.contract.interface.encodeFunctionData("withdraw", [this.collateral.address, addr(this.contract.signer), 0, share])
            ], true
        );
    }

    depositAsset(amount) {
        let share = this.info.totalAssetAmount == 0 ? amount : amount.mul(this.info.totalAssetShare).div(this.info.totalAssetAmount);
        return this.contract.batch(
            [this.contract.interface.encodeFunctionData("deposit", [this.asset.address, addr(this.contract.signer), amount, 0]),
            this.contract.interface.encodeFunctionData("addAsset", [share, addr(this.contract.signer), false])], true
        );
    }

    withdrawAsset(fraction) {
        let share = this.info.pairAssetFraction == 0 ? fraction : fraction.mul(this.info.pairAssetShare).div(this.info.pairAssetFraction);
        return this.contract.batch(
            [
                this.contract.interface.encodeFunctionData("removeAsset", [fraction, addr(this.contract.signer)]),
                this.contract.interface.encodeFunctionData("withdraw", [this.asset.address, addr(this.contract.signer), 0, share])
            ], true
        );
    }

    repay(part) {
        let amount = this.info.pairBorrowPart == 0 ? part : part.mul(this.info.pairBorrowAmount).div(this.info.pairBorrowPart)
        return this.contract.batch(
            [this.contract.interface.encodeFunctionData("deposit", [this.asset.address, addr(this.contract.signer), 0, amount]),
            this.contract.interface.encodeFunctionData("repay", [part, addr(this.contract.signer), false])], true
        );
    }

    borrow(amount) {
        /*let amount = this.info.pairBorrowPart == 0 ? part : part.mul(this.info.pairBorrowAmount).div(this.info.pairBorrowPart)
        return this.contract.batch(
            [this.contract.interface.encodeFunctionData("deposit", [this.asset.address, addr(this.contract.signer), 0, amount]),
            this.contract.interface.encodeFunctionData("repay", [part, addr(this.contract.signer), false])], true
        );*/
    }
}

Object.defineProperty(LendingPair.prototype, "cmd", {
    get: function () {
        return new Proxy(this, {
            get: function (target, method) {
                return function(...params) {
                    if (method == "do") {
                        return {
                            type: "LendingPairDo",
                            method: params[0],
                            params: params.slice(1)         
                        }
                    }
                    return {
                        type: "LendingPairCmd",
                        pair: target,
                        method: method,
                        params: params
                    }
                }
            }
        });
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
    await pairHelper.init(bentoBox);
    return pairHelper;
}

module.exports = {
    LendingPair
}