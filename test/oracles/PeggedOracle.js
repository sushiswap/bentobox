const { expect } = require("chai")
const { getBigNumber, prepare } = require("../utilities")

describe("PeggedOracle", function () {
  before(async function () {
    await prepare(this, ["PeggedOracle"])
  })

  beforeEach(async function () {
    this.oracle = await this.PeggedOracle.deploy()
    await this.oracle.deployed()
    this.oracleData = await this.oracle.getDataParameter(getBigNumber(1))
  })

  it("Assigns name to Pegged", async function () {
    expect(await this.oracle.name(this.oracleData)).to.equal("Pegged")
  })

  it("Assigns symbol to PEG", async function () {
    expect(await this.oracle.symbol(this.oracleData)).to.equal("PEG")
  })

  it("should return 1e18 on rate request", async function () {
    const [success, rate] = await this.oracle.peek(this.oracleData)
    expect(success).to.be.true
    expect(rate).to.be.equal(getBigNumber(1))
  })
})
