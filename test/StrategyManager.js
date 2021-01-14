const { ADDRESS_ZERO, setMasterContractApproval, prepare, deploy, getBigNumber, advanceTime } = require("./utilities")
const { expect } = require("chai")
const { ethers } = require("hardhat")

describe("StrategyManager", function () {
  before(async function () {
    await prepare(this, ["StrategyManagerMock","RevertingERC20Mock","SushiStrategy", "SushiBarMock", "BentoBoxPlus"])
    await deploy(this, 
      [ 
      ['sushi', this.RevertingERC20Mock,  ["SUSHI", "SUSHI", getBigNumber("10000000")]],
      ])
      await deploy(this, [['bentoBox', this.BentoBoxPlus, [this.sushi.address]],['bar', this.SushiBarMock, [this.sushi.address]]])
      await deploy(this, [['sushiStrategy', this.SushiStrategy, [this.bar.address, this.sushi.address]]])
      await this.sushiStrategy.transferOwnership(this.bentoBox.address, true, false)
      await this.sushi.approve(this.bar.address, getBigNumber(1))
      await this.bar.enter(getBigNumber(1))
  })

  describe("allow to set Strategy", function () {
    it("allows to set strategy", async function(){
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

    it("should rebalance the token", async function (){
      await this.sushi.approve(this.bentoBox.address, getBigNumber(10))
      await this.bentoBox.deposit(this.sushi.address, this.alice.address, this.alice.address, getBigNumber(10), 0)
      expect((await this.bentoBox.strategyData(this.sushi.address)).balance).to.be.equal(0)
      await this.bentoBox.harvest(this.sushi.address, true)
      expect((await this.bentoBox.strategyData(this.sushi.address)).balance).to.be.equal(getBigNumber(8))
    })

    it("rebalances correctly after SushiBar makes money", async function (){
      await this.sushi.transfer(this.bar.address, getBigNumber(10))
      await this.bentoBox.harvest(this.sushi.address, true)
      expect((await this.bentoBox.strategyData(this.sushi.address)).balance).to.be.equal("15111111111111111112")
      expect(await this.sushi.balanceOf(this.bentoBox.address)).to.be.equal("3777777777777777778")
    })

    it("switches to new strategy and exits from old", async function (){
      await deploy(this, [['sushiStrategy2', this.SushiStrategy, [this.bar.address, this.sushi.address]]])
      await this.bentoBox.setStrategy(this.sushi.address, this.sushiStrategy2.address)
      await advanceTime(1209600, ethers)
      await this.bentoBox.setStrategy(this.sushi.address, this.sushiStrategy2.address)
      expect(await this.sushi.balanceOf(this.bentoBox.address)).to.be.equal("18888888888888888890")
    })
    
  })

})
