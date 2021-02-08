const { ethers } = require("hardhat")
const assert = require("assert")
const { getBigNumber, advanceTime, prepare, setMasterContractApproval, deploymentsFixture } = require("../utilities")
const { LendingPair } = require("../utilities/lendingpair")

async function depositHelper(bentoBox, token, wallet, amount) {
    await bentoBox.deposit(token.address, wallet.address, wallet.address, getBigNumber(amount, await token.decimals()), 0)
}

async function withdrawHelper(bentoBox, token, wallet, amount) {
    await bentoBox.withdraw(token.address, wallet.address, wallet.address, getBigNumber(amount, await token.decimals()), 0)
}

describe("Harvest with DummyStrategyMock", function () {
    const APPROVAL_AMOUNT = 1000000
    const DEPOSIT_AMOUNT = 1000
    let strategyBalance = 0

    before(async function () {
        await prepare(this, ["ReturnFalseERC20Mock", "DummyStrategyMock"])
    })

    it("Setup", async function () {
        await deploymentsFixture(this, async (cmd) => {
            await cmd.addToken("tokenA", "Token A", "A", 18, this.ReturnFalseERC20Mock)
        })

        await this.DummyStrategyMock.new("dummyStrategy", this.bentoBox.address, this.tokenA.address)
        await this.tokenA.approve(this.bentoBox.address, getBigNumber(APPROVAL_AMOUNT, await this.tokenA.decimals()))
    })

    it("should allow adding of balances to the BentoBox", async function () {
        await depositHelper(this.bentoBox, this.tokenA, this.alice, DEPOSIT_AMOUNT)
    })

    it("check balances of BentoBox", async function () {
        assert.equal(
            (await this.bentoBox.balanceOf(this.tokenA.address, this.alice.address)).toString(),
            getBigNumber(DEPOSIT_AMOUNT, await this.tokenA.decimals()).toString(),
            "should match deposit amount"
        )

        assert.equal(
            (await this.tokenA.balanceOf(this.bentoBox.address)).toString(),
            getBigNumber(DEPOSIT_AMOUNT, await this.tokenA.decimals()).toString(),
            "should match deposit amount"
        )
    })

    it("set harvest profit on strategy mock", async function () {
        await this.dummyStrategy.setHarvestProfit(DEPOSIT_AMOUNT)
    })

    it("harvest without strategy set - revert", async function () {
        await assert.rejects(this.bentoBox.harvest(this.tokenA.address, true, 0))
    })

    it("set strategy and target percentage", async function () {
        await this.bentoBox.setStrategy(this.tokenA.address, this.dummyStrategy.address)
        await advanceTime(1209600, ethers)
        await this.bentoBox.setStrategy(this.tokenA.address, this.dummyStrategy.address)

        await this.bentoBox.setStrategyTargetPercentage(this.tokenA.address, 95)
    })

    it("harvest", async function () {
        await this.bentoBox.harvest(this.tokenA.address, true, 1)
        strategyBalance++
    })

    it("set harvest profit on strategy mock to zero", async function () {
        await this.dummyStrategy.setHarvestProfit(0)
    })

    it("harvest", async function () {
        await this.bentoBox.harvest(this.tokenA.address, true, 1)
        strategyBalance++
    })

    it("check balance of dummy strategy contract", async function () {
        assert.equal(
            (await this.tokenA.balanceOf(this.dummyStrategy.address)).toString(),
            strategyBalance.toString(),
            "should match DEPOSIT_AMOUNT - (2x profit drain)"
        )
    })

    it("set harvest profit on strategy mock negative", async function () {
        await this.dummyStrategy.setHarvestProfit(-DEPOSIT_AMOUNT)
    })

    it("set strategy percentage to zero", async function () {
        await this.bentoBox.setStrategyTargetPercentage(this.tokenA.address, 0)
    })

    it("harvest", async function () {
        await this.bentoBox.harvest(this.tokenA.address, true, 1)
    })

    it("set target percentage positive and set re-apply strategy contract", async function () {
        await this.dummyStrategy.setHarvestProfit(DEPOSIT_AMOUNT)
        await this.bentoBox.setStrategy(this.tokenA.address, this.dummyStrategy.address)
        await advanceTime(1209600, ethers)
        await this.bentoBox.setStrategy(this.tokenA.address, this.dummyStrategy.address)
    })

    it("harvest", async function () {
        await this.bentoBox.harvest(this.tokenA.address, true, 1)
    })

    it("should allow withdraw from BentoBox", async function () {
        await withdrawHelper(this.bentoBox, this.tokenA, this.alice, DEPOSIT_AMOUNT - strategyBalance)
    })

    it("harvest", async function () {
        await this.bentoBox.harvest(this.tokenA.address, true, 1)
    })
})
