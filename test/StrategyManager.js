const { ADDRESS_ZERO, setMasterContractApproval, createFixture, getBigNumber, advanceTime } = require("./utilities")
const { expect } = require("chai")
const { ethers } = require("hardhat")

let cmd, fixture

describe("StrategyManager", function () {
    before(async function () {
        fixture = await createFixture(deployments, this, async (cmd) => {
            await cmd.deploy("sushi", "RevertingERC20Mock", "SUSHI", "SUSHI", 18, getBigNumber("10000000"))
            await cmd.deploy("weth9", "WETH9Mock")
            await cmd.deploy("bentoBox", "BentoBoxMock", this.weth9.address)
            await cmd.deploy("bar", "SushiBarMock", this.sushi.address)
            await cmd.deploy("sushiStrategy", "SushiStrategy", this.bar.address, this.sushi.address)
            await this.sushiStrategy.transferOwnership(this.bentoBox.address, true, false)
            await this.sushi.approve(this.bar.address, getBigNumber(1))
            await this.bar.enter(getBigNumber(1))
        })
        cmd = await fixture()
    })

    describe("Strategy", function () {
        it("allows to set strategy", async function () {
            await this.bentoBox.setStrategy(this.sushi.address, this.sushiStrategy.address)
            expect(await this.bentoBox.pendingStrategy(this.sushi.address)).to.be.equal(this.sushiStrategy.address)
            await advanceTime(1209600, ethers)
            await this.bentoBox.setStrategy(this.sushi.address, this.sushiStrategy.address)
            expect(await this.bentoBox.strategy(this.sushi.address)).to.be.equal(this.sushiStrategy.address)
        })

        it("allows to set target for Sushi", async function () {
            await this.bentoBox.setStrategyTargetPercentage(this.sushi.address, 80)
            expect((await this.bentoBox.strategyData(this.sushi.address)).targetPercentage).to.be.equal(80)
        })

        it("reverts if target is too high", async function () {
            await expect(this.bentoBox.setStrategyTargetPercentage(this.sushi.address, 96)).to.be.revertedWith(
                "StrategyManager: Target too high"
            )
        })

        it("should rebalance the token", async function () {
            await this.sushi.approve(this.bentoBox.address, getBigNumber(10))
            await this.bentoBox.deposit(this.sushi.address, this.alice.address, this.alice.address, getBigNumber(10), 0)
            expect((await this.bentoBox.strategyData(this.sushi.address)).balance).to.be.equal(0)
            await this.bentoBox.harvest(this.sushi.address, true, 0)
            expect((await this.bentoBox.strategyData(this.sushi.address)).balance).to.be.equal(getBigNumber(8))
        })

        it("allows harvest of 0 when there's nothing to harvest", async function () {
            expect((await this.bentoBox.totals(this.sushi.address)).elastic).to.equal("10000000000000000000")
            await this.bentoBox.harvest(this.sushi.address, false, 0)
            expect((await this.bentoBox.totals(this.sushi.address)).elastic).to.equal("10000000000000000000")
        })

        it("rebalances correctly after SushiBar makes money", async function () {
            await this.sushi.transfer(this.bar.address, getBigNumber(10))
            await this.bentoBox.harvest(this.sushi.address, true, 0)
            expect((await this.bentoBox.strategyData(this.sushi.address)).balance).to.be.equal("15111111111111111112")
            expect(await this.sushi.balanceOf(this.bentoBox.address)).to.be.equal("3777777777777777778")
        })

        it("switches to new strategy and exits from old", async function () {
            await cmd.deploy("sushiStrategy2", "SushiStrategy", this.bar.address, this.sushi.address)
            await this.bentoBox.setStrategy(this.sushi.address, this.sushiStrategy2.address)
            await advanceTime(1209600, ethers)
            await this.bentoBox.setStrategy(this.sushi.address, this.sushiStrategy2.address)
            expect(await this.sushi.balanceOf(this.bentoBox.address)).to.be.equal("18888888888888888888")
            expect((await this.bentoBox.totals(this.sushi.address)).elastic).to.be.equal("18888888888888888888")
        })

        it("SushiStrategy does not allow to draw a too high share", async function () {
            await this.sushiStrategy2.withdraw(getBigNumber(1))
        })

        it("rebalances correctly after a withdraw from BentoBox", async function () {
            await this.sushiStrategy2.transferOwnership(this.bentoBox.address, true, false)
            await this.bentoBox.harvest(this.sushi.address, true, 0)
            await this.bentoBox.withdraw(this.sushi.address, this.alice.address, this.alice.address, "3677777777777777778", 0)
            await this.bentoBox.harvest(this.sushi.address, true, 0)
            expect(await this.sushi.balanceOf(this.bentoBox.address)).to.be.equal("3042222222222222220")
            expect((await this.bentoBox.totals(this.sushi.address)).elastic).to.be.equal("15211111111111111110")
        })

        it("switches to new strategy and exits from old with profit", async function () {
            await this.sushi.transfer(this.bar.address, getBigNumber(1))
            await cmd.deploy("sushiStrategy3", "SushiStrategy", this.bar.address, this.sushi.address)
            await this.bentoBox.setStrategy(this.sushi.address, this.sushiStrategy3.address)
            await advanceTime(1209600, ethers)
            await this.bentoBox.setStrategy(this.sushi.address, this.sushiStrategy3.address)
            expect(await this.sushi.balanceOf(this.bentoBox.address)).to.be.equal("16063274198568316213")
            expect((await this.bentoBox.totals(this.sushi.address)).elastic).to.be.equal("16063274198568316213")
        })
    })
})
