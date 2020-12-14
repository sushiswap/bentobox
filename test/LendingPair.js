const { ethers } = require("hardhat")
const { expect, assert } = require("chai")
const { getApprovalDigest } = require("./permit")
const { parseEther, parseUnits } = require("ethers/lib/utils")
const { ecsign } = require("ethereumjs-util")

describe("Lending Pair", function () {
  before(async function () {
    this.WETH9 = await ethers.getContractFactory("WETH9")

    this.BentoBox = await ethers.getContractFactory("BentoBox")

    this.LendingPair = await ethers.getContractFactory("LendingPair")

    this.UniswapV2Pair = await ethers.getContractFactory("UniswapV2Pair")

    this.SushiSwapFactory = await ethers.getContractFactory("UniswapV2Factory")

    this.ReturnFalseERC20 = await ethers.getContractFactory("ReturnFalseERC20")

    this.RevertingERC20 = await ethers.getContractFactory("RevertingERC20")

    this.TestOracle = await ethers.getContractFactory("TestOracle")

    this.SushiSwapSwapper = await ethers.getContractFactory("SushiSwapSwapper")

    this.signers = await ethers.getSigners()

    this.alice = this.signers[0]

    this.bob = this.signers[1]

    this.charlie = this.signers[2]

    this.charliePrivateKey =
      "0x94890218f2b0d04296f30aeafd13655eba4c5bbf1770273276fee52cbe3f2cb4"
  })

  beforeEach(async function () {
    this.weth9 = await this.WETH9.deploy()
    await this.weth9.deployed()

    this.bentoBox = await this.BentoBox.deploy(this.weth9.address)
    await this.bentoBox.deployed()

    this.a = await this.ReturnFalseERC20.deploy("Token A", "A", parseUnits("10000000", 18))

    await this.a.deployed()

    this.b = await this.RevertingERC20.deploy("Token B", "B", parseUnits("10000000", 18))

    await this.b.deployed()

    // Alice has all tokens for a and b since creator

    // Bob has 1000 b tokens
    await this.b.transfer(this.bob.address, parseUnits("1000", 18))
    await this.b.transfer(this.charlie.address, parseUnits("1000", 18))

    this.lendingPair = await this.LendingPair.deploy(this.bentoBox.address)
    await this.lendingPair.deployed()

    this.factory = await this.SushiSwapFactory.deploy(this.alice.address)
    await this.factory.deployed()
    let tx = await this.factory.createPair(this.a.address, this.b.address)
    let pair_address = (await tx.wait()).events[0].args.pair
    this.sushiswappair = await this.UniswapV2Pair.attach(pair_address)
    await this.a.transfer(this.sushiswappair.address, parseUnits("5000", 18));
    await this.b.transfer(this.sushiswappair.address, parseUnits("5000", 18));
    await this.sushiswappair.mint(this.alice.address);

    this.swapper = await this.SushiSwapSwapper.deploy(this.bentoBox.address, this.factory.address)
    await this.swapper.deployed()
    await this.lendingPair.setSwapper(this.swapper.address, true)

    this.testOracle = await this.TestOracle.deploy()
    await this.testOracle.deployed()
    await this.testOracle.set(parseUnits("1", 18), this.alice.address)

    await this.bentoBox.setMasterContractApproval(this.lendingPair.address, true);
    await this.bentoBox.connect(this.bob).setMasterContractApproval(this.lendingPair.address, true);

    let oracleData = await this.testOracle.getDataParameter()
    let initData = await this.lendingPair.getInitData(this.a.address, this.b.address, this.testOracle.address, oracleData)
    tx = await this.bentoBox.deploy(this.lendingPair.address, initData)
    let clone_address = (await tx.wait()).events[1].args.clone_address
    this.pair = await this.LendingPair.attach(clone_address)
    await this.pair.updateExchangeRate()
  })

  describe("Symbol", function () {
    it('should autogen a nice name and symbol', async function () {
        console.log(await this.pair.name())
        //assert.equal(await this.pair.symbol(), "bmA>B-TEST");
        //assert.equal(await this.pair.name(), "Bento Med Risk Token A>Token B-TEST");
    })
  })
})
