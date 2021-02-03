const { expect } = require("chai")
const { prepare, getBigNumber, deploymentsFixture } = require("../utilities")

// TODO: Can we test this in isolation?
describe("SushiSwapSwapper", function () {
  before(async function () {
    await prepare(this, ["SushiSwapSwapper", "ReturnFalseERC20Mock", "RevertingERC20Mock"])
  })

  beforeEach(async function () {
    await deploymentsFixture(this, async (cmd) => {
      await cmd.addToken("a", "Token A", "A", this.ReturnFalseERC20Mock)
      await cmd.addToken("b", "Token B", "B", this.RevertingERC20Mock)
      await cmd.addPair("sushiSwapPair", this.a, this.b, 50000, 50000)
    })

    this.swapper = await this.SushiSwapSwapper.deploy(this.bentoBox.address, this.factory.address)
    await this.swapper.deployed()
  })

  describe("Swap", function () {
    it("should swap", async function () {
      await this.a.approve(this.bentoBox.address, getBigNumber(100))
      await this.bentoBox.deposit(this.a.address, this.alice.address, this.alice.address, getBigNumber(100), 0)
      await this.bentoBox.transfer(this.a.address, this.alice.address, this.swapper.address, getBigNumber(20))
      await this.swapper.swap(this.a.address, this.b.address, this.alice.address, 0, getBigNumber(20))
    })

    it("should swap in opposite direction", async function () {
      await this.b.approve(this.bentoBox.address, getBigNumber(100))
      await this.bentoBox.deposit(this.b.address, this.alice.address, this.alice.address, getBigNumber(100), 0)
      await this.bentoBox.transfer(this.b.address, this.alice.address, this.swapper.address, getBigNumber(20))
      await this.swapper.swap(this.b.address, this.a.address, this.alice.address, 0, getBigNumber(20))
    })
  })

  describe("Swap Exact", function () {
    it("should swap exact", async function () {
      await this.a.approve(this.bentoBox.address, getBigNumber(100))
      await this.bentoBox.deposit(this.a.address, this.alice.address, this.alice.address, getBigNumber(100), 0)
      await this.bentoBox.transfer(this.a.address, this.alice.address, this.swapper.address, getBigNumber(30))
      await this.swapper.swapExact(this.a.address, this.b.address, this.alice.address, this.bob.address, getBigNumber(30), getBigNumber(20))
    })

    it("should swap exact in opposite direction", async function () {
      await this.b.approve(this.bentoBox.address, getBigNumber(100))
      await this.bentoBox.deposit(this.b.address, this.alice.address, this.alice.address, getBigNumber(100), 0)
      await this.bentoBox.transfer(this.b.address, this.alice.address, this.swapper.address, getBigNumber(30))
      await this.swapper.swapExact(this.b.address, this.a.address, this.alice.address, this.bob.address, getBigNumber(30), getBigNumber(20))
    })
  })
})
