const { ethers, deployments } = require("hardhat")
const { expect, assert } = require("chai")
const { getApprovalDigest, prepare, ADDRESS_ZERO, getBigNumber, sansSafetyAmount, setMasterContractApproval, deploy } = require("./utilities")
const { ecsign } = require("ethereumjs-util")

describe("BentoBoxPlus", function () {
  before(async function () {
    await prepare(this, ["ERC20Mock", 'FlashLoanerMock', "ReturnFalseERC20Mock", "RevertingERC20Mock"])
  })

  beforeEach(async function () {
    await deployments.fixture()

    this.weth9 = await ethers.getContract("WETH9Mock")

    this.bentoBox = await ethers.getContract("BentoBoxPlus")

    await deploy(this, [['flashLoaner', this.FlashLoanerMock]])

    this.erc20 = await this.ERC20Mock.deploy(10000000)
    await this.erc20.deployed()

    this.a = await this.ReturnFalseERC20Mock.deploy("Token A", "A", getBigNumber(10))

    await this.a.deployed()

    this.b = await this.RevertingERC20Mock.deploy("Token B", "B", getBigNumber(10))

    await this.b.deployed()

    // Alice has all tokens for a and b since creator

    // await this.a.transfer(this.alice.address, parseUnits("1000"));

    // Bob has 1000 b tokens
    await this.b.transfer(this.bob.address, getBigNumber(1))

    this.lendingPair = await ethers.getContract("LendingPair")

    this.peggedOracle = await ethers.getContract("PeggedOracle")

  })

  describe("Deploy", function () {
  it("Emits LogDeploy event with correct arguments", async function () {
    const data = await this.lendingPair.getInitData(
      this.a.address,
         this.b.address,
        this.peggedOracle.address,
       await this.peggedOracle.getDataParameter("0")
      )

    await expect(this.bentoBox.deploy(this.lendingPair.address, data))
        .to.emit(this.bentoBox, "LogDeploy")
        .withArgs(
           this.lendingPair.address,
           data,
           "0x61c36a8d610163660E21a8b7359e1Cac0C9133e1"
        )
     })
   })

  describe('Conversion', function() {
    it('Should convert Shares to Amounts', async function () {
      expect(await this.bentoBox.toShare(this.a.address, 1)).to.be.equal(1)
    })
    it('Should convert amount to shares', async function () {
      expect(await this.bentoBox.toAmount(this.a.address, 1)).to.be.equal(1)
    })
  })
  describe("Deposit", function () {
    it("Reverts with to address zero", async function () {
      await expect(this.bentoBox.deposit(this.a.address, this.alice.address, "0x0000000000000000000000000000000000000000", 1, 0)).to.be.revertedWith(
        "BentoBox: to not set"
      )
    })

    /*
    it("Reverts with from address BentoBox", async function () {
      await expect(this.bentoBox.deposit(this.a.address, this.bentoBox.address, this.alice.address, 1, 0)).to.be.revertedWith(
        "BentoBox: to not set"
      )
    })
    implement with batching
    */

    it("Reverts without approval", async function () {
      await expect(this.bentoBox.deposit(this.a.address, this.alice.address, this.alice.address, 1, 0)).to.be.revertedWith("BoringERC20: TransferFrom ")

      expect(await this.bentoBox.balanceOf(this.a.address, this.alice.address)).to.be.equal(0)
    })

    it("Mutates balanceOf correctly", async function () {
      await this.a.approve(this.bentoBox.address, 1)

      await this.bentoBox.deposit(this.a.address, this.alice.address, this.alice.address, 1, 0)

      expect(await this.bentoBox.balanceOf(this.a.address, this.alice.address)).to.be.equal(1)
    })

    it("Mutates balanceOf for BentoBox and WETH correctly", async function () {
      await this.weth9.connect(this.alice).deposit( {
        value: 1,
      })
      await this.bentoBox.connect(this.bob).deposit(ADDRESS_ZERO, this.bob.address, this.bob.address, 1, 0, {
        from: this.bob.address,
        value: 1,
      })

      expect(await this.weth9.balanceOf(this.bentoBox.address), "BentoBox should hold WETH").to.be.equal(1)

      expect(await this.bentoBox.balanceOf(this.weth9.address, this.bob.address), "bob should have weth").to.be.equal(1)
    })

    it("Reverts if TotalSupply is Zero", async function () {
      
      await expect(this.bentoBox.connect(this.bob).deposit(ADDRESS_ZERO, this.bob.address, this.bob.address, 1, 0, {
        from: this.bob.address,
        value: 1,
      })).to.be.revertedWith("BentoBox: No tokens")
    })

    it("Mutates balanceOf and totalSupply for two deposits correctly", async function () {
      await this.a.approve(this.bentoBox.address, 3)

      await this.bentoBox.deposit(this.a.address, this.alice.address, this.alice.address, 1, 0)

      await this.bentoBox.deposit(this.a.address, this.alice.address, this.alice.address, 2, 0)

      expect(await this.bentoBox.balanceOf(this.a.address, this.alice.address), "incorrect amount calculation").to.be.equal(3)

      expect((await this.bentoBox.totals(this.a.address)).amount, "incorrect total amount").to.be.equal(3)
    })

    it("Emits LogDeposit event with correct arguments", async function () {
      await this.a.approve(this.bentoBox.address, 1)

      await expect(this.bentoBox.deposit(this.a.address, this.alice.address, this.alice.address, 1, 0))
        .to.emit(this.bentoBox, "LogDeposit")
        .withArgs(this.a.address, this.alice.address, this.alice.address, 1, 1)
    })
  })

  describe("Deposit Share", function (){
    it("allows for deposit of Share", async function (){
      await this.a.approve(this.bentoBox.address, 1)

      await this.bentoBox.deposit(this.a.address, this.alice.address, this.alice.address, 0, 1)

      expect(await this.bentoBox.balanceOf(this.a.address, this.alice.address)).to.be.equal(1)
    })
  })

  describe("Deposit To", function () {

    it("Mutates balanceOf and totalSupply correctly", async function () {
      await this.a.approve(this.bentoBox.address, 1)

      await this.bentoBox.deposit(this.a.address, this.alice.address, this.bob.address, 1, 0)

      expect(await this.bentoBox.balanceOf(this.a.address, this.alice.address), "incorrect amount calculation").to.be.equal(0)

      expect(await this.bentoBox.balanceOf(this.a.address, this.bob.address), "incorrect amount calculation").to.be.equal(1)

      expect((await this.bentoBox.totals(this.a.address)).amount, "incorrect total amount").to.be.equal(1)
    })
  })

  // TODO: Cover these
  describe("Deposit With Permit", function () {
    // tested in BoringSolidity
  })

  describe("Withdraw", function () {
    it("Reverts when address zero is passed as to argument", async function () {
      await expect(this.bentoBox.withdraw(this.a.address, this.alice.address, "0x0000000000000000000000000000000000000000", 1, 0)).to.be.revertedWith(
        "BentoBox: to not set"
      )
    })

    it("Reverts when attempting to withdraw below 10000 shares", async function () {
      await this.a.approve(this.bentoBox.address, 10000)

      await this.bentoBox.deposit(this.a.address, this.alice.address, this.alice.address, 0, 10000)

      await expect(this.bentoBox.withdraw(this.a.address, this.alice.address, this.alice.address, 0, 2)).to.be.revertedWith("BentoBox: cannot empty")
    })

    it("Reverts when attempting to withdraw larger amount than available", async function () {
      await this.a.approve(this.bentoBox.address, getBigNumber(1))

      await this.bentoBox.deposit(this.a.address, this.alice.address, this.alice.address, getBigNumber(1), 0)

      await expect(this.bentoBox.withdraw(this.a.address, this.alice.address, this.alice.address, getBigNumber(2), 0)).to.be.revertedWith("BoringMath: Underflow")
    })

    it("Mutates balanceOf of Token and BentoBox correctly", async function () {
      await this.a.approve(this.bentoBox.address, getBigNumber(1))

      await this.bentoBox.deposit(this.a.address, this.alice.address, this.alice.address, getBigNumber(1), 0)
      
      await this.bentoBox.withdraw(this.a.address, this.alice.address, this.alice.address, sansSafetyAmount(getBigNumber(1)), 0)

      expect(await this.a.balanceOf(this.alice.address), "alice should have all of their tokens back").to.equal(sansSafetyAmount(getBigNumber(10)))

      expect(await this.bentoBox.balanceOf(this.a.address, this.alice.address), "token should be withdrawn").to.equal(100000)
    })

    it("Mutates balanceOf on BentoBox for WETH correctly", async function () {
      await this.weth9.connect(this.alice).deposit( {
        value: 1,
      })
      await this.bentoBox.connect(this.bob).deposit(ADDRESS_ZERO, this.bob.address, this.bob.address, getBigNumber(1), 0, {
        from: this.bob.address,
        value: getBigNumber(1),
      })

      await this.bentoBox.connect(this.bob).withdraw(ADDRESS_ZERO, this.bob.address, this.bob.address, sansSafetyAmount(getBigNumber(1)), 0 ,{
        from: this.bob.address,
      })

      expect(await this.bentoBox.balanceOf(this.weth9.address, this.bob.address), "token should be withdrawn").to.be.equal(100000)
    })

    it("Emits LogWithdraw event with expected arguments", async function () {
      await this.a.approve(this.bentoBox.address, getBigNumber(1))

      this.bentoBox.deposit(this.a.address, this.alice.address, this.alice.address, getBigNumber(1), 0)

      await expect(this.bentoBox.withdraw(this.a.address, this.alice.address, this.alice.address, 1, 0))
        .to.emit(this.bentoBox, "LogWithdraw")
        .withArgs(this.a.address, this.alice.address, this.alice.address, 1, 1)
    })
  })

  describe("Withdraw From", function () {
    it("Mutates bentoBox balanceOf and token balanceOf for from and to correctly", async function () {
      await this.a.approve(this.bentoBox.address, getBigNumber(1))

      await this.bentoBox.deposit(this.a.address, this.alice.address, this.alice.address, getBigNumber(1), 0)

      await this.bentoBox.withdraw(this.a.address, this.alice.address, this.bob.address, 1, 0)

      expect(await this.a.balanceOf(this.bob.address), "bob should have received their tokens").to.be.equal(1)

    })
  })

  describe("Transfer", function () {
    it("Reverts when address zero is given as to argument", async function () {
      await expect(this.bentoBox.transfer(this.a.address, this.alice.address, "0x0000000000000000000000000000000000000000", 1)).to.be.revertedWith(
        "BentoBox: to not set"
      )
    })

    it("Reverts when attempting to transfer larger amount than available", async function () {
      await expect(
        this.bentoBox.connect(this.bob).transfer(this.a.address, this.bob.address, this.alice.address, 1)
      ).to.be.revertedWith("BoringMath: Underflow")
    })

    it("Mutates balanceOf for from and to correctly", async function () {
      await this.a.approve(this.bentoBox.address, 1)

      await this.bentoBox.deposit(this.a.address, this.alice.address, this.alice.address, 1, 0)

      await this.bentoBox.transfer(this.a.address, this.alice.address, this.bob.address, 1)

      expect(await this.bentoBox.balanceOf(this.a.address, this.alice.address), "token should be transferred").to.be.equal(0)

      expect(await this.bentoBox.balanceOf(this.a.address, this.bob.address), "token should be transferred").to.be.equal(1)
    })


    it("Emits LogTransfer event with expected arguments", async function () {
      await this.a.approve(this.bentoBox.address, 1)

      this.bentoBox.deposit(this.a.address, this.alice.address, this.alice.address, 1, 0)

      await expect(this.bentoBox.transfer(this.a.address, this.alice.address, this.bob.address, 1))
        .to.emit(this.bentoBox, "LogTransfer")
        .withArgs(this.a.address, this.alice.address, this.bob.address, 1)
    })
  })

  describe("Transfer Multiple", function () {
    it("Reverts if first to argument is address zero", async function () {
      await expect(this.bentoBox.transferMultiple(this.a.address, this.alice.address, ["0x0000000000000000000000000000000000000000"], [1])).to.be.reverted
    })

    it("should allow transfer multiple from alice to bob and carol", async function () {
      await this.a.approve(this.bentoBox.address, 2)

      await this.bentoBox.deposit(this.a.address, this.alice.address, this.alice.address, 2, 0)

      await this.bentoBox.transferMultiple(this.a.address, this.alice.address, [this.bob.address, this.carol.address], [1, 1], { from: this.alice.address })

      assert.equal(await this.bentoBox.balanceOf(this.a.address, this.alice.address), 0, "token should be transferred")

      assert.equal(await this.bentoBox.balanceOf(this.a.address, this.bob.address), 1, "token should be transferred")

      assert.equal(await this.bentoBox.balanceOf(this.a.address, this.carol.address), 1, "token should be transferred")
    })
  })

  describe("Skim", function () {
    it("Skims tokens to from address", async function () {
      await this.a.transfer(this.bentoBox.address, 1)

      expect(await this.bentoBox.balanceOf(this.a.address, this.bob.address), "bob should have no tokens").to.be.equal(0)

      await this.bentoBox.connect(this.bob).deposit(this.a.address, this.bentoBox.address, this.bob.address, 1, 0)

      expect(await this.bentoBox.balanceOf(this.a.address, this.bob.address), "bob should have tokens").to.be.equal(1)
    })

    it("Be benevolent", async function () {
      await this.a.transfer(this.bentoBox.address, 1)

      expect(await this.bentoBox.balanceOf(this.a.address, this.bob.address), "bob should have no tokens").to.be.equal(0)

      await this.bentoBox.connect(this.bob).deposit(this.a.address, this.bentoBox.address, ADDRESS_ZERO, 1, 0)

      expect((await this.bentoBox.totals(this.a.address)).amount, "total amount should increase").to.be.equal(1)
    })

    it("Emits LogDeposit event with expected arguments", async function () {
      await this.a.transfer(this.bentoBox.address, 1)

      await expect(this.bentoBox.connect(this.bob).deposit(this.a.address, this.bentoBox.address, this.bob.address, 1, 0))
        .to.emit(this.bentoBox, "LogDeposit")
        .withArgs(this.a.address, this.bentoBox.address, this.bob.address, 1, 1)
    })
  })

  describe('modifier allowed', function (){
    it("does not allow functions if MasterContract does not exist", async function () {
      
      await this.a.approve(this.bentoBox.address, 1)

      await expect(this.bentoBox.connect(this.bob).deposit(this.a.address, this.alice.address, this.alice.address, 1, 0)).to.be.revertedWith(
        "BentoBox: no masterContract"
      )
    })

    it("does not allow clone contract calls if MasterContract is not approved", async function () {
      const data = await this.lendingPair.getInitData(
        this.a.address,
        this.b.address,
        this.peggedOracle.address,
       await this.peggedOracle.getDataParameter("0")
      )

      let deployTx = await this.bentoBox.deploy(this.lendingPair.address, data)
      const cloneAddress = (await deployTx.wait()).events[0].args.cloneAddress
      let pair = await this.lendingPair.attach(cloneAddress)

      await this.a.approve(this.bentoBox.address, 1)

      await expect(pair.addAsset(1, this.bob.address)).to.be.revertedWith(
        "BentoBox: Transfer not approved"
      )
    })

    it("allow clone contract calls if MasterContract is approved", async function () {
      await this.bentoBox.whitelistMasterContract(this.lendingPair.address, true)
      await setMasterContractApproval(this.bentoBox, this.alice, this.alice, '', this.lendingPair.address, true, true)


      const data = await this.lendingPair.getInitData(
        this.a.address,
        this.b.address,
        this.peggedOracle.address,
       await this.peggedOracle.getDataParameter("0")
      )

      let deployTx = await this.bentoBox.deploy(this.lendingPair.address, data)
      const cloneAddress = (await deployTx.wait()).events[0].args.cloneAddress
      let pair = await this.lendingPair.attach(cloneAddress)

      await this.a.approve(this.bentoBox.address, 1)

      await this.bentoBox.deposit(this.a.address, this.alice.address, this.alice.address, 0, 1)

      await pair.addCollateral(1, this.alice.address)

      expect(await this.bentoBox.balanceOf(this.a.address, pair.address)).to.be.equal(1)
    })
  })

  describe("Skim ETH", function () {
    it("Skims ether to from address", async function () {
      await this.weth9.connect(this.alice).deposit( {
        value: 1,
      })

      await this.bentoBox.batch([], true, {
        value: 1,
      })

      await this.bentoBox.deposit(ADDRESS_ZERO, this.bentoBox.address, this.alice.address, 1, 0)

      amount = await this.bentoBox.balanceOf(this.weth9.address, this.alice.address)

      expect(amount, "alice should have weth").to.equal(1)

      expect(await this.weth9.balanceOf(this.bentoBox.address), "BentoBox should hold WETH").to.equal(1)

    })
  })
  
  describe("Batch", function () {
    it("Batches calls with revertOnFail true", async function () {
      await this.a.approve(this.bentoBox.address, 2)

      const deposit = this.bentoBox.interface.encodeFunctionData("deposit", [this.a.address, this.alice.address, this.alice.address, 1, 0])

      const transfer = this.bentoBox.interface.encodeFunctionData("transfer", [this.a.address, this.alice.address, this.bob.address, 1])

      await this.bentoBox.batch([deposit, transfer], true)

      assert.equal(await this.bentoBox.balanceOf(this.a.address, this.bob.address), 1, "bob should have tokens")
    })

    it("Batches calls with revertOnFail false", async function () {
      //tested in BoringSolidity
    })

    it("Does not revert on fail if revertOnFail is set to false", async function () {
      //tested in BoringSolidity
    })

    it("Reverts on fail if revertOnFail is set to true", async function () {
      //tested in BoringSolidity
  })
})
  describe('FlashLoan', function () {
    it('should revert on flashloan if not enough funds are available', async function (){
      const param = this.bentoBox.interface.encodeFunctionData("toShare", [this.a.address, 1])
      await expect(this.bentoBox.flashLoan(this.flashLoaner.address, [this.a.address], [getBigNumber(1)], this.flashLoaner.address, param)).to.be.revertedWith(
        "BoringERC20: Transfer failed")
    })
  
    it('should revert on flashloan if fee can not be paid', async function () {
      await this.a.transfer(this.bentoBox.address, getBigNumber(2))
      await this.a.approve(this.bentoBox.address, getBigNumber(2))
      await this.bentoBox.deposit(this.a.address, this.alice.address, this.alice.address, getBigNumber(1), 0)
      const param = this.bentoBox.interface.encodeFunctionData("toShare", [this.a.address, 1])      
      await expect(this.bentoBox.flashLoan(this.flashLoaner.address, [this.a.address], [getBigNumber(1)], this.flashLoaner.address, param)).to.be.revertedWith(
        "BoringERC20: Transfer")
    })
    /*
    it('should allow flashloan', async function () {
      await this.a.approve(this.bentoBox.address, getBigNumber(2))
      await this.bentoBox.deposit(this.a.address, this.alice.address, this.alice.address, 0, getBigNumber(1));
  
      const param = this.bentoBox.interface.encodeFunctionData("toShare", [this.a.address, 1])      
      await this.a.transfer(this.flashLoaner.address, getBigNumber(2));
      await this.bentoBox.flashLoan(this.flashLoaner.address, [this.a.address], [getBigNumber(1)], this.flashLoaner.address, param)
      expect(await this.bentoBox.toAmount(this.a.address, getBigNumber(1))).to.be.equal(getBigNumber(1).mul(10005).div(10000))
    
    }) */
    
  })
})
