const { ethers } = require("hardhat")
const { expect } = require("chai")
const { getBigNumber, roundBN, encodePrice, advanceTime, prepare } = require("../utilities")

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
    this.weth9 = await this.WETH9Mock.deploy()
    await this.weth9.deployed()

    this.bentoBox = await this.BentoBoxPlus.deploy(this.weth9.address)
    await this.bentoBox.deployed()

    this.collateral = await this.ReturnFalseERC20Mock.deploy("Token A", "A", getBigNumber(10000000))
    await this.collateral.deployed()

    this.asset = await this.RevertingERC20Mock.deploy("Token B", "B", getBigNumber(10000000))
    await this.asset.deployed()

    this.factory = await this.UniswapV2Factory.deploy(this.alice.address)
    await this.factory.deployed()

    const createPairTx = await this.factory.createPair(this.collateral.address, this.asset.address)

    const sushipair = (await createPairTx.wait()).events[0].args.pair

    this.pair = await this.UniswapV2Pair.attach(sushipair)

    await this.collateral.transfer(this.pair.address, getBigNumber(5))
    await this.asset.transfer(this.pair.address, getBigNumber(10))
    this.expectedPrice = encodePrice(getBigNumber(5), getBigNumber(10))

    await this.pair.mint(this.alice.address)

    if (this.asset.address == (await this.pair.token0())) {
      this.oracle = await this.SimpleSLPTWAP0Oracle.deploy()
    } else {
      this.oracle = await this.SimpleSLPTWAP1Oracle.deploy()
    }
    await this.oracle.deployed()
    this.oracleData = await this.oracle.getDataParameter(this.pair.address)
  })

  describe("name", function () {
    it("should get name", async function () {
      expect(await this.oracle.name(this.oracleData)).to.be.equal("SushiSwap TWAP")
    })
  })

  describe("symbol", function () {
    it("should get symbol", async function () {
      expect(await this.oracle.symbol(this.oracleData)).to.be.equal("S")
    })
  })
  describe("peek", function () {
    it("should return false on first peek", async function () {
      expect((await this.oracle.peek(this.oracleData))[1]).to.equal("0")
    })

    it("should get price even when time since last update is longer than period", async function () {
      const blockTimestamp = (await this.pair.getReserves())[2]

      await this.oracle.get(this.oracleData)
      await advanceTime(30, ethers)
      await this.oracle.get(this.oracleData)
      await advanceTime(271, ethers)
      await this.oracle.get(this.oracleData)

      let info = (await this.oracle.pairs(this.pair.address)).priceAverage.toString()
      await advanceTime(301, ethers)

      expect(info).to.be.equal(this.expectedPrice[1].toString())
      expect((await this.oracle.peek(this.oracleData))[1]).to.be.equal(getBigNumber(1).mul(5).div(10))
    })
  })

  describe("get", function () {
    it("should update and get prices within period", async function () {
      const blockTimestamp = (await this.pair.getReserves())[2]

      await this.oracle.get(this.oracleData)
      await advanceTime(30, ethers)
      await this.oracle.get(this.oracleData)
      await advanceTime(271, ethers)
      await this.oracle.get(this.oracleData)
      await this.oracle.get(this.oracleData)

      let info = (await this.oracle.pairs(this.pair.address)).priceAverage.toString()

      expect(info).to.be.equal(this.expectedPrice[1].toString())
      expect((await this.oracle.peek(this.oracleData))[1]).to.be.equal(getBigNumber(1).mul(5).div(10))
    })

    it("should update prices after swap", async function () {
      const blockTimestamp = (await this.pair.getReserves())[2]
      await this.oracle.get(this.oracleData)
      await advanceTime(301, ethers)
      await this.oracle.get(this.oracleData)

      const price0 = (await this.oracle.peek(this.oracleData))[1]
      await this.collateral.transfer(this.pair.address, getBigNumber(5))
      await advanceTime(150, ethers)
      await this.pair.sync()
      await advanceTime(150, ethers)
      await this.oracle.get(this.oracleData)
      const price1 = (await this.oracle.peek(this.oracleData))[1]

      expect(price0).to.be.equal(getBigNumber(1).mul(5).div(10))
      expect(roundBN(price1)).to.be.equal(roundBN(getBigNumber(1).mul(75).div(100)))
    })
  })

  it("Assigns name to SushiSwap TWAP", async function () {
    expect(await this.oracle.name(this.oracleData)).to.equal("SushiSwap TWAP")
  })

  it("Assigns symbol to S", async function () {
    expect(await this.oracle.symbol(this.oracleData)).to.equal("S")
  })
})
