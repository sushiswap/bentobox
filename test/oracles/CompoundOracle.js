const { expect } = require("chai")
const { getBigNumber, prepare, ADDRESS_ZERO } = require("../utilities")

describe("Compound Oracle", function () {
    before(async function () {
        await prepare(this, ["CompoundOracle"])
    })

    beforeEach(async function () {
        this.oracle = await this.CompoundOracle.deploy()
        await this.oracle.deployed()
        this.oracleData = await this.oracle.getDataParameter("DAI", "ETH", getBigNumber(1))
    })

    it("Assigns name to Compound", async function () {
        expect(await this.oracle.name(this.oracleData)).to.equal("Compound")
    })

    it("Assigns symbol to COMP", async function () {
        expect(await this.oracle.symbol(this.oracleData)).to.equal("COMP")
    })

    if (!hre.network.config.forking) {
        console.trace("*** chain forking not available, skipping tests ***");
        return;
    }

    it("should return ETH Price in USD on rate request", async function () {
        await this.oracle.get(this.oracleData)
        const [success, rate] = await this.oracle.peek(this.oracleData)
        expect(success).to.be.true
        expect(rate).to.be.equal("1706297776996748967577")
    })
})
