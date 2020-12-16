const { expect } = require("chai")
const { e18 } = require("../utilities")

describe("PeggedOracle", function () {
  before(async function () {
    this.PeggedOracle = await ethers.getContractFactory("PeggedOracle")
  })

  beforeEach(async function () {
    this.oracle = await this.PeggedOracle.deploy()
    await this.oracle.deployed()
    this.oracleData = await this.oracle.getDataParameter(e18(1))
  })

<<<<<<< HEAD
  it("should return 1e18 on rate request", async function () {
    let result = await this.oracle.peek(this.oracleData)
    expect(result[1]).to.be.equal(e18(1))
=======
  it("Assigns name to Pegged", async function () {
    expect(await this.oracle.name(this.oracleData)).to.equal("Pegged")
  })

  it("Assigns symbol to PEG", async function () {
    expect(await this.oracle.symbol(this.oracleData)).to.equal("PEG")
  })

  it("should return 1e18 on rate request", async function () {
    const [success, rate] = await this.oracle.peek(this.oracleData)
    expect(success).to.be.true
    expect(rate).to.be.equal(e18(1))
>>>>>>> 7c914e831bc36643185f55c407a31278d63bab26
  })
})
