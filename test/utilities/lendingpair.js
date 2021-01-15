const { ADDRESS_ZERO, addr } = require(".")

class LendingPair {
    constructor(contract) {
        this.contract = contract;
    }

    async init(bentoBox) {
        this.bentoBox = bentoBox;
        this.asset = await this.contract.asset();
        this.collateral = await this.contract.collateral();
    }

    as(from) {
        return new LendingPair(this.contract.connect(from));
    }

    async depositCollateral(user, amount) {
        let share = await this.bentoBox.toShare(this.collateral, amount)
        return this.contract.batch(
            [this.contract.interface.encodeFunctionData("deposit", [this.collateral, addr(user), amount, 0]),
            this.contract.interface.encodeFunctionData("addCollateral", [share, addr(user), false])], false
        );
    }

    async removeCollateral(user, share) {
        return this.contract.batch(
            [
                this.contract.interface.encodeFunctionData("removeCollateral", [share, addr(user)]),
                this.contract.interface.encodeFunctionData("withdraw", [this.collateral, addr(user), 0, share])
            ], false
        );
    }

    async addAsset(user, amount) {
        let share = await this.bentoBox.toShare(this.asset, amount)
        return this.contract.batch(
            [this.contract.interface.encodeFunctionData("deposit", [this.asset, addr(user), amount, 0]),
            this.contract.interface.encodeFunctionData("addAsset", [share, addr(user), false])], false
        );
    }

    async removeAsset(user, fraction) {
        return this.contract.batch(
            [
                this.contract.interface.encodeFunctionData("removeAsset", [fraction, addr(user)]),
                this.contract.interface.encodeFunctionData("withdraw", [this.collateral, addr(user), 0, share])
            ], false
        );
    }

    async repay(part, user) {
        let amount = part.mul((await this.contract.totalBorrow()).elastic).div((await this.contract.totalBorrow()).base)
        return this.contract.batch(
            [this.contract.interface.encodeFunctionData("deposit", [this.asset, addr(user), 0, amount]),
            this.contract.interface.encodeFunctionData("repay", [part, addr(user), false])], false
        );
    }

    async borrow(amount, to) {

    }
}

module.exports = {
    LendingPair
}