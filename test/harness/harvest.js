const assert = require("assert")
const { ethers } = require("hardhat")
const { getBigNumber, advanceTime, setMasterContractApproval, createFixture } = require("../utilities")

async function depositHelper(bentoBox, token, wallet, amount) {
    await bentoBox.deposit(token.address, wallet.address, wallet.address, getBigNumber(amount, await token.decimals()), 0)
}

async function withdrawHelper(bentoBox, token, wallet, amount) {
    await bentoBox.withdraw(token.address, wallet.address, wallet.address, getBigNumber(amount, await token.decimals()), 0)
}

describe("DummyStrategyMock", function () {
    const APPROVAL_AMOUNT = 1000000
    const DEPOSIT_AMOUNT = 1000
    const HARVEST_MAX_AMOUNT = 3

    before(async function () {
        fixture = await createFixture(deployments, this, async (cmd) => {
            await cmd.deploy("weth9", "WETH9Mock")
            await cmd.deploy("bentoBox", "BentoBoxMock", this.weth9.address)

            await cmd.addToken("tokenA", "Token A", "A", 18, this.ReturnFalseERC20Mock)
            await cmd.deploy("dummyStrategy", "DummyStrategyMock", this.bentoBox.address, this.tokenA.address)
            await this.tokenA.approve(this.bentoBox.address, getBigNumber(APPROVAL_AMOUNT, await this.tokenA.decimals()))
        })
        cmd = await fixture()
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

    it("set harvest profit on strategy mock to zero", async function () {
        await this.dummyStrategy.setHarvestProfit(0)
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
        await this.bentoBox.harvest(this.tokenA.address, true, HARVEST_MAX_AMOUNT)
    })

    it("set harvest profit on strategy mock positive", async function () {
        await this.dummyStrategy.setHarvestProfit(DEPOSIT_AMOUNT)
    })

    it("harvest profit", async function () {
        await this.bentoBox.harvest(this.tokenA.address, true, HARVEST_MAX_AMOUNT)
    })

    it("harvest profit 2", async function () {
        await this.bentoBox.harvest(this.tokenA.address, true, HARVEST_MAX_AMOUNT)
    })

    it("check balance of dummy strategy contract", async function () {
        assert.equal(
            (await this.bentoBox.strategyData(this.tokenA.address)).balance.toString(),
            (HARVEST_MAX_AMOUNT * 3).toString(),
            "should match"
        )
    })

    it("set harvest profit on strategy mock negative", async function () {
        await this.dummyStrategy.setHarvestProfit(-DEPOSIT_AMOUNT)
    })

    it("set strategy percentage to zero", async function () {
        await this.bentoBox.setStrategyTargetPercentage(this.tokenA.address, 0)
    })

    it("harvest 2", async function () {
        await this.bentoBox.harvest(this.tokenA.address, true, HARVEST_MAX_AMOUNT)
    })

    it("set target percentage positive and set re-apply strategy contract", async function () {
        await this.dummyStrategy.setHarvestProfit(DEPOSIT_AMOUNT)
        await this.bentoBox.setStrategy(this.tokenA.address, this.dummyStrategy.address)
        await advanceTime(1209600, ethers)
        await this.bentoBox.setStrategy(this.tokenA.address, this.dummyStrategy.address)
    })

    it("harvest 3", async function () {
        await this.bentoBox.harvest(this.tokenA.address, true, HARVEST_MAX_AMOUNT)
    })

    it("should allow withdraw original deposit amount from BentoBox", async function () {
        await withdrawHelper(this.bentoBox, this.tokenA, this.alice, DEPOSIT_AMOUNT)
    })

    it("harvest 4", async function () {
        await this.bentoBox.harvest(this.tokenA.address, true, HARVEST_MAX_AMOUNT)
    })

    it("check token balances of contracts", async function () {
        assert.equal((await this.tokenA.balanceOf(this.bentoBox.address)).toString(), "0", "bentoBox")
        assert.equal((await this.tokenA.balanceOf(this.dummyStrategy.address)).toString(), "0", "dummyStrategy")
    })
})
