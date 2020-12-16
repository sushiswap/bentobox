const { ethers } = require("hardhat")
<<<<<<< HEAD
const { expect, assert } = require("chai")
const { e18, roundBN } = require("../utilities")
const { advanceBlock } = require("../utilities/timeWarp")
const { encodePrice } = require("../utilities")
=======
const { expect } = require("chai")
const { e18, roundBN, encodePrice, advanceTime } = require("../utilities")
>>>>>>> f4655af (Coverage, and grammar)

describe("SimpleSLPOracle", function () {
  before(async function () {
    this.WETH9 = await ethers.getContractFactory("WETH9")

    this.BentoBox = await ethers.getContractFactory("BentoBox")

    this.UniswapV2Pair = await ethers.getContractFactory("UniswapV2Pair")

    this.SushiSwapFactory = await ethers.getContractFactory("UniswapV2Factory")

    this.ReturnFalseERC20 = await ethers.getContractFactory(
      "ReturnFalseERC20Mock"
    )

    this.RevertingERC20 = await ethers.getContractFactory("RevertingERC20Mock")

    this.SimpleSLPOracle0 = await ethers.getContractFactory(
      "SimpleSLPTWAP0Oracle"
    )

    this.SimpleSLPOracle1 = await ethers.getContractFactory(
      "SimpleSLPTWAP1Oracle"
    )

    this.signers = await ethers.getSigners()

    this.alice = this.signers[0]
  })

  beforeEach(async function () {
    this.weth9 = await this.WETH9.deploy()
    await this.weth9.deployed()

    this.bentoBox = await this.BentoBox.deploy(this.weth9.address)
    await this.bentoBox.deployed()

    this.collateral = await this.ReturnFalseERC20.deploy(
      "Token A",
      "A",
      e18("10000000")
    )
    await this.collateral.deployed()

    this.asset = await this.RevertingERC20.deploy(
      "Token B",
      "B",
      e18("10000000")
    )
    await this.asset.deployed()

    this.factory = await this.SushiSwapFactory.deploy(this.alice.address)
    await this.factory.deployed()

    const createPairTx = await this.factory.createPair(
      this.collateral.address,
      this.asset.address
    )

    const sushipair = (await createPairTx.wait()).events[0].args.pair

    this.pair = await this.UniswapV2Pair.attach(sushipair)

    await this.collateral.transfer(this.pair.address, e18(5))
    await this.asset.transfer(this.pair.address, e18(10))
    this.expectedPrice = encodePrice(e18(5), e18(10))

    await this.pair.mint(this.alice.address)

    if (this.asset.address == (await this.pair.token0())) {
      this.oracle = await this.SimpleSLPOracle0.deploy()
    } else {
      this.oracle = await this.SimpleSLPOracle1.deploy()
    }
    await this.oracle.deployed()
    this.oracleData = await this.oracle.getDataParameter(this.pair.address)
  })
  describe("peek", function () {
    it("should return false on first peek", async function () {
      expect((await this.oracle.peek(this.oracleData))[1]).to.equal("0")
<<<<<<< HEAD
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

      let info = (
        await this.oracle.pairs(this.pair.address)
      ).priceAverage.toString()

      expect(info).to.be.equal(this.expectedPrice[1].toString())
      expect((await this.oracle.peek(this.oracleData))[1]).to.be.equal(
        e18(1).mul(5).div(10)
      )
=======
>>>>>>> f4655af (Coverage, and grammar)
    })
  })

<<<<<<< HEAD
    it("should update prices after swap", async function () {
      const blockTimestamp = (await this.pair.getReserves())[2]
      await this.oracle.get(this.oracleData)
      await advanceTime(301, ethers)
      await this.oracle.get(this.oracleData)

      let price0 = (await this.oracle.peek(this.oracleData))[1]
      await this.collateral.transfer(this.pair.address, e18(5))
      await advanceTime(150, ethers)
      await this.pair.sync()
      await advanceTime(150, ethers)
      await this.oracle.get(this.oracleData)
      let price1 = (await this.oracle.peek(this.oracleData))[1]

      expect(price0).to.be.equal(e18(1).mul(5).div(10))
      expect(roundBN(price1)).to.be.equal(roundBN(e18(1).mul(75).div(100)))
    })
=======
  describe("get", function () {
    it("should update and get prices within period", async function () {
      const blockTimestamp = (await this.pair.getReserves())[2]

      await this.oracle.get(this.oracleData)
      await advanceTime(30, ethers)
      await this.oracle.get(this.oracleData)
      await advanceTime(271, ethers)
      await this.oracle.get(this.oracleData)
      await this.oracle.get(this.oracleData)

      let info = (
        await this.oracle.pairs(this.pair.address)
      ).priceAverage.toString()

      expect(info).to.be.equal(this.expectedPrice[1].toString())
      expect((await this.oracle.peek(this.oracleData))[1]).to.be.equal(
        e18(1).mul(5).div(10)
      )
    })

    it("should update prices after swap", async function () {
      const blockTimestamp = (await this.pair.getReserves())[2]
      await this.oracle.get(this.oracleData)
      await advanceTime(301, ethers)
      await this.oracle.get(this.oracleData)

      let price0 = (await this.oracle.peek(this.oracleData))[1]
      await this.collateral.transfer(this.pair.address, e18(5))
      await advanceTime(150, ethers)
      await this.pair.sync()
      await advanceTime(150, ethers)
      await this.oracle.get(this.oracleData)
      let price1 = (await this.oracle.peek(this.oracleData))[1]

      expect(price0).to.be.equal(e18(1).mul(5).div(10))
      expect(roundBN(price1)).to.be.equal(roundBN(e18(1).mul(75).div(100)))
    })
  })

  it("Assigns name to SushiSwap TWAP", async function () {
    expect(await this.oracle.name(this.oracleData)).to.equal("SushiSwap TWAP")
  })

  it("Assigns symbol to S", async function () {
    expect(await this.oracle.symbol(this.oracleData)).to.equal("S")
>>>>>>> f4655af (Coverage, and grammar)
  })
})
