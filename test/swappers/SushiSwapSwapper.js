const { expect } = require("chai")

// TODO: Can we test this in isolation?
describe("SushiSwapSwapper", function () {
  before(async function () {
    this.SushiSwapSwapper = await ethers.getContractFactory("SushiSwapSwapper")
  })

  beforeEach(async function () {
    this.swapper = await this.SushiSwapSwapper.deploy()
    await this.swapper.deployed()
  })
})
