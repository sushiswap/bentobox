const { expect } = require("chai")
const { e18 } = require("../utilities")

describe("PeggedOracle", function () {
    before(async function () {
  
      this.PeggedOracle = await ethers.getContractFactory("PeggedOracle")
  
    })
  
    beforeEach(async function () {
      this.oracle = await this.PeggedOracle.deploy()
      await this.oracle.deployed()
      this.oracleData = await this.oracle.getDataParameter(e18(1));
    })

    it("should return 1e18 on rate request", async function() {
        let result = await this.oracle.peek(this.oracleData)
        expect(result[1]).to.be.equal(e18(1))
    })
})