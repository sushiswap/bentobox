const { ethers } = require("hardhat")
const { expect, assert } = require("chai")
const { getApprovalDigest, getDomainSeparator } = require("./utilities")
const { parseEther, parseUnits } = require("ethers/lib/utils")
const { ecsign } = require("ethereumjs-util")

describe("Lending Pair", function () {
  before(async function () {
    this.WETH9 = await ethers.getContractFactory("WETH9")

    this.BentoBox = await ethers.getContractFactory("BentoBox")

    this.LendingPair = await ethers.getContractFactory("LendingPair")

    this.UniswapV2Pair = await ethers.getContractFactory("UniswapV2Pair")

    this.SushiSwapFactory = await ethers.getContractFactory("UniswapV2Factory")

    this.SushiSwapSwapper = await ethers.getContractFactory("SushiSwapSwapper")

    this.ReturnFalseERC20 = await ethers.getContractFactory(
      "ReturnFalseERC20Mock"
    )

    this.RevertingERC20 = await ethers.getContractFactory("RevertingERC20Mock")

    this.Oracle = await ethers.getContractFactory("OracleMock")

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

    this.a = await this.ReturnFalseERC20.deploy(
      "Token A",
      "A",
      parseUnits("10000000", 18)
    )
    await this.a.deployed()

    this.b = await this.RevertingERC20.deploy(
      "Token B",
      "B",
      parseUnits("10000000", 18)
    )
    await this.b.deployed()

    // Alice has all tokens for a and b since creator

    // Bob has 1000 b tokens
    await this.b.transfer(this.bob.address, parseUnits("1000", 18))
    await this.b.transfer(this.charlie.address, parseUnits("1000", 18))

    this.lendingPair = await this.LendingPair.deploy(this.bentoBox.address)
    await this.lendingPair.deployed()

    this.factory = await this.SushiSwapFactory.deploy(this.alice.address)
    await this.factory.deployed()

    const createPairTx = await this.factory.createPair(
      this.a.address,
      this.b.address
    )

    const pair = (await createPairTx.wait()).events[0].args.pair

    this.sushiswappair = await this.UniswapV2Pair.attach(pair)

    await this.a.transfer(this.sushiswappair.address, parseUnits("5000", 18))
    await this.b.transfer(this.sushiswappair.address, parseUnits("5000", 18))

    await this.sushiswappair.mint(this.alice.address)

    this.swapper = await this.SushiSwapSwapper.deploy(
      this.bentoBox.address,
      this.factory.address
    )
    await this.swapper.deployed()

    await this.lendingPair.setSwapper(this.swapper.address, true)

    this.oracle = await this.Oracle.deploy()
    await this.oracle.deployed()

    await this.oracle.set(parseUnits("1", 18), this.alice.address)

    await this.bentoBox.setMasterContractApproval(
      this.lendingPair.address,
      true
    )
    await this.bentoBox
      .connect(this.bob)
      .setMasterContractApproval(this.lendingPair.address, true)

    const oracleData = await this.oracle.getDataParameter()

    this.initData = await this.lendingPair.getInitData(
      this.a.address,
      this.b.address,
      this.oracle.address,
      oracleData
    )

    const deployTx = await this.bentoBox.deploy(
      this.lendingPair.address,
      this.initData
    )

    const cloneAddress = (await deployTx.wait()).events[1].args.clone_address

    this.pair = await this.LendingPair.attach(cloneAddress)
    await this.pair.updateExchangeRate()
  })

  describe("name, symbol and decimals", function () {
    it("should autogen a nice name and symbol", async function () {
      //assert.equal(await this.pair.symbol(), "bmA>B-TEST");
      //assert.equal(await this.pair.name(), "Bento Med Risk Token A>Token B-TEST");
    })
  })

  describe("init", function () {
    it("should not allow to init initialized pair", async function () {
      expect(this.pair.init(this.initData)).to.be.revertedWith(
        "LendingPair: already initialized"
      )
    })
  })

  describe("accrue", function () {})

  describe("isSolvent", function () {})

  describe("peekExchangeRate", function () {
    it("should return correct exchange rate", async function () {
      expect((await this.pair.peekExchangeRate())[1]).to.be.equal(
        parseUnits("1", 18)
      )
    })
  })

  describe("updateExchangeRate", function () {})

  describe("permits", function () {
    it("should give a correct DOMAIN_SEPARATOR", async function () {
      expect(await this.pair.DOMAIN_SEPARATOR()).to.be.equal(
        getDomainSeparator(
          this.pair.address,
          this.alice.provider._network.chainId
        )
      )
    })
    it('should execute a permit', async function() {
        let nonce = await this.pair.nonces(this.charlie.address)
        
        const deadline = (await this.charlie.provider._internalBlockNumber).respTime + 10000
    const digest = await getApprovalDigest(
      this.pair,
      {
        owner: this.charlie.address,
        spender: this.alice.address,
        value: 1,
      },
      nonce,
      deadline
    )
    const { v, r, s } = ecsign(
      Buffer.from(digest.slice(2), "hex"),
      Buffer.from(this.charliePrivateKey.replace("0x", ""), "hex")
    )
    await this.pair
      .connect(this.charlie)
      .permit(
        this.charlie.address,
        this.alice.address,
        1,
        deadline,
        v,
        r,
        s
      , {from: this.charlie.address})
      })

      it('permit should revert on old deadline', async function() {
        let nonce = await this.pair.nonces(this.charlie.address)
        
        const deadline = 0

    const digest = await getApprovalDigest(
      this.pair,
      {
        owner: this.charlie.address,
        spender: this.alice.address,
        value: 1,
      },
      nonce,
      deadline
    )
    const { v, r, s } = ecsign(
      Buffer.from(digest.slice(2), "hex"),
      Buffer.from(this.charliePrivateKey.replace("0x", ""), "hex")
    )

    expect(this.pair
      .connect(this.charlie)
      .permit(
        this.charlie.address,
        this.alice.address,
        1,
        deadline,
        v,
        r,
        s
      , {from: this.charlie.address})).to.be.revertedWith("Expired")
      })

      it('permit should revert on incorrect signer', async function() {
        let nonce = await this.pair.nonces(this.charlie.address)
        
        const deadline = (await this.charlie.provider._internalBlockNumber).respTime + 10000

    const digest = await getApprovalDigest(
      this.pair,
      {
        owner: this.charlie.address,
        spender: this.alice.address,
        value: 1,
      },
      nonce,
      deadline
    )
    const { v, r, s } = ecsign(
      Buffer.from(digest.slice(2), "hex"),
      Buffer.from(this.charliePrivateKey.replace("0x", ""), "hex")
    )

    expect(this.pair
      .connect(this.charlie)
      .permit(
        this.bob.address,
        this.alice.address,
        1,
        deadline,
        v,
        r,
        s
      , {from: this.charlie.address})).to.be.revertedWith("Invalid Signature")
      })
  })

  describe("assets", function () {
    describe("addAsset", function () {
      it("should revert if MasterContract is not approved", async function () {
        await this.b.connect(this.charlie).approve(this.bentoBox.address, 300)
        expect(
          this.pair.connect(this.charlie).addAsset(290)
        ).to.be.revertedWith("BentoBox: Transfer not approved")
      })

      it("should take a deposit of assets from BentoBox", async function () {
        await this.b.approve(this.bentoBox.address, 300)
        await this.bentoBox.deposit(this.b.address, this.alice.address, 300)
        await this.pair.addAssetFromBento(300)
        expect(await this.pair.balanceOf(this.alice.address)).to.be.equal(300)
      })

      it("should emit correct event on adding asset", async function () {
        await this.b.approve(this.bentoBox.address, 300)
        expect(this.pair.addAsset(290))
          .to.emit(this.pair, "LogAddAsset")
          .withArgs(this.alice.address, 290, 290)
      })

      it("should have correct balance after adding asset", async function () {
        await this.b.approve(this.bentoBox.address, 300)
        await this.pair.addAsset(290)
        expect(await this.pair.balanceOf(this.alice.address)).to.be.equal(290)
      })
    })

    describe("removeAsset", function () {
      it("should not allow a remove without assets", async function () {
        expect(this.pair.removeAsset(1, this.alice.address)).to.be.revertedWith(
          "BoringMath: Underflow"
        )
      })
    })
  })

  describe("collateral", function () {
    describe("addCollateral", function () {
      it('should take a deposit of collateral', async function() {
        await this.a.approve(this.bentoBox.address, 300)
        expect(this.pair.addCollateral(290)).to.emit(this.pair, "LogAddCollateral")
        .withArgs(this.alice.address, 290)
      })
    })
    describe("removeCollateral", function () {
      it("should not allow a remove without collateral", async function () {
        expect(
          this.pair.removeCollateral(1, this.alice.address)
        ).to.be.revertedWith("BoringMath: Underflow")
      })
    })
  })

  describe("borrow", function () {
    it("should not allow borrowing without any assets", async function () {
      expect(this.pair.borrow(1, this.alice.address)).to.be.revertedWith(
        "BoringMath: Underflow"
      )
    })

    it("should not allow borrowing without any collateral", async function () {
      await this.b.approve(this.bentoBox.address, 300)
      await this.pair.addAsset(290)
      expect(this.pair.borrow(1, this.alice.address)).to.be.revertedWith(
        "user insolvent"
      )
    })
  })

  describe("repay", function () {})

  describe("short", function () {})

  describe("unwind", function () {})

  describe("liquidate", function () {})

  describe("batch", function () {})

  describe("withdrawFees", function () {})

  describe("swipe", function () {})

  describe("onlyOwner functions", function () {
    it("should not allow nonDev to setDev", async function () {
      expect(
        this.pair.connect(this.bob).setDev(this.bob.address)
      ).to.be.revertedWith("LendingPair: Not dev")
    })
  })
})
