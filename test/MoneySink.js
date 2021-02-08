const { ADDRESS_ZERO, setMasterContractApproval, prepare, deploy, getBigNumber, advanceTime } = require("./utilities")
const { expect } = require("chai")
const { ethers } = require("hardhat")

describe("MoneySink", function () {
  before(async function () {
    await prepare(this, ["WETH9Mock", "RevertingERC20Mock", "MoneySink", "BentoBoxMock"])
    await deploy(this, [
      ["sushi", this.RevertingERC20Mock, ["SUSHI", "SUSHI", 18, getBigNumber("10000000")]],
      ["weth9", this.WETH9Mock],
    ])
    await deploy(this, [
      ["bentoBox", this.BentoBoxMock, [this.sushi.address]],
    ])
    await deploy(this, [["moneySink", this.MoneySink, [this.sushi.address]]])
    await this.moneySink.transferOwnership(this.bentoBox.address, true, false)
  })

  describe("allow to set Strategy", function () {
    it("allows to set strategy", async function () {
      await this.bentoBox.setStrategy(this.sushi.address, this.moneySink.address)
      expect(await this.bentoBox.pendingStrategy(this.sushi.address)).to.be.equal(this.moneySink.address)
      await advanceTime(1209600, ethers)
      await this.bentoBox.setStrategy(this.sushi.address, this.moneySink.address)
      expect(await this.bentoBox.strategy(this.sushi.address)).to.be.equal(this.moneySink.address)
    })

    it("allows to set target for Sushi", async function () {
      await this.bentoBox.setStrategyTargetPercentage(this.sushi.address, 80)
      expect((await this.bentoBox.strategyData(this.sushi.address)).targetPercentage).to.be.equal(80)
    })

    it("should rebalance the token", async function () {
      await this.sushi.approve(this.bentoBox.address, getBigNumber(10))
      await this.bentoBox.deposit(this.sushi.address, this.alice.address, this.alice.address, getBigNumber(10), 0)
      expect((await this.bentoBox.strategyData(this.sushi.address)).balance).to.be.equal(0)
      await expect(
        this.bentoBox.harvest(this.sushi.address, true, 0)
        ).to.emit(this.bentoBox, "LogStrategyInvest")
        .withArgs(this.sushi.address, getBigNumber(8))
      expect((await this.bentoBox.strategyData(this.sushi.address)).balance).to.be.equal(getBigNumber(8))
    })

    it("tracks loss from harvest correctly", async function () {
      expect((await this.bentoBox.totals(this.sushi.address)).elastic).to.equal("10000000000000000000")
      await expect(
        this.bentoBox.harvest(this.sushi.address, false, 0))
        .to.emit(this.bentoBox, "LogStrategyLoss")
        .withArgs(this.sushi.address, getBigNumber(8, 17))
      expect((await this.bentoBox.totals(this.sushi.address)).elastic).to.equal(getBigNumber(92,17))
    })

    it("switches to new strategy and exits from old", async function () {
      await deploy(this, [["moneySink2", this.MoneySink, [this.sushi.address]]])
      await this.bentoBox.setStrategy(this.sushi.address, this.moneySink2.address)
      await advanceTime(1209600, ethers)
      await this.bentoBox.setStrategy(this.sushi.address, this.moneySink2.address)
      expect(await this.sushi.balanceOf(this.bentoBox.address)).to.be.equal(getBigNumber(84,17))
      expect((await this.bentoBox.totals(this.sushi.address)).elastic).to.be.equal(getBigNumber(84,17))
    })

  
    it("holds correct asset after withdraw and harvest from BentoBox", async function () {
      await this.moneySink2.transferOwnership(this.bentoBox.address, true, false)
      expect((await this.bentoBox.strategyData(this.sushi.address)).balance).to.be.equal(0)
      await this.bentoBox.harvest(this.sushi.address, true, 0)
      await this.bentoBox.withdraw(this.sushi.address, this.alice.address, this.alice.address, getBigNumber(1,17), 0)
      expect((await this.bentoBox.strategyData(this.sushi.address)).balance).to.be.equal(getBigNumber(672, 16))
      await this.bentoBox.harvest(this.sushi.address, false, 0)
      expect(await this.sushi.balanceOf(this.bentoBox.address)).to.be.equal(getBigNumber(158, 16))
      expect((await this.bentoBox.strategyData(this.sushi.address)).balance).to.be.equal(getBigNumber(6048, 15))
      expect((await this.bentoBox.totals(this.sushi.address)).elastic).to.be.equal(getBigNumber(7628, 15))
    })
  })
})
