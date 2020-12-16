const {
  ethers: { utils },
} = require("hardhat")
const { expect, assert } = require("chai")
const {
  getBigNumber,
  sansBorrowFee,
  advanceBlock,
  ADDRESS_ZERO,
} = require("./utilities")

describe("Lending Pair", function () {
  before(async function () {
    this.WETH9 = await ethers.getContractFactory("WETH9Mock")

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

    const [alice, bob, charlie] = await ethers.getSigners()

    this.alice = alice

    this.bob = bob

    this.charlie = charlie

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
      getBigNumber(10000000)
    )
    await this.a.deployed()

    this.b = await this.RevertingERC20.deploy(
      "Token B",
      "B",
      getBigNumber(10000000)
    )
    await this.b.deployed()

    // Alice has all tokens for a and b since creator

    // Bob has 1000 b tokens
    await this.b.transfer(this.bob.address, getBigNumber(1000))
    await this.b.transfer(this.charlie.address, getBigNumber(1000))

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

    await this.a.transfer(this.sushiswappair.address, getBigNumber(5000))
    await this.b.transfer(this.sushiswappair.address, getBigNumber(5000))

    await this.sushiswappair.mint(this.alice.address)

    this.swapper = await this.SushiSwapSwapper.deploy(
      this.bentoBox.address,
      this.factory.address
    )
    await this.swapper.deployed()

    await this.lendingPair.setSwapper(this.swapper.address, true)

    this.oracle = await this.Oracle.deploy()
    await this.oracle.deployed()

    await this.oracle.set(getBigNumber(1), this.alice.address)

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

  describe("Deployment", function () {
    it("Assigns a name", async function () {
      expect(await this.pair.name()).to.be.equal(
        "Bento Med Risk Token A>Token B-TEST"
      )
    })
    it("Assigns a symbol", async function () {
      expect(await this.pair.symbol()).to.be.equal("bmA>B-TEST")
    })

    it("Assigns decimals", async function () {
      expect(await this.pair.decimals()).to.be.equal(18)
    })

    it("totalSupply is reachable", async function () {
      expect(await this.pair.totalSupply()).to.be.equal(0)
    })

    it("Assigns dev", async function () {
      expect(await this.lendingPair.dev()).to.be.equal(this.alice.address)
      expect(await this.pair.dev()).to.be.equal(ADDRESS_ZERO)
    })

    it("Assigns feeTo", async function () {
      expect(await this.lendingPair.feeTo()).to.be.equal(this.alice.address)
      expect(await this.pair.feeTo()).to.be.equal(ADDRESS_ZERO)
    })
  })

  describe("Init", function () {
    it("Reverts init for initilised pair", async function () {
      await expect(this.pair.init(this.initData)).to.be.revertedWith(
        "LendingPair: already initialized"
      )
    })
  })

  describe("Accrue", function () {
    it("should update the interest rate according to utilization", async function () {
      await this.b.approve(this.bentoBox.address, getBigNumber(700))
      await this.pair.addAsset(getBigNumber(290))
      await this.a.approve(this.bentoBox.address, getBigNumber(800))
      await this.pair.addCollateral(getBigNumber(100))
      await this.pair.borrow(
        sansBorrowFee(getBigNumber(75)),
        this.alice.address
      )
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
      await this.pair.addCollateral(getBigNumber(400))
      // 300 * 0.9 = 270
      await this.pair.borrow(
        sansBorrowFee(getBigNumber(270)),
        this.alice.address
      )

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

    it("should reset interest rate if no more assets are available", async function () {
      await this.b.approve(this.bentoBox.address, getBigNumber(900))
      await this.pair.addAsset(getBigNumber(290))
      await this.a.approve(this.bentoBox.address, getBigNumber(100))
      await this.pair.addCollateral(getBigNumber(100))
      await this.pair.borrow(
        sansBorrowFee(getBigNumber(75)),
        this.alice.address
      )
      await this.pair.accrue()
      let borrowFractionLeft = await this.pair.userBorrowFraction(
        this.alice.address
      )
      await this.pair.repay(borrowFractionLeft)
      await this.pair.removeAsset(
        await this.pair.balanceOf(this.alice.address),
        this.alice.address
      )
      await expect(this.pair.accrue()).to.emit(this.pair, "LogAccrue")
    })

    it("should emit Accrue if on target utilization", async function () {
      await this.b.approve(this.bentoBox.address, getBigNumber(900))
      await this.pair.addAsset(getBigNumber(100))
      await this.a.approve(this.bentoBox.address, getBigNumber(100))
      await this.pair.addCollateral(getBigNumber(100))
      await this.pair.borrow(
        sansBorrowFee(getBigNumber(75)),
        this.alice.address
      )
      await expect(this.pair.accrue()).to.emit(this.pair, "LogAccrue")
    })
  })

  describe("Is Solvent", function () {
    //
  })

  describe("Peek Exchange Rate", function () {
    it("Returns expected exchange rate", async function () {
      expect((await this.pair.peekExchangeRate())[1]).to.be.equal(
        getBigNumber(1)
      )
    })
  })

  describe("Update Exchange Rate", function () {
    //
  })

  describe("Add Asset", function () {
    it("should revert if MasterContract is not approved", async function () {
      await this.b.connect(this.charlie).approve(this.bentoBox.address, 300)
      await expect(
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
      await expect(this.pair.addAsset(290))
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
      await expect(
        this.pair.removeAsset(1, this.alice.address)
      ).to.be.revertedWith("BoringMath: Underflow")
    })

    it("should allow to remove asset to Bento", async function () {
      await this.b.approve(this.bentoBox.address, 300)
      await this.pair.addAsset(290)
      await this.pair.removeAssetToBento(290, this.alice.address)
    })
  })

  describe("Add Collateral", function () {
    it("should take a deposit of collateral", async function () {
      await this.a.approve(this.bentoBox.address, 300)
      await expect(this.pair.addCollateral(290))
        .to.emit(this.pair, "LogAddCollateral")
        .withArgs(this.alice.address, 290)
    })

    it("should take a deposit of collateral from Bento", async function () {
      await this.a.approve(this.bentoBox.address, 300)
      await this.bentoBox.deposit(this.a.address, this.alice.address, 290)
      await expect(this.pair.addCollateralFromBento(290))
        .to.emit(this.pair, "LogAddCollateral")
        .withArgs(this.alice.address, 290)
    })
  })
  describe("Remove Collateral", function () {
    it("should not allow a remove without collateral", async function () {
      await expect(
        this.pair.removeCollateral(1, this.alice.address)
      ).to.be.revertedWith("BoringMath: Underflow")
    })

    it("should not allow a remove of collateral if user is insolvent", async function(){
        await this.b.approve(this.bentoBox.address, getBigNumber(300))
        await this.pair.addAsset(getBigNumber(290))
        await this.a.approve(this.bentoBox.address, getBigNumber(100))
        await this.pair.addCollateral(getBigNumber(100))
        await this.pair.borrow(
          sansBorrowFee(getBigNumber(75)),
          this.alice.address
        )
        await this.pair.accrue()
        await expect(
          this.pair.removeCollateral(getBigNumber(100), this.alice.address)
        ).to.be.revertedWith("LendingPair: user insolvent")
    })

    it("should not allow a remove of collateral to Bento if user is insolvent", async function(){
      await this.b.approve(this.bentoBox.address, getBigNumber(300))
      await this.pair.addAsset(getBigNumber(290))
      await this.a.approve(this.bentoBox.address, getBigNumber(100))
      await this.pair.addCollateral(getBigNumber(100))
      await this.pair.borrow(
        sansBorrowFee(getBigNumber(75)),
        this.alice.address
      )
      await expect(
        this.pair.removeCollateralToBento(getBigNumber(100), this.alice.address)
      ).to.be.revertedWith("LendingPair: user insolvent")
  })

    it("should allow to remove collateral to Bento", async function () {
      await this.a.approve(this.bentoBox.address, 300)
      await this.pair.addCollateral(290)
      await this.pair.removeCollateralToBento(290, this.alice.address)
    })

    it("should allow to partial withdrawal of collateral", async function () {
      await this.b.approve(this.bentoBox.address, getBigNumber(700))
      await this.pair.addAsset(getBigNumber(290))
      await this.a.approve(this.bentoBox.address, getBigNumber(100))
      await this.pair.addCollateral(getBigNumber(100))
      await this.pair.borrow(
        sansBorrowFee(getBigNumber(75)),
        this.alice.address
      )
      await this.pair.accrue()
      await this.oracle.set("1100000000000000000", this.pair.address)
      await this.pair.updateExchangeRate()
      let borrowFractionLeft = await this.pair.userBorrowFraction(
        this.alice.address
      )
      await this.pair.repay(borrowFractionLeft)
      await this.pair.removeCollateral(getBigNumber(60), this.alice.address)
    })

    it("should allow to full withdrawal of collateral", async function () {
      await this.b.approve(this.bentoBox.address, getBigNumber(700))
      await this.pair.addAsset(getBigNumber(290))
      await this.a.approve(this.bentoBox.address, getBigNumber(100))
      await this.pair.addCollateral(getBigNumber(100))
      await this.pair.borrow(
        sansBorrowFee(getBigNumber(75)),
        this.alice.address
      )
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
      await expect(this.pair.borrow(1, this.alice.address)).to.be.revertedWith(
        "BoringMath: Underflow"
      )
    })

    it("should not allow borrowing without any collateral", async function () {
      await this.b.approve(this.bentoBox.address, 300)
      await this.pair.addAsset(290)
      await expect(this.pair.borrow(1, this.alice.address)).to.be.revertedWith(
        "user insolvent"
      )
    })

    it("should allow borrowing to Bento", async function () {
      await this.b.approve(this.bentoBox.address, getBigNumber(300))
      await this.pair.addAsset(getBigNumber(290))
      await this.a.approve(this.bentoBox.address, getBigNumber(100))
      await this.pair.addCollateral(getBigNumber(100))
      await expect(
        this.pair.borrowToBento(
          sansBorrowFee(getBigNumber(75)),
          this.alice.address
        )
      )
        .to.emit(this.pair, "LogAddBorrow")
        .withArgs(
          this.alice.address,
          "74999999999999999999",
          "74999999999999999999"
        )
    })

    it("should allow borrowing with collateral up to 75%", async function () {
      await this.b.approve(this.bentoBox.address, getBigNumber(300))
      await this.pair.addAsset(getBigNumber(290))
      await this.a.approve(this.bentoBox.address, getBigNumber(100))
      await this.pair.addCollateral(getBigNumber(100))
      await expect(
        this.pair.borrow(sansBorrowFee(getBigNumber(75)), this.alice.address)
      )
        .to.emit(this.pair, "LogAddBorrow")
        .withArgs(
          this.alice.address,
          "74999999999999999999",
          "74999999999999999999"
        )
    })

    it("should not allow any more borrowing", async function () {
      await this.b.approve(this.bentoBox.address, getBigNumber(300))
      await this.pair.addAsset(getBigNumber(290))
      await this.a.approve(this.bentoBox.address, getBigNumber(100))
      await this.pair.addCollateral(getBigNumber(100))
      await this.pair.borrow(
        sansBorrowFee(getBigNumber(75)),
        this.alice.address
      )
      await expect(
        this.pair.borrow(100, this.alice.address)
      ).to.be.revertedWith("user insolvent")
    })

    it("should not allow any more borrowing to Bento", async function () {
      await this.b.approve(this.bentoBox.address, getBigNumber(300))
      await this.pair.addAsset(getBigNumber(290))
      await this.a.approve(this.bentoBox.address, getBigNumber(100))
      await this.pair.addCollateral(getBigNumber(100))
      await expect(
        this.pair.borrowToBento(getBigNumber(80), this.alice.address)
      ).to.be.revertedWith("user insolvent")
    })

    it("should report insolvency due to interest", async function () {
      await this.b.approve(this.bentoBox.address, getBigNumber(300))
      await this.pair.addAsset(getBigNumber(290))
      await this.a.approve(this.bentoBox.address, getBigNumber(100))
      await this.pair.addCollateral(getBigNumber(100))
      await this.pair.borrow(
        sansBorrowFee(getBigNumber(75)),
        this.alice.address
      )
      await this.pair.accrue()
      expect(await this.pair.isSolvent(this.alice.address, false)).to.be.false
    })

    it("should not report open insolvency due to interest", async function () {
      await this.b.approve(this.bentoBox.address, getBigNumber(300))
      await this.pair.addAsset(getBigNumber(290))
      await this.a.approve(this.bentoBox.address, getBigNumber(100))
      await this.pair.addCollateral(getBigNumber(100))
      await this.pair.borrow(
        sansBorrowFee(getBigNumber(75)),
        this.alice.address
      )
      await this.pair.accrue()
      expect(await this.pair.isSolvent(this.alice.address, true)).to.be.true
    })

    it("should report open insolvency after oracle rate is updated", async function () {
      await this.b.approve(this.bentoBox.address, getBigNumber(300))
      await this.pair.addAsset(getBigNumber(290))
      await this.a.approve(this.bentoBox.address, getBigNumber(100))
      await this.pair.addCollateral(getBigNumber(100))
      await this.pair.borrow(
        sansBorrowFee(getBigNumber(75)),
        this.alice.address
      )
      await this.pair.accrue()
      await this.oracle.set("1100000000000000000", this.pair.address)
      await this.pair.updateExchangeRate()
      expect(await this.pair.isSolvent(this.alice.address, true)).to.be.false
    })
  })

  describe("Repay", function () {
    it("should allow to repay", async function () {
      await this.b.approve(this.bentoBox.address, getBigNumber(700))
      await this.pair.addAsset(getBigNumber(290))
      await this.a.approve(this.bentoBox.address, getBigNumber(100))
      await this.pair.addCollateral(getBigNumber(100))
      await this.pair.borrow(
        sansBorrowFee(getBigNumber(75)),
        this.alice.address
      )
      await this.pair.accrue()
      await this.oracle.set("1100000000000000000", this.pair.address)
      await this.pair.updateExchangeRate()
      await this.pair.repay(getBigNumber(50))
    })

    it("should allow to repay from Bento", async function () {
      await this.b.approve(this.bentoBox.address, getBigNumber(700))
      await this.pair.addAsset(getBigNumber(290))
      await this.a.approve(this.bentoBox.address, getBigNumber(100))
      await this.pair.addCollateral(getBigNumber(100))
      await this.pair.borrow(
        sansBorrowFee(getBigNumber(75)),
        this.alice.address
      )
      await this.bentoBox.deposit(
        this.b.address,
        this.alice.address,
        getBigNumber(100)
      )
      await this.pair.repayFromBento(getBigNumber(50))
    })

    it("should allow full repayment", async function () {
      await this.b.approve(this.bentoBox.address, getBigNumber(900))
      await this.pair.addAsset(getBigNumber(290))
      await this.a.approve(this.bentoBox.address, getBigNumber(100))
      await this.pair.addCollateral(getBigNumber(100))
      await this.pair.borrow(
        sansBorrowFee(getBigNumber(75)),
        this.alice.address
      )
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
    it("should not allow invalid swapper", async function(){
        let invalidSwapper = await this.SushiSwapSwapper.deploy(
          this.bentoBox.address,
          this.factory.address
        )
        await invalidSwapper.deployed()
        await expect(
          this.pair
            .short(
              invalidSwapper.address,
              getBigNumber(20),
              getBigNumber(20)
            )
        ).to.be.revertedWith("LendingPair: Invalid swapper")
    })
    it("should not allow shorting if it does not return enough", async function () {
      await this.a.approve(this.bentoBox.address, getBigNumber(100))
      await this.pair.addCollateral(getBigNumber(100))
      await this.b
        .connect(this.bob)
        .approve(this.bentoBox.address, getBigNumber(1000))
      await this.pair.connect(this.bob).addAsset(getBigNumber(1000))
      await expect(
        this.pair.short(
          this.swapper.address,
          getBigNumber(200),
          getBigNumber(200)
        )
      ).to.be.revertedWith("SushiSwapSwapper: return not enough")
    })

    it("should not allow shorting into insolvency", async function () {
      await this.a.approve(this.bentoBox.address, getBigNumber(100))
      await this.pair.addCollateral(getBigNumber(100))
      await this.b
        .connect(this.bob)
        .approve(this.bentoBox.address, getBigNumber(1000))
      await this.pair.connect(this.bob).addAsset(getBigNumber(1000))
      await expect(
        this.pair.short(
          this.swapper.address,
          getBigNumber(300),
          getBigNumber(200)
        )
      ).to.be.revertedWith("user insolvent")
    })

    it("should allow shorting", async function () {
      await this.a.approve(this.bentoBox.address, getBigNumber(100))
      await this.pair.addCollateral(getBigNumber(100))
      await this.b
        .connect(this.bob)
        .approve(this.bentoBox.address, getBigNumber(1000))
      await this.pair.connect(this.bob).addAsset(getBigNumber(1000))
      await this.pair.short(
        this.swapper.address,
        getBigNumber(250),
        getBigNumber(230)
      )
    })

    it("should limit asset availability after shorting", async function () {
      await this.a.approve(this.bentoBox.address, getBigNumber(100))
      await this.pair.addCollateral(getBigNumber(100))
      await this.b
        .connect(this.bob)
        .approve(this.bentoBox.address, getBigNumber(1000))
      await this.pair.connect(this.bob).addAsset(getBigNumber(1000))
      await this.pair.short(
        this.swapper.address,
        getBigNumber(250),
        getBigNumber(230)
      )
      const bobBal = await this.pair.balanceOf(this.bob.address)
      expect(bobBal).to.be.equal(getBigNumber(1000))
      // virtual balance of 1000 is higher than the contract has
      await expect(
        this.pair.connect(this.bob).removeAsset(bobBal, this.bob.address)
      ).to.be.revertedWith("BoringMath: Underflow")
      // 750 still too much, as 250 should be kept to rewind all shorts
      await expect(
        this.pair
          .connect(this.bob)
          .removeAsset(getBigNumber(750), this.bob.address)
      ).to.be.revertedWith("BoringMath: Underflow")
      await this.pair
        .connect(this.bob)
        .removeAsset(getBigNumber(499), this.bob.address)
    })
  })

  describe("Unwind", function () {
    it("should not allow invalid swapper", async function(){
      let invalidSwapper = await this.SushiSwapSwapper.deploy(
        this.bentoBox.address,
        this.factory.address
      )
      await invalidSwapper.deployed()
      await expect(
        this.pair
          .unwind(
            invalidSwapper.address,
            getBigNumber(20),
            getBigNumber(20)
          )
      ).to.be.revertedWith("LendingPair: Invalid swapper")
  })
    it("should allow unwinding the short", async function () {
      await this.a.approve(this.bentoBox.address, getBigNumber(100))
      await this.pair.addCollateral(getBigNumber(100))
      await this.b
        .connect(this.bob)
        .approve(this.bentoBox.address, getBigNumber(1000))
      await this.pair.connect(this.bob).addAsset(getBigNumber(1000))
      await this.pair.short(
        this.swapper.address,
        getBigNumber(250),
        getBigNumber(230)
      )
      await this.pair.unwind(
        this.swapper.address,
        getBigNumber(250),
        getBigNumber(337)
      )
    })
  })

  describe("Liquidate", function () {
    it("should not allow open liquidate yet", async function () {
      await this.b.approve(this.bentoBox.address, getBigNumber(300))
      await this.pair.addAsset(getBigNumber(290))
      await this.a.approve(this.bentoBox.address, getBigNumber(100))
      await this.pair.addCollateral(getBigNumber(100))
      await this.pair.borrow(
        sansBorrowFee(getBigNumber(75)),
        this.alice.address
      )
      await this.pair.accrue()
      await this.b
        .connect(this.bob)
        .approve(this.bentoBox.address, getBigNumber(25))
      await expect(
        this.pair
          .connect(this.bob)
          .liquidate(
            [this.alice.address],
            [getBigNumber(20)],
            this.bob.address,
            "0x0000000000000000000000000000000000000000",
            true
          )
      ).to.be.revertedWith("all users are solvent")
    })

    it("should allow open liquidate", async function () {
      await this.b.approve(this.bentoBox.address, getBigNumber(300))
      await this.pair.addAsset(getBigNumber(290))
      await this.a.approve(this.bentoBox.address, getBigNumber(100))
      await this.pair.addCollateral(getBigNumber(100))
      await this.pair.borrow(
        sansBorrowFee(getBigNumber(75)),
        this.alice.address
      )
      await this.pair.accrue()
      await this.oracle.set("1100000000000000000", this.pair.address)
      await this.pair.updateExchangeRate()
      await this.b
        .connect(this.bob)
        .approve(this.bentoBox.address, getBigNumber(25))
      this.pair
        .connect(this.bob)
        .liquidate(
          [this.alice.address],
          [getBigNumber(20)],
          this.bob.address,
          "0x0000000000000000000000000000000000000000",
          true
        )
    })

    it("should allow open liquidate with swapper", async function () {
      await this.b.approve(this.bentoBox.address, getBigNumber(300))
      await this.pair.addAsset(getBigNumber(290))
      await this.a.approve(this.bentoBox.address, getBigNumber(100))
      await this.pair.addCollateral(getBigNumber(100))
      await this.pair.borrow(
        sansBorrowFee(getBigNumber(75)),
        this.alice.address
      )
      await this.pair.accrue()
      await this.oracle.set("1100000000000000000", this.pair.address)
      await this.a.transfer(this.sushiswappair.address, getBigNumber(500))
      await this.sushiswappair.sync()
      await this.pair.updateExchangeRate()
      await expect(this.pair
        .connect(this.bob)
        .liquidate(
          [this.alice.address],
          [getBigNumber(20)],
          this.bob.address,
          this.swapper.address,
          true
        )).to.emit(this.pair, "LogAddAsset")
    })

    it("should allow open liquidate from Bento", async function () {
      await this.b.approve(this.bentoBox.address, getBigNumber(300))
      await this.pair.addAsset(getBigNumber(290))
      await this.a.approve(this.bentoBox.address, getBigNumber(100))
      await this.pair.addCollateral(getBigNumber(100))
      await this.pair.borrow(
        sansBorrowFee(getBigNumber(75)),
        this.alice.address
      )
      await this.pair.accrue()
      await this.oracle.set("1100000000000000000", this.pair.address)
      await this.pair.updateExchangeRate()
      await this.b
        .connect(this.bob)
        .approve(this.bentoBox.address, getBigNumber(25))
      await this.bentoBox
        .connect(this.bob)
        .deposit(this.b.address, this.bob.address, getBigNumber(25))
      this.pair
        .connect(this.bob)
        .liquidate(
          [this.alice.address],
          [getBigNumber(20)],
          this.bob.address,
          "0x0000000000000000000000000000000000000001",
          true
        )
    })

    it("should allow closed liquidate", async function () {
      await this.b.approve(this.bentoBox.address, getBigNumber(300))
      await this.pair.addAsset(getBigNumber(290))
      await this.a.approve(this.bentoBox.address, getBigNumber(100))
      await this.pair.addCollateral(getBigNumber(100))
      await this.pair.borrow(
        sansBorrowFee(getBigNumber(75)),
        this.alice.address
      )
      await this.pair.accrue()
      await this.b
        .connect(this.bob)
        .approve(this.bentoBox.address, getBigNumber(25))
      await this.pair
        .connect(this.bob)
        .liquidate(
          [this.alice.address],
          [getBigNumber(20)],
          this.bob.address,
          this.swapper.address,
          false
        )
    })

    it("should not allow closed liquidate with invalid swapper", async function () {
      await this.b.approve(this.bentoBox.address, getBigNumber(300))
      await this.pair.addAsset(getBigNumber(290))
      await this.a.approve(this.bentoBox.address, getBigNumber(100))
      await this.pair.addCollateral(getBigNumber(100))
      await this.pair.borrow(
        sansBorrowFee(getBigNumber(75)),
        this.alice.address
      )
      await this.pair.accrue()
      await this.b
        .connect(this.bob)
        .approve(this.bentoBox.address, getBigNumber(25))
      let invalidSwapper = await this.SushiSwapSwapper.deploy(
        this.bentoBox.address,
        this.factory.address
      )
      await invalidSwapper.deployed()
      await expect(
        this.pair
          .connect(this.bob)
          .liquidate(
            [this.alice.address],
            [getBigNumber(20)],
            this.bob.address,
            invalidSwapper.address,
            false
          )
      ).to.be.revertedWith("LendingPair: Invalid swapper")
    })
  })

  describe("Batch", function () {})

  describe("Swipe", function () {
    it("Reverts if caller is not the owner", async function () {
      await expect(
        this.pair
          .connect(this.bob)
          .swipe(this.a.address, { from: this.bob.address })
      ).to.be.revertedWith("LendingPair: caller is not the owner")
    })
    it("allows the swiping of ETH", async function(){
      await this.pair.addAsset(0, { value: 2 })
      await this.pair.swipe(ADDRESS_ZERO)
    })

    it("allows the swiping of WETH", async function(){
      await this.weth9.deposit({ value: 200 })
      await this.weth9.transfer(this.pair.address, 10)
      await this.pair.swipe(this.weth9.address)
    })

    it("allows the swiping of excess asset", async function(){
      await this.b.transfer(this.pair.address, getBigNumber(1))
      await this.pair.swipe(this.b.address)
    })

  })

  describe("Withdraw Fees", function () {
    it("should allow to withdraw fees", async function () {
      await this.b.approve(this.bentoBox.address, getBigNumber(700))
      await this.pair.addAsset(getBigNumber(290))
      await this.a.approve(this.bentoBox.address, getBigNumber(100))
      await this.pair.addCollateral(getBigNumber(100))
      await this.pair.borrow(
        sansBorrowFee(getBigNumber(75)),
        this.alice.address
      )
      await this.pair.repay(getBigNumber(50))
      await expect(this.pair.withdrawFees()).to.emit(this.pair, "LogWithdrawFees")
    })
    
    it("should emit events even if dev fees are empty", async function () {
      await this.b.approve(this.bentoBox.address, getBigNumber(700))
      await this.pair.addAsset(getBigNumber(290))
      await this.a.approve(this.bentoBox.address, getBigNumber(100))
      await this.pair.addCollateral(getBigNumber(100))
      await this.pair.borrow(
        sansBorrowFee(getBigNumber(75)),
        this.alice.address
      )
      let borrowFractionLeft = await this.pair.userBorrowFraction(
        this.alice.address
      )
      await this.pair.repay(borrowFractionLeft)
      await this.pair.withdrawFees()
      await expect(this.pair.withdrawFees()).to.emit(this.pair, "LogWithdrawFees")
    })
    
  })

  describe("Batch", function () {
    it("Batches calls with revertOnFail true", async function () {
      await this.b.approve(this.bentoBox.address, 2)

      const addAsset = this.pair.interface.encodeFunctionData("addAsset", [1])

      const accrue = this.pair.interface.encodeFunctionData("accrue", [])

      await this.pair.batch([addAsset, accrue, accrue], true)

      expect(await this.pair.balanceOf(this.alice.address)).to.be.equal(1)
    })

    it("Batches calls with revertOnFail false", async function () {
      await this.b.approve(this.bentoBox.address, 2)

      const addAsset = this.pair.interface.encodeFunctionData("addAsset", [1])

      const accrue = this.pair.interface.encodeFunctionData("accrue", [])

      await this.pair.batch([addAsset, accrue, accrue], false)

      expect(await this.pair.balanceOf(this.alice.address)).to.be.equal(1)
    })

    it("Does not revert on fail if revertOnFail is set to false", async function () {
      const addAsset = this.pair.interface.encodeFunctionData("addAsset", [1])

      const accrue = this.pair.interface.encodeFunctionData("accrue", [])

      await this.pair.batch([addAsset, accrue, accrue], false)

      expect(await this.pair.balanceOf(this.alice.address)).to.be.equal(0)
    })

    it("Reverts on fail if revertOnFail is set to true", async function () {
      const addAsset = this.pair.interface.encodeFunctionData("addAsset", [1])

      const accrue = this.pair.interface.encodeFunctionData("accrue", [])

      await expect(this.pair.batch([addAsset, accrue, accrue], true)).to.be
        .reverted
    })
  })

  describe("Set Dev", function () {
    it("Mutates dev", async function () {
      await this.lendingPair.setDev(this.bob.address)
      expect(await this.lendingPair.dev()).to.be.equal(this.bob.address)
      expect(await this.pair.dev()).to.be.equal(ADDRESS_ZERO)
    })

    it("Emit LogDev event if dev attempts to set dev", async function () {
      await expect(this.lendingPair.setDev(this.bob.address))
        .to.emit(this.lendingPair, "LogDev")
        .withArgs(this.bob.address)
    })
    it("Reverts if non-dev attempts to set dev", async function () {
      await expect(
        this.lendingPair.connect(this.bob).setDev(this.bob.address)
      ).to.be.revertedWith("LendingPair: Not dev")
      await expect(
        this.pair.connect(this.bob).setDev(this.bob.address)
      ).to.be.revertedWith("LendingPair: Not dev")
    })
  })

  describe("Set Fee To", function () {
    it("Mutates fee to", async function () {
      await this.lendingPair.setFeeTo(this.bob.address)
      expect(await this.lendingPair.feeTo()).to.be.equal(this.bob.address)
      expect(await this.pair.feeTo()).to.be.equal(ADDRESS_ZERO)
    })

    it("Emit LogFeeTo event if dev attempts to set fee to", async function () {
      await expect(this.lendingPair.setFeeTo(this.bob.address))
        .to.emit(this.lendingPair, "LogFeeTo")
        .withArgs(this.bob.address)
    })

    it("Reverts if non-owner attempts to set fee to", async function () {
      await expect(
        this.lendingPair.connect(this.bob).setFeeTo(this.bob.address)
      ).to.be.revertedWith("caller is not the owner")
      await expect(
        this.pair.connect(this.bob).setFeeTo(this.bob.address)
      ).to.be.revertedWith("caller is not the owner")
    })
  })
})
