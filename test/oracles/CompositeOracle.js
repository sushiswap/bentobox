const { ethers } = require("hardhat")
const { expect, assert } = require("chai")
const { e18, roundBN } = require("../utilities")
const { advanceBlock } = require("../utilities/timeWarp")

describe("CompositeOracle", function () {
  before(async function () {
    this.WETH9 = await ethers.getContractFactory("WETH9")

    this.BentoBox = await ethers.getContractFactory("BentoBox")

    this.UniswapV2Pair = await ethers.getContractFactory("UniswapV2Pair")

    this.SushiSwapFactory = await ethers.getContractFactory("UniswapV2Factory")

    this.ReturnFalseERC20 = await ethers.getContractFactory(
      "ReturnFalseERC20Mock"
    )

    this.SimpleSLPOracle0 = await ethers.getContractFactory(
      "SimpleSLPTWAP0Oracle"
    )

    this.SimpleSLPOracle1 = await ethers.getContractFactory(
      "SimpleSLPTWAP1Oracle"
    )

    this.CompositeOracle = await ethers.getContractFactory("CompositeOracle")

    this.signers = await ethers.getSigners()

    this.alice = this.signers[0]

    this.sushiAmount = e18(400)

    this.ethAmount = e18(1)

    this.daiAmount = e18(500)
  })

  beforeEach(async function () {
    this.weth9 = await this.WETH9.deploy()
    await this.weth9.deployed()

    this.bentoBox = await this.BentoBox.deploy(this.weth9.address)
    await this.bentoBox.deployed()

    this.sushiToken = await this.ReturnFalseERC20.deploy(
      "SUSHI",
      "SUSHI",
      e18("10000000")
    )
    await this.sushiToken.deployed()

    this.ethToken = await this.ReturnFalseERC20.deploy(
      "WETH",
      "ETH",
      e18("10000000")
    )
    await this.ethToken.deployed()

    this.daiToken = await this.ReturnFalseERC20.deploy(
      "DAI",
      "DAI",
      e18("10000000")
    )
    await this.daiToken.deployed()

    this.factory = await this.SushiSwapFactory.deploy(this.alice.address)
    await this.factory.deployed()

    let createPairTx = await this.factory.createPair(
      this.sushiToken.address,
      this.ethToken.address
    )

    const pairSushiEth = (await createPairTx.wait()).events[0].args.pair

    this.pairSushiEth = await this.UniswapV2Pair.attach(pairSushiEth)

    await this.sushiToken.transfer(this.pairSushiEth.address, this.sushiAmount)
    await this.ethToken.transfer(this.pairSushiEth.address, this.ethAmount)

    await this.pairSushiEth.mint(this.alice.address)

    if (this.ethToken.address == (await this.pairSushiEth.token0())) {
      this.oracleSushiEth = await this.SimpleSLPOracle0.deploy()
    } else {
      this.oracleSushiEth = await this.SimpleSLPOracle1.deploy()
    }
    await this.oracleSushiEth.deployed()
    this.oracleDataA = await this.oracleSushiEth.getDataParameter(
      this.pairSushiEth.address
    )

    createPairTx = await this.factory.createPair(
      this.ethToken.address,
      this.daiToken.address
    )

    const pairDaiEth = (await createPairTx.wait()).events[0].args.pair

    this.pairDaiEth = await this.UniswapV2Pair.attach(pairDaiEth)

    await this.daiToken.transfer(this.pairDaiEth.address, this.daiAmount)
    await this.ethToken.transfer(this.pairDaiEth.address, this.ethAmount)

    await this.pairDaiEth.mint(this.alice.address)

    if (this.daiToken.address == (await this.pairDaiEth.token0())) {
      this.oracleDaiEth = await this.SimpleSLPOracle0.deploy()
    } else {
      this.oracleDaiEth = await this.SimpleSLPOracle1.deploy()
    }
    await this.oracleDaiEth.deployed()
    this.oracleDataB = await this.oracleDaiEth.getDataParameter(
      this.pairDaiEth.address
    )
    this.compositeOracle = await this.CompositeOracle.deploy()
    await this.compositeOracle.deployed()

    this.compositeOracleData = await this.compositeOracle.getDataParameter(
      this.oracleSushiEth.address,
      this.oracleDaiEth.address,
      this.oracleDataA,
      this.oracleDataB
    )
  })
  describe("peek", function () {
    it("should return false on first peek", async function () {
      expect(
        (await this.compositeOracle.peek(this.compositeOracleData))[1]
      ).to.equal("0")
    })
  })

  describe("get", function () {
    it("should update and get prices within period", async function () {
      await this.compositeOracle.get(this.compositeOracleData)
      await advanceTime(301, ethers)
      await this.compositeOracle.get(this.compositeOracleData)

      const price = (
        await this.compositeOracle.peek(this.compositeOracleData)
      )[1]
      expect(roundBN(price)).to.be.equal("80")
    })

    it("should update prices after swap", async function () {
      //update exchange rate
      await this.compositeOracle.get(this.compositeOracleData)
      await advanceTime(301, ethers)
      await this.compositeOracle.get(this.compositeOracleData)

      //check the composite oracle
      let price0 = (
        await this.compositeOracle.peek(this.compositeOracleData)
      )[1]

      //check expectations
      const oldPrice = this.sushiAmount.mul(100).div(this.daiAmount)
      expect(roundBN(price0)).to.be.equal(oldPrice)

      //half the sushi price
      await advanceTime(150, ethers)
      await this.sushiToken.transfer(this.pairSushiEth.address, e18(400))
      await this.pairSushiEth.sync()
      await advanceTime(150, ethers)

      // read exchange rate again half way
      await this.compositeOracle.get(this.compositeOracleData)
      let price1 = (
        await this.compositeOracle.peek(this.compositeOracleData)
      )[1]

      //check expectations
      // oracle returns "the amount of callateral unit to buy 10^18 of asset units"
      // expectation: 1.2 of Sushi to buy 1 DAI
      expect(roundBN(price1)).to.be.equal("120")

      //read exchange rate at final price
      await advanceTime(301, ethers)
      await this.compositeOracle.get(this.compositeOracleData)
      let price2 = (
        await this.compositeOracle.peek(this.compositeOracleData)
      )[1]
      // oracle returns "the amount of callateral unit to buy 10^18 of asset units"
      // expectation: 1.6 of Sushi to buy 1 DAI

      expect(roundBN(price2)).to.be.equal("160")
    })
  })
})
