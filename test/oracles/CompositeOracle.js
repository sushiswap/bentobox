const { ethers } = require("hardhat")
const { expect } = require("chai")
const { getBigNumber, roundBN, advanceTime, prepare, deploy } = require("../utilities")

describe("CompositeOracle", function () {
  before(async function () {
    await prepare(this, [
      "WETH9Mock",
      "BentoBoxPlus",
      "UniswapV2Pair",
      "UniswapV2Factory",
      "ReturnFalseERC20Mock",
      "SimpleSLPTWAP0Oracle",
      "SimpleSLPTWAP1Oracle",
      "CompositeOracle",
    ])

    this.sushiAmount = getBigNumber(400)
    this.ethAmount = getBigNumber(1)
    this.daiAmount = getBigNumber(500)
  })

  beforeEach(async function () {
    await deploy(this, [
      ["weth9", this.WETH9Mock],
      ["sushiToken", this.ReturnFalseERC20Mock, ["SUSHI", "SUSHI", getBigNumber("10000000")]],
      ["ethToken", this.ReturnFalseERC20Mock, ["WETH", "ETH", getBigNumber("10000000")]],
      ["daiToken", this.ReturnFalseERC20Mock, ["DAI", "DAI", getBigNumber("10000000")]],
      ["factory", this.UniswapV2Factory, [this.alice.address]],
    ])
    await deploy(this, [["bentoBox", this.BentoBoxPlus, [this.weth9.address]]])

    let createPairTx = await this.factory.createPair(this.sushiToken.address, this.ethToken.address)

    const pairSushiEth = (await createPairTx.wait()).events[0].args.pair

    this.pairSushiEth = await this.UniswapV2Pair.attach(pairSushiEth)

    await this.sushiToken.transfer(this.pairSushiEth.address, this.sushiAmount)
    await this.ethToken.transfer(this.pairSushiEth.address, this.ethAmount)

    await this.pairSushiEth.mint(this.alice.address)

    if (this.ethToken.address == (await this.pairSushiEth.token0())) {
      this.oracleSushiEth = await this.SimpleSLPTWAP0Oracle.deploy()
    } else {
      this.oracleSushiEth = await this.SimpleSLPTWAP1Oracle.deploy()
    }
    await this.oracleSushiEth.deployed()
    this.oracleDataA = await this.oracleSushiEth.getDataParameter(this.pairSushiEth.address)

    createPairTx = await this.factory.createPair(this.ethToken.address, this.daiToken.address)

    const pairDaiEth = (await createPairTx.wait()).events[0].args.pair

    this.pairDaiEth = await this.UniswapV2Pair.attach(pairDaiEth)

    await this.daiToken.transfer(this.pairDaiEth.address, this.daiAmount)
    await this.ethToken.transfer(this.pairDaiEth.address, this.ethAmount)

    await this.pairDaiEth.mint(this.alice.address)

    if (this.daiToken.address == (await this.pairDaiEth.token0())) {
      this.oracleDaiEth = await this.SimpleSLPTWAP0Oracle.deploy()
    } else {
      this.oracleDaiEth = await this.SimpleSLPTWAP1Oracle.deploy()
    }
    await this.oracleDaiEth.deployed()
    this.oracleDataB = await this.oracleDaiEth.getDataParameter(this.pairDaiEth.address)
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
      expect((await this.compositeOracle.peek(this.compositeOracleData))[1]).to.equal("0")
    })
  })

  describe("get", function () {
    it("should update and get prices within period", async function () {
      await this.compositeOracle.get(this.compositeOracleData)
      await advanceTime(301, ethers)
      await this.compositeOracle.get(this.compositeOracleData)

      const price = (await this.compositeOracle.peek(this.compositeOracleData))[1]
      expect(roundBN(price)).to.be.equal("80")
    })
    it("should update prices after swap", async function () {
      //update exchange rate
      await this.compositeOracle.get(this.compositeOracleData)
      await advanceTime(301, ethers)
      await this.compositeOracle.get(this.compositeOracleData)

      //check the composite oracle
      let price0 = (await this.compositeOracle.peek(this.compositeOracleData))[1]

      //check expectations
      const oldPrice = this.sushiAmount.mul(100).div(this.daiAmount)
      expect(roundBN(price0)).to.be.equal(oldPrice)

      //half the sushi price
      await advanceTime(150, ethers)
      await this.sushiToken.transfer(this.pairSushiEth.address, getBigNumber(400))
      await this.pairSushiEth.sync()
      await advanceTime(150, ethers)

      // read exchange rate again half way
      await this.compositeOracle.get(this.compositeOracleData)
      let price1 = (await this.compositeOracle.peek(this.compositeOracleData))[1]

      //check expectations
      // oracle returns "the amount of callateral unit to buy 10^18 of asset units"
      // expectation: 1.2 of Sushi to buy 1 DAI
      expect(roundBN(price1)).to.be.equal("120")

      //read exchange rate at final price
      await advanceTime(301, ethers)
      await this.compositeOracle.get(this.compositeOracleData)
      let price2 = (await this.compositeOracle.peek(this.compositeOracleData))[1]
      // oracle returns "the amount of callateral unit to buy 10^18 of asset units"
      // expectation: 1.6 of Sushi to buy 1 DAI

      expect(roundBN(price2)).to.be.equal("160")
    })
  })

  it("Assigns name SushiSwap TWAP+SushiSwap TWAP to Composite Oracle", async function () {
    expect(await this.compositeOracle.name(this.compositeOracleData)).to.equal("SushiSwap TWAP+SushiSwap TWAP")
  })

  it("Assigns symbol S+S to Composite Oracle", async function () {
    expect(await this.compositeOracle.symbol(this.compositeOracleData)).to.equal("S+S")
  })
})
