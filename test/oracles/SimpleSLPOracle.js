const { ethers } = require("hardhat")
const { expect } = require("chai")
const { getBigNumber, roundBN, encodePrice, advanceTime, advanceTimeAndBlock, deploymentsFixture, prepare } = require("../utilities")

describe("SimpleSLPOracle", function () {
  before(async function () {
    await prepare(this, [
      "WETH9Mock",
      "BentoBoxPlus",
      "UniswapV2Pair",
      "UniswapV2Factory",
      "ReturnFalseERC20Mock",
      "RevertingERC20Mock",
      "SimpleSLPTWAP0Oracle",
      "SimpleSLPTWAP1Oracle",
    ])
  })

  beforeEach(async function () {
    await deploymentsFixture(this, async (cmd) => {
      await cmd.addToken("collateral", "Collateral", "C", this.ReturnFalseERC20Mock)
      await cmd.addToken("asset", "Asset", "A", this.RevertingERC20Mock)
      await cmd.addPair("sushiSwapPair", this.collateral, this.asset, 5, 10)
    })

    this.expectedPrice = encodePrice(getBigNumber(5), getBigNumber(10))

    if (this.asset.address == (await this.sushiSwapPair.token0())) {
      this.oracleF = await this.SimpleSLPTWAP0Oracle.deploy()
      this.oracleB = await this.SimpleSLPTWAP1Oracle.deploy()
    } else {
      this.oracleF = await this.SimpleSLPTWAP1Oracle.deploy()
      this.oracleB = await this.SimpleSLPTWAP0Oracle.deploy()
    }
    await this.oracleF.deployed()
    await this.oracleB.deployed()
    this.oracleData = await this.oracleF.getDataParameter(this.sushiSwapPair.address)
  })

  describe("forward oracle", function () {
    describe("name", function () {
      it("should get name", async function () {
        expect(await this.oracleF.name(this.oracleData)).to.be.equal("SushiSwap TWAP")
      })
    })

    describe("symbol", function () {
      it("should get symbol", async function () {
        expect(await this.oracleF.symbol(this.oracleData)).to.be.equal("S")
      })
    })

    describe("peek", function () {
      it("should return false on first peek", async function () {
        expect((await this.oracleF.peek(this.oracleData))[1]).to.equal("0")
      })

      it("should get price even when time since last update is longer than period", async function () {
        const blockTimestamp = (await this.sushiSwapPair.getReserves())[2]

        await this.oracleF.get(this.oracleData)
        await this.oracleB.get(this.oracleData)
        await advanceTime(30, ethers)
        await this.oracleF.get(this.oracleData)
        await this.oracleB.get(this.oracleData)
        await advanceTime(271, ethers)
        await this.oracleF.get(this.oracleData)
        await this.oracleB.get(this.oracleData)

        let info = (await this.oracleF.pairs(this.sushiSwapPair.address)).priceAverage.toString()
        expect(info).to.be.equal(this.expectedPrice[1].toString())

        await advanceTimeAndBlock(301, ethers)

        expect((await this.oracleF.peek(this.oracleData))[1]).to.be.equal(getBigNumber(1).mul(5).div(10))
        await this.oracleB.peek(this.oracleData)
      })
    })

    describe("get", function () {
      it("should update and get prices within period", async function () {
        const blockTimestamp = (await this.sushiSwapPair.getReserves())[2]

        await this.oracleF.get(this.oracleData)
        await this.oracleB.get(this.oracleData)
        await advanceTime(30, ethers)
        await this.oracleF.get(this.oracleData)
        await this.oracleB.get(this.oracleData)
        await advanceTime(271, ethers)
        await this.oracleB.get(this.oracleData)
        await this.oracleB.get(this.oracleData)
        await this.oracleF.get(this.oracleData)
        await this.oracleF.get(this.oracleData)

        let info = (await this.oracleF.pairs(this.sushiSwapPair.address)).priceAverage.toString()

        expect(info).to.be.equal(this.expectedPrice[1].toString())
        expect((await this.oracleF.peek(this.oracleData))[1]).to.be.equal(getBigNumber(1).mul(5).div(10))
        await this.oracleB.peek(this.oracleData)
      })

      it("should update prices after swap", async function () {
        const blockTimestamp = (await this.sushiSwapPair.getReserves())[2]
        await this.oracleF.get(this.oracleData)
        await advanceTime(301, ethers)
        await this.oracleF.get(this.oracleData)

        const price0 = (await this.oracleF.peek(this.oracleData))[1]
        await this.collateral.transfer(this.sushiSwapPair.address, getBigNumber(5))
        await advanceTime(150, ethers)
        await this.sushiSwapPair.sync()
        await advanceTime(150, ethers)
        await this.oracleF.get(this.oracleData)
        const price1 = (await this.oracleF.peek(this.oracleData))[1]

        expect(price0).to.be.equal(getBigNumber(1).mul(5).div(10))
        expect(roundBN(price1)).to.be.equal(roundBN(getBigNumber(1).mul(75).div(100)))
      })
    })

    it("Assigns name to SushiSwap TWAP", async function () {
      expect(await this.oracleF.name(this.oracleData)).to.equal("SushiSwap TWAP")
    })

    it("Assigns symbol to S", async function () {
      expect(await this.oracleF.symbol(this.oracleData)).to.equal("S")
    })
  })

  describe("backwards oracle", function () {})
})
