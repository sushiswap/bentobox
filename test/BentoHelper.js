const { expect } = require("chai")
const { prepare } = require("./utilities")

describe("BentoHelper", function () {
  before(async function () {
    await prepare(this, ["BentoHelper"])
  })

  beforeEach(async function () {
    this.swapper = await this.BentoHelper.deploy()
    await this.swapper.deployed()
  })
})
