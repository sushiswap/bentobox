const { expect } = require("chai")

describe("BentoHelper", function () {
  before(async function () {
    this.BentoHelper = await ethers.getContractFactory("BentoHelper")
  })

  beforeEach(async function () {
    this.swapper = await this.BentoHelper.deploy()
    await this.swapper.deployed()
  })
})
