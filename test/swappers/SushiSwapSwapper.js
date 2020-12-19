const { expect } = require("chai")
const { prepare } = require("../utilities")

// TODO: Can we test this in isolation?
describe("SushiSwapSwapper", function () {
  before(async function () {
    await prepare(this, ["SushiSwapSwapper"])
  })

  beforeEach(async function () {
    this.swapper = await this.SushiSwapSwapper.deploy()
    await this.swapper.deployed()
  })
})
