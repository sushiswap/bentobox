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

    async addAsset(user, amount) {
        let share = await this.bentoBox.toShare(this.asset, amount)
        return this.contract.batch(
            [this.contract.interface.encodeFunctionData("deposit", [this.asset, addr(user), amount, 0]),
            this.contract.interface.encodeFunctionData("addAsset", [share, addr(user), false])], false
        );
    }

    async addCollateral(user, amount) {
        let share = await this.bentoBox.toShare(this.collateral, amount)
        return this.contract.batch(
            [this.contract.interface.encodeFunctionData("deposit", [this.collateral, addr(user), amount, 0]),
            this.contract.interface.encodeFunctionData("addCollateral", [share, addr(user), false])], false
        );
    }

    async borrow(amount, to) {

    }
}

module.exports = {
    LendingPair
}