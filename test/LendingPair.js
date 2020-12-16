const {
  ethers: { utils },
} = require("hardhat")
const { expect, assert } = require("chai")
const { e18, sansBorrowFee, advanceBlock } = require("./utilities")

const { parseEther, parseUnits } = utils

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

    this.a = await this.ReturnFalseERC20.deploy("Token A", "A", e18("10000000"))
    await this.a.deployed()

    this.b = await this.RevertingERC20.deploy("Token B", "B", e18("10000000"))
    await this.b.deployed()

    // Alice has all tokens for a and b since creator

    // Bob has 1000 b tokens
    await this.b.transfer(this.bob.address, e18(1000))
    await this.b.transfer(this.charlie.address, e18(1000))

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

    await this.a.transfer(this.sushiswappair.address, e18(5000))
    await this.b.transfer(this.sushiswappair.address, e18(5000))

    await this.sushiswappair.mint(this.alice.address)

    this.swapper = await this.SushiSwapSwapper.deploy(
      this.bentoBox.address,
      this.factory.address
    )
    await this.swapper.deployed()

    await this.lendingPair.setSwapper(this.swapper.address, true)

    this.oracle = await this.Oracle.deploy()
    await this.oracle.deployed()

    await this.oracle.set(e18(1), this.alice.address)

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

  describe("Depolyment", function () {
    it("Assigns a name", async function () {
      //assert.equal(await this.pair.name(), "Bento Med Risk Token A>Token B-TEST");
    })
    it("Assigns a symbol", async function () {
      //assert.equal(await this.pair.symbol(), "bmA>B-TEST");
    })

    it("Assigns dev", async function () {
      expect(await this.pair.dev()).to.be.equal(this.alice.address)
    })

    it("Assigns feeTo", async function () {
      expect(await this.pair.feeTo()).to.be.equal(this.alice.address)
    })
  })

  describe("Init", function () {
    it("Reverts init for initilised pair", async function () {
      expect(this.pair.init(this.initData)).to.be.revertedWith(
        "LendingPair: already initialized"
      )
    })
  })

  describe("Accrue", function () {
    it("should update the interest rate according to utilization", async function () {
      await this.b.approve(this.bentoBox.address, e18(700))
      await this.pair.addAsset(e18(290))
      await this.a.approve(this.bentoBox.address, e18(800))
      await this.pair.addCollateral(e18(100))
      await this.pair.borrow(sansBorrowFee(e18(75)), this.alice.address)
      await this.pair.accrue()
      await this.oracle.set("1100000000000000000", this.pair.address)
      await this.pair.updateExchangeRate()
      let borrowFractionLeft = await this.pair.userBorrowFraction(
        this.alice.address
      )
      await this.pair.repay(borrowFractionLeft)
      let collateralLeft = await this.pair.userCollateralAmount(
        this.alice.address
      )
      await this.pair.removeCollateral(collateralLeft, this.alice.address)
      // run for a while with 0 utilization
      let rate1 = (await this.pair.accrueInfo()).interestPerBlock
      for (let i = 0; i < 20; i++) {
        await advanceBlock(ethers)
      }
      await this.pair.accrue()

      // check results
      let rate2 = (await this.pair.accrueInfo()).interestPerBlock
      assert(rate2.lt(rate1), "rate has not adjusted down with low utilization")

      // then increase utilization to 90%
      await this.pair.addCollateral(e18(400))
      // 300 * 0.9 = 270
      await this.pair.borrow(sansBorrowFee(e18(270)), this.alice.address)

      // and run a while again
      rate1 = (await this.pair.accrueInfo()).interestPerBlock
      for (let i = 0; i < 20; i++) {
        await advanceBlock(ethers)
      }

      // check results
      await this.pair.accrue()
      rate2 = (await this.pair.accrueInfo()).interestPerBlock
      assert(rate2.gt(rate1), "rate has not adjusted up with high utilization")
    })
  })

  describe("Is Solvent", function () {
    //
  })

  describe("Peek Exchange Rate", function () {
    it("Returns expected exchange rate", async function () {
      expect((await this.pair.peekExchangeRate())[1]).to.be.equal(
        parseUnits("1", 18)
      )
    })
  })

  describe("Update Exchange Rate", function () {
    //
  })

  describe("Add Asset", function () {
    it("should revert if MasterContract is not approved", async function () {
      await this.b.connect(this.charlie).approve(this.bentoBox.address, 300)
      expect(this.pair.connect(this.charlie).addAsset(290)).to.be.revertedWith(
        "BentoBox: Transfer not approved"
      )
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

  describe("Remove Asset", function () {
    it("should not allow a remove without assets", async function () {
      expect(this.pair.removeAsset(1, this.alice.address)).to.be.revertedWith(
        "BoringMath: Underflow"
      )
    })
  })

  describe("Add Collateral", function () {
    it("should take a deposit of collateral", async function () {
      await this.a.approve(this.bentoBox.address, 300)
      expect(this.pair.addCollateral(290))
        .to.emit(this.pair, "LogAddCollateral")
        .withArgs(this.alice.address, 290)
    })
  })
  describe("Remove Collateral", function () {
    it("should not allow a remove without collateral", async function () {
      expect(
        this.pair.removeCollateral(1, this.alice.address)
      ).to.be.revertedWith("BoringMath: Underflow")
    })

    it("should allow to partial withdrawal of collateral", async function () {
      await this.b.approve(this.bentoBox.address, e18(700))
      await this.pair.addAsset(e18(290))
      await this.a.approve(this.bentoBox.address, e18(100))
      await this.pair.addCollateral(e18(100))
      await this.pair.borrow(sansBorrowFee(e18(75)), this.alice.address)
      await this.pair.accrue()
      await this.oracle.set("1100000000000000000", this.pair.address)
      await this.pair.updateExchangeRate()
      let borrowFractionLeft = await this.pair.userBorrowFraction(
        this.alice.address
      )
      await this.pair.repay(borrowFractionLeft)
      await this.pair.removeCollateral(e18(60), this.alice.address)
    })

    it("should allow to full withdrawal of collateral", async function () {
      await this.b.approve(this.bentoBox.address, e18(700))
      await this.pair.addAsset(e18(290))
      await this.a.approve(this.bentoBox.address, e18(100))
      await this.pair.addCollateral(e18(100))
      await this.pair.borrow(sansBorrowFee(e18(75)), this.alice.address)
      await this.pair.accrue()
      await this.oracle.set("1100000000000000000", this.pair.address)
      await this.pair.updateExchangeRate()
      let borrowFractionLeft = await this.pair.userBorrowFraction(
        this.alice.address
      )
      await this.pair.repay(borrowFractionLeft)
      let collateralLeft = await this.pair.userCollateralAmount(
        this.alice.address
      )
      await this.pair.removeCollateral(collateralLeft, this.alice.address)
    })
  })

  describe("Borrow", function () {
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

    it("should allow borrowing with collateral up to 75%", async function () {
      await this.b.approve(this.bentoBox.address, e18(300))
      await this.pair.addAsset(e18(290))
      await this.a.approve(this.bentoBox.address, e18(100))
      await this.pair.addCollateral(e18(100))
      expect(this.pair.borrow(sansBorrowFee(e18(75)), this.alice.address))
        .to.emit(this.pair, "LogAddBorrow")
        .withArgs(
          this.alice.address,
          "74999999999999999999",
          "74999999999999999999"
        )
    })

    it("should not allow any more borrowing", async function () {
      await this.b.approve(this.bentoBox.address, e18(300))
      await this.pair.addAsset(e18(290))
      await this.a.approve(this.bentoBox.address, e18(100))
      await this.pair.addCollateral(e18(100))
      await this.pair.borrow(sansBorrowFee(e18(75)), this.alice.address)
      expect(this.pair.borrow(100, this.alice.address)).to.be.revertedWith(
        "user insolvent"
      )
    })

    it("should report insolvency due to interest", async function () {
      await this.b.approve(this.bentoBox.address, e18(300))
      await this.pair.addAsset(e18(290))
      await this.a.approve(this.bentoBox.address, e18(100))
      await this.pair.addCollateral(e18(100))
      await this.pair.borrow(sansBorrowFee(e18(75)), this.alice.address)
      await this.pair.accrue()
      expect(await this.pair.isSolvent(this.alice.address, false)).to.be.false
    })

    it("should not report open insolvency due to interest", async function () {
      await this.b.approve(this.bentoBox.address, e18(300))
      await this.pair.addAsset(e18(290))
      await this.a.approve(this.bentoBox.address, e18(100))
      await this.pair.addCollateral(e18(100))
      await this.pair.borrow(sansBorrowFee(e18(75)), this.alice.address)
      await this.pair.accrue()
      expect(await this.pair.isSolvent(this.alice.address, true)).to.be.true
    })

    it("should report open insolvency after oracle rate is updated", async function () {
      await this.b.approve(this.bentoBox.address, e18(300))
      await this.pair.addAsset(e18(290))
      await this.a.approve(this.bentoBox.address, e18(100))
      await this.pair.addCollateral(e18(100))
      await this.pair.borrow(sansBorrowFee(e18(75)), this.alice.address)
      await this.pair.accrue()
      await this.oracle.set("1100000000000000000", this.pair.address)
      await this.pair.updateExchangeRate()
      expect(await this.pair.isSolvent(this.alice.address, true)).to.be.false
    })
  })

  describe("Repay", function () {
    it("should allow to repay", async function () {
      await this.b.approve(this.bentoBox.address, e18(700))
      await this.pair.addAsset(e18(290))
      await this.a.approve(this.bentoBox.address, e18(100))
      await this.pair.addCollateral(e18(100))
      await this.pair.borrow(sansBorrowFee(e18(75)), this.alice.address)
      await this.pair.accrue()
      await this.oracle.set("1100000000000000000", this.pair.address)
      await this.pair.updateExchangeRate()
      await this.pair.repay(e18(50))
    })

    it("should allow full repayment", async function () {
      await this.b.approve(this.bentoBox.address, e18(900))
      await this.pair.addAsset(e18(290))
      await this.a.approve(this.bentoBox.address, e18(100))
      await this.pair.addCollateral(e18(100))
      await this.pair.borrow(sansBorrowFee(e18(75)), this.alice.address)
      await this.pair.accrue()
      await this.oracle.set("1100000000000000000", this.pair.address)
      await this.pair.updateExchangeRate()
      let borrowFractionLeft = await this.pair.userBorrowFraction(
        this.alice.address
      )
      await this.pair.repay(borrowFractionLeft)
    })
  })

  describe("Short", function () {
    it("should not allow shorting if it does not return enough", async function () {
      await this.a.approve(this.bentoBox.address, e18(100))
      await this.pair.addCollateral(e18(100))
      await this.b.connect(this.bob).approve(this.bentoBox.address, e18(1000))
      await this.pair.connect(this.bob).addAsset(e18(1000))
      expect(
        this.pair.short(this.swapper.address, e18(200), e18(200))
      ).to.be.revertedWith("SushiSwapSwapper: return not enough")
    })

    it("should not allow shorting into insolvency", async function () {
      await this.a.approve(this.bentoBox.address, e18(100))
      await this.pair.addCollateral(e18(100))
      await this.b.connect(this.bob).approve(this.bentoBox.address, e18(1000))
      await this.pair.connect(this.bob).addAsset(e18(1000))
      expect(
        this.pair.short(this.swapper.address, e18(300), e18(200))
      ).to.be.revertedWith("user insolvent")
    })

    it("should allow shorting", async function () {
      await this.a.approve(this.bentoBox.address, e18(100))
      await this.pair.addCollateral(e18(100))
      await this.b.connect(this.bob).approve(this.bentoBox.address, e18(1000))
      await this.pair.connect(this.bob).addAsset(e18(1000))
      await this.pair.short(this.swapper.address, e18(250), e18(230))
    })

    it("should limit asset availability after shorting", async function () {
      await this.a.approve(this.bentoBox.address, e18(100))
      await this.pair.addCollateral(e18(100))
      await this.b.connect(this.bob).approve(this.bentoBox.address, e18(1000))
      await this.pair.connect(this.bob).addAsset(e18(1000))
      await this.pair.short(this.swapper.address, e18(250), e18(230))
      const bobBal = await this.pair.balanceOf(this.bob.address)
      expect(bobBal).to.be.equal(e18(1000))
      // virtual balance of 1000 is higher than the contract has
      expect(
        this.pair.connect(this.bob).removeAsset(bobBal, this.bob.address)
      ).to.be.revertedWith("BoringMath: Underflow")
      // 750 still too much, as 250 should be kept to rewind all shorts
      expect(
        this.pair.connect(this.bob).removeAsset(e18(750), this.bob.address)
      ).to.be.revertedWith("BoringMath: Underflow")
      await this.pair.connect(this.bob).removeAsset(e18(499), this.bob.address)
    })
  })

  describe("Unwind", function () {
    it("should allow unwinding the short", async function () {
      await this.a.approve(this.bentoBox.address, e18(100))
      await this.pair.addCollateral(e18(100))
      await this.b.connect(this.bob).approve(this.bentoBox.address, e18(1000))
      await this.pair.connect(this.bob).addAsset(e18(1000))
      await this.pair.short(this.swapper.address, e18(250), e18(230))
      await this.pair.unwind(this.swapper.address, e18(250), e18(337))
    })
  })

  describe("Liquidate", function () {
    it("should not allow open liquidate yet", async function () {
      await this.b.approve(this.bentoBox.address, e18(300))
      await this.pair.addAsset(e18(290))
      await this.a.approve(this.bentoBox.address, e18(100))
      await this.pair.addCollateral(e18(100))
      await this.pair.borrow(sansBorrowFee(e18(75)), this.alice.address)
      await this.pair.accrue()
      await this.b.connect(this.bob).approve(this.bentoBox.address, e18(25))
      expect(
        this.pair
          .connect(this.bob)
          .liquidate(
            [this.alice.address],
            [e18(20)],
            this.bob.address,
            "0x0000000000000000000000000000000000000000",
            true
          )
      ).to.be.revertedWith("all users are solvent")
    })

    it("should allow open liquidate", async function () {
      await this.b.approve(this.bentoBox.address, e18(300))
      await this.pair.addAsset(e18(290))
      await this.a.approve(this.bentoBox.address, e18(100))
      await this.pair.addCollateral(e18(100))
      await this.pair.borrow(sansBorrowFee(e18(75)), this.alice.address)
      await this.pair.accrue()
      await this.oracle.set("1100000000000000000", this.pair.address)
      await this.pair.updateExchangeRate()
      await this.b.connect(this.bob).approve(this.bentoBox.address, e18(25))
      this.pair
        .connect(this.bob)
        .liquidate(
          [this.alice.address],
          [e18(20)],
          this.bob.address,
          "0x0000000000000000000000000000000000000000",
          true
        )
    })

    it("should allow open liquidate from Bento", async function () {
      await this.b.approve(this.bentoBox.address, e18(300))
      await this.pair.addAsset(e18(290))
      await this.a.approve(this.bentoBox.address, e18(100))
      await this.pair.addCollateral(e18(100))
      await this.pair.borrow(sansBorrowFee(e18(75)), this.alice.address)
      await this.pair.accrue()
      await this.oracle.set("1100000000000000000", this.pair.address)
      await this.pair.updateExchangeRate()
      await this.b.connect(this.bob).approve(this.bentoBox.address, e18(25))
      await this.bentoBox
        .connect(this.bob)
        .deposit(this.b.address, this.bob.address, e18(25))
      this.pair
        .connect(this.bob)
        .liquidate(
          [this.alice.address],
          [e18(20)],
          this.bob.address,
          "0x0000000000000000000000000000000000000001",
          true
        )
    })

    it("should allow closed liquidate", async function () {
      await this.b.approve(this.bentoBox.address, e18(300))
      await this.pair.addAsset(e18(290))
      await this.a.approve(this.bentoBox.address, e18(100))
      await this.pair.addCollateral(e18(100))
      await this.pair.borrow(sansBorrowFee(e18(75)), this.alice.address)
      await this.pair.accrue()
      await this.b.connect(this.bob).approve(this.bentoBox.address, e18(25))
      await this.pair
        .connect(this.bob)
        .liquidate(
          [this.alice.address],
          [e18(20)],
          this.bob.address,
          this.swapper.address,
          false
        )
    })

    it("should not allow closed liquidate with invalid swapper", async function () {
      await this.b.approve(this.bentoBox.address, e18(300))
      await this.pair.addAsset(e18(290))
      await this.a.approve(this.bentoBox.address, e18(100))
      await this.pair.addCollateral(e18(100))
      await this.pair.borrow(sansBorrowFee(e18(75)), this.alice.address)
      await this.pair.accrue()
      await this.b.connect(this.bob).approve(this.bentoBox.address, e18(25))
      let invalidSwapper = await this.SushiSwapSwapper.deploy(
        this.bentoBox.address,
        this.factory.address
      )
      await invalidSwapper.deployed()
      expect(
        this.pair
          .connect(this.bob)
          .liquidate(
            [this.alice.address],
            [e18(20)],
            this.bob.address,
            invalidSwapper.address,
            false
          )
      ).to.be.revertedWith("LendingPair: Invalid swapper")
    })
  })

  describe("Batch", function () {})

  describe("Withdraw Fees", function () {})

  describe("Swipe", function () {})

  describe("Set Dev", function () {
    it("Mutates dev", async function () {
      await this.pair.setDev(this.bob.address)

      expect(await this.pair.dev()).to.be.equal(this.bob.address)
    })

    it("Emit LogDev event if dev attempts to set new dev", async function () {
      expect(this.pair.setDev(this.bob.address))
        .to.emit(this.bentoBox, "LogDev")
        .withArgs(this.bob.address)
    })
    it("Reverts if non-dev attempts to set dev", async function () {
      expect(
        this.pair.connect(this.bob).setDev(this.bob.address)
      ).to.be.revertedWith("LendingPair: Not dev")
    })
  })
})
