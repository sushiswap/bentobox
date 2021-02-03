const { ethers, deployments } = require("hardhat")
const { expect, assert } = require("chai")
const {
  getApprovalDigest,
  prepare,
  ADDRESS_ZERO,
  getBigNumber,
  sansSafetyAmount,
  setMasterContractApproval,
  deploy,
  deploymentsFixture,
  decodeLogs,
} = require("./utilities")
const { ecsign } = require("ethereumjs-util")

describe("BentoBoxPlus", function () {
  before(async function () {
    await prepare(this, [
      "ERC20Mock",
      "SneakyFlashLoanerMock",
      "FlashLoanerMock",
      "ReturnFalseERC20Mock",
      "RevertingERC20Mock",
      "BentoBoxPlusMock",
    ])
  })

  beforeEach(async function () {
    await deploymentsFixture(this, async (cmd) => {
      await cmd.addToken("a", "Token A", "A", this.ReturnFalseERC20Mock)
      await cmd.addToken("b", "Token B", "B", this.RevertingERC20Mock)
    })

    await deploy(this, [
      ["flashLoaner", this.FlashLoanerMock],
      ["sneakyFlashLoaner", this.SneakyFlashLoanerMock],
    ])

    this.erc20 = await this.ERC20Mock.deploy(10000000)
    await this.erc20.deployed()

    await this.b.transfer(this.bob.address, getBigNumber(1))
  })

  describe("Deploy", function () {
    it("Emits LogDeploy event with correct arguments", async function () {
      const data = await this.lendingPair.getInitData(
        this.a.address,
        this.b.address,
        this.peggedOracle.address,
        await this.peggedOracle.getDataParameter("0")
      )

      await expect(this.bentoBox.deploy(this.lendingPair.address, data)).to.emit(this.bentoBox, "LogDeploy")
    })
  })

  describe("Conversion", function () {
    it("Should convert Shares to Amounts", async function () {
      expect(await this.bentoBox.toShare(this.a.address, 1000, false)).to.be.equal(1000)
      expect(await this.bentoBox.toShare(this.a.address, 1, false)).to.be.equal(1)
      expect(await this.bentoBox.toShare(this.a.address, 0, false)).to.be.equal(0)
      expect(await this.bentoBox.toShare(this.a.address, 1000, true)).to.be.equal(1000)
      expect(await this.bentoBox.toShare(this.a.address, 1, true)).to.be.equal(1)
      expect(await this.bentoBox.toShare(this.a.address, 0, true)).to.be.equal(0)
    })

    it("Should convert amount to Shares", async function () {
      expect(await this.bentoBox.toAmount(this.a.address, 1000, false)).to.be.equal(1000)
      expect(await this.bentoBox.toAmount(this.a.address, 1, false)).to.be.equal(1)
      expect(await this.bentoBox.toAmount(this.a.address, 0, false)).to.be.equal(0)
      expect(await this.bentoBox.toAmount(this.a.address, 1000, true)).to.be.equal(1000)
      expect(await this.bentoBox.toAmount(this.a.address, 1, true)).to.be.equal(1)
      expect(await this.bentoBox.toAmount(this.a.address, 0, true)).to.be.equal(0)
    })

    it("Should convert at ratio", async function () {
      await this.BentoBoxPlusMock.new("bento", this.weth9.address)
      await this.a.approve(this.bento.address, getBigNumber(100))

      await this.bento.deposit(this.a.address, this.alice.address, this.alice.address, getBigNumber(100), 0)
      await this.bento.addProfit(this.a.address, getBigNumber(66))

      expect(await this.bento.toAmount(this.a.address, 1000, false)).to.be.equal(1660)
      expect(await this.bento.toAmount(this.a.address, 1, false)).to.be.equal(1)
      expect(await this.bento.toAmount(this.a.address, 0, false)).to.be.equal(0)
      expect(await this.bento.toAmount(this.a.address, 1000, true)).to.be.equal(1660)
      expect(await this.bento.toAmount(this.a.address, 1, true)).to.be.equal(2)
      expect(await this.bento.toAmount(this.a.address, 0, true)).to.be.equal(0)
      // 1000 * 100 / 166 = 602.4096
      expect(await this.bento.toShare(this.a.address, 1000, false)).to.be.equal(602)
      expect(await this.bento.toShare(this.a.address, 1000, true)).to.be.equal(603)
      expect(await this.bento.toShare(this.a.address, 1, false)).to.be.equal(0)
      expect(await this.bento.toShare(this.a.address, 1, true)).to.be.equal(1)
      expect(await this.bento.toShare(this.a.address, 0, false)).to.be.equal(0)
      expect(await this.bento.toShare(this.a.address, 0, true)).to.be.equal(0)
    })
  })

  describe("Deposit", function () {
    it("Reverts with to address zero", async function () {
      await expect(this.bentoBox.deposit(this.a.address, this.alice.address, ADDRESS_ZERO, 0, 0)).to.be.revertedWith("BentoBox: to not set")
      await expect(this.bentoBox.deposit(ADDRESS_ZERO, this.alice.address, ADDRESS_ZERO, 0, 0)).to.be.revertedWith("BentoBox: to not set")
      await expect(this.bentoBox.deposit(this.a.address, this.bob.address, ADDRESS_ZERO, 1, 0)).to.be.revertedWith("BentoBox: no masterContract")
    })

    it("Reverts without approval", async function () {
      await this.a.connect(this.bob).approve(this.bentoBox.address, 1000)
      await expect(this.bentoBox.deposit(this.a.address, this.alice.address, this.alice.address, 1, 0)).to.be.revertedWith(
        "BoringERC20: TransferFrom"
      )

      await expect(this.bentoBox.deposit(this.a.address, this.alice.address, this.bob.address, 1, 0)).to.be.revertedWith(
        "BoringERC20: TransferFrom"
      )

      await expect(this.bentoBox.connect(this.bob).deposit(this.b.address, this.bob.address, this.bob.address, 1, 0)).to.be.revertedWith(
        "BoringERC20: TransferFrom"
      )

      expect(await this.bentoBox.balanceOf(this.a.address, this.alice.address)).to.be.equal(0)
    })

    async function analyse(thisObject, contract, tx_promise) {
      const tx = await tx_promise
      const rx = await thisObject.alice.provider.getTransactionReceipt(tx.hash)
      const logs = decodeLogs(rx.logs)
      for (var i in logs) {
        var log = logs[i]
        console.log(".to.emit(this." + ', "LogWithdraw")')
        console.log(".withArgs(this.a.address, this.alice.address, this.alice.address, 1, 1)")

        console.log()
      }
      //console.log(tx, contract.interface.parseLog(rx.logs[1]));
    }

    it("Mutates balanceOf correctly", async function () {
      await this.a.approve(this.bentoBox.address, 1)

      await analyse(this, this.bentoBox, this.bentoBox.deposit(this.a.address, this.alice.address, this.alice.address, 1, 0))

      expect(await this.bentoBox.balanceOf(this.a.address, this.alice.address)).to.be.equal(1)
    })

    it("Mutates balanceOf for BentoBox and WETH correctly", async function () {
      await this.weth9.connect(this.alice).deposit({
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
      await expect(
        this.bentoBox.connect(this.bob).deposit(ADDRESS_ZERO, this.bob.address, this.bob.address, 1, 0, {
          from: this.bob.address,
          value: 1,
        })
      ).to.be.revertedWith("BentoBox: No tokens")
    })

    it("Mutates balanceOf and totalSupply for two deposits correctly", async function () {
      await this.a.approve(this.bentoBox.address, 3)

      await this.bentoBox.deposit(this.a.address, this.alice.address, this.alice.address, 1, 0)

      await this.bentoBox.deposit(this.a.address, this.alice.address, this.alice.address, 2, 0)

      expect(await this.bentoBox.balanceOf(this.a.address, this.alice.address), "incorrect amount calculation").to.be.equal(3)

      expect((await this.bentoBox.totals(this.a.address)).elastic, "incorrect total amount").to.be.equal(3)
    })

    it("Emits LogDeposit event with correct arguments", async function () {
      await this.a.approve(this.bentoBox.address, 1)

      await expect(this.bentoBox.deposit(this.a.address, this.alice.address, this.alice.address, 1, 0))
        .to.emit(this.bentoBox, "LogDeposit")
        .withArgs(this.a.address, this.alice.address, this.alice.address, 1, 1)
    })
  })

  describe("Deposit Share", function () {
    it("allows for deposit of Share", async function () {
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

      expect((await this.bentoBox.totals(this.a.address)).elastic, "incorrect total amount").to.be.equal(1)
    })
  })

  // TODO: Cover these
  describe("Deposit With Permit", function () {
    // tested in BoringSolidity
  })

  describe("Withdraw", function () {
    it("Reverts when address zero is passed as to argument", async function () {
      await expect(this.bentoBox.withdraw(this.a.address, this.alice.address, ADDRESS_ZERO, 1, 0)).to.be.revertedWith("BentoBox: to not set")
    })

    it("Reverts when attempting to withdraw below 1000 shares", async function () {
      await this.a.approve(this.bentoBox.address, 1000)

      await this.bentoBox.deposit(this.a.address, this.alice.address, this.alice.address, 0, 1000)

      await expect(this.bentoBox.withdraw(this.a.address, this.alice.address, this.alice.address, 0, 2)).to.be.revertedWith(
        "BentoBox: cannot empty"
      )
    })

    it("Reverts when attempting to withdraw larger amount than available", async function () {
      await this.a.approve(this.bentoBox.address, getBigNumber(1))

      await this.bentoBox.deposit(this.a.address, this.alice.address, this.alice.address, getBigNumber(1), 0)

      await expect(this.bentoBox.withdraw(this.a.address, this.alice.address, this.alice.address, getBigNumber(2), 0)).to.be.revertedWith(
        "BoringMath: Underflow"
      )
    })

    it("Mutates balanceOf of Token and BentoBox correctly", async function () {
      const startBal = await this.a.balanceOf(this.alice.address)
      await this.a.approve(this.bentoBox.address, getBigNumber(1))
      await this.a.connect(this.bob).approve(this.bentoBox.address, getBigNumber(1))

      await this.bentoBox.deposit(this.a.address, this.alice.address, this.alice.address, getBigNumber(1), 0)
      await this.bentoBox.connect(this.bob).deposit(this.a.address, this.bob.address, this.bob.address, getBigNumber(1), 0)

      await this.bentoBox.withdraw(this.a.address, this.alice.address, this.alice.address, getBigNumber(1), 0)

      expect(await this.a.balanceOf(this.alice.address), "alice should have all of their tokens back").to.equal(startBal)

      expect(await this.bentoBox.balanceOf(this.a.address, this.alice.address), "token should be withdrawn").to.equal(0)
    })

    it("Mutates balanceOf on BentoBox for WETH correctly", async function () {
      await this.weth9.connect(this.alice).deposit({
        value: 1,
      })
      await this.bentoBox.connect(this.bob).deposit(ADDRESS_ZERO, this.bob.address, this.bob.address, getBigNumber(1), 0, {
        from: this.bob.address,
        value: getBigNumber(1),
      })

      await this.bentoBox.connect(this.bob).withdraw(ADDRESS_ZERO, this.bob.address, this.bob.address, sansSafetyAmount(getBigNumber(1)), 0, {
        from: this.bob.address,
      })

      expect(await this.bentoBox.balanceOf(this.weth9.address, this.bob.address), "token should be withdrawn").to.be.equal(100000)
    })

    it("Reverts if ETH transfer fails", async function () {
      await this.weth9.connect(this.alice).deposit({
        value: 1,
      })
      await this.bentoBox.connect(this.bob).deposit(ADDRESS_ZERO, this.bob.address, this.bob.address, getBigNumber(1), 0, {
        from: this.bob.address,
        value: getBigNumber(1),
      })

      await expect(
        this.bentoBox
          .connect(this.bob)
          .withdraw(ADDRESS_ZERO, this.bob.address, this.flashLoaner.address, sansSafetyAmount(getBigNumber(1)), 0, {
            from: this.bob.address,
          })
      ).to.be.revertedWith("BentoBox: ETH transfer failed")
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
      const bobStartBalance = await this.a.balanceOf(this.bob.address)
      await this.a.approve(this.bentoBox.address, getBigNumber(1))

      await this.bentoBox.deposit(this.a.address, this.alice.address, this.alice.address, getBigNumber(1), 0)

      await this.bentoBox.withdraw(this.a.address, this.alice.address, this.bob.address, 1, 0)

      expect(await this.a.balanceOf(this.bob.address), "bob should have received their tokens").to.be.equal(bobStartBalance.add(1))
    })
  })

  describe("Transfer", function () {
    it("Reverts when address zero is given as to argument", async function () {
      await expect(this.bentoBox.transfer(this.a.address, this.alice.address, ADDRESS_ZERO, 1)).to.be.revertedWith("BentoBox: to not set")
    })

    it("Reverts when attempting to transfer larger amount than available", async function () {
      await expect(this.bentoBox.connect(this.bob).transfer(this.a.address, this.bob.address, this.alice.address, 1)).to.be.revertedWith(
        "BoringMath: Underflow"
      )
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
      await expect(this.bentoBox.transferMultiple(this.a.address, this.alice.address, [ADDRESS_ZERO], [1])).to.be.reverted
    })

    it("should allow transfer multiple from alice to bob and carol", async function () {
      await this.a.approve(this.bentoBox.address, 2)

      await this.bentoBox.deposit(this.a.address, this.alice.address, this.alice.address, 2, 0)

      await this.bentoBox.transferMultiple(this.a.address, this.alice.address, [this.bob.address, this.carol.address], [1, 1], {
        from: this.alice.address,
      })

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

    it("Emits LogDeposit event with expected arguments", async function () {
      await this.a.transfer(this.bentoBox.address, 1)

      await expect(this.bentoBox.connect(this.bob).deposit(this.a.address, this.bentoBox.address, this.bob.address, 1, 0))
        .to.emit(this.bentoBox, "LogDeposit")
        .withArgs(this.a.address, this.bentoBox.address, this.bob.address, 1, 1)
    })
  })

  describe("modifier allowed", function () {
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

      await expect(pair.addAsset(this.bob.address, false, 1)).to.be.revertedWith("BentoBox: Transfer not approved")
    })

    it("allow clone contract calls if MasterContract is approved", async function () {
      await this.bentoBox.whitelistMasterContract(this.lendingPair.address, true)
      await setMasterContractApproval(this.bentoBox, this.alice, this.alice, "", this.lendingPair.address, true, true)

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

      await pair.addCollateral(this.alice.address, false, 1)

      expect(await this.bentoBox.balanceOf(this.a.address, pair.address)).to.be.equal(1)
    })
  })

  describe("Skim ETH", function () {
    it("Skims ether to from address", async function () {
      await this.weth9.connect(this.alice).deposit({
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
  describe("FlashLoan", function () {
    it("should revert on batch flashloan if not enough funds are available", async function () {
      const param = this.bentoBox.interface.encodeFunctionData("toShare", [this.a.address, 1, false])
      await expect(
        this.bentoBox.batchFlashLoan(this.flashLoaner.address, [this.flashLoaner.address], [this.a.address], [getBigNumber(1)], param)
      ).to.be.revertedWith("BoringERC20: Transfer failed")
    })

    it("should revert on flashloan if fee can not be paid", async function () {
      await this.a.transfer(this.bentoBox.address, getBigNumber(2))
      await this.a.approve(this.bentoBox.address, getBigNumber(2))
      await this.bentoBox.deposit(this.a.address, this.alice.address, this.alice.address, getBigNumber(1), 0)
      const param = this.bentoBox.interface.encodeFunctionData("toShare", [this.a.address, 1, false])
      await expect(
        this.bentoBox.batchFlashLoan(this.flashLoaner.address, [this.flashLoaner.address], [this.a.address], [getBigNumber(1)], param)
      ).to.be.revertedWith("BoringERC20: Transfer")
    })

    it("should revert on flashloan if amount is not paid back", async function () {
      await this.a.approve(this.bentoBox.address, getBigNumber(2))
      await this.bentoBox.deposit(this.a.address, this.alice.address, this.alice.address, getBigNumber(1), 0)
      const param = this.bentoBox.interface.encodeFunctionData("toShare", [this.a.address, 1, false])
      await expect(
        this.bentoBox.flashLoan(this.sneakyFlashLoaner.address, this.sneakyFlashLoaner.address, this.a.address, getBigNumber(1), param)
      ).to.be.revertedWith("BentoBoxPlus: Wrong amount")
    })

    it("should revert on batch flashloan if amount is not paid back", async function () {
      await this.a.approve(this.bentoBox.address, getBigNumber(2))
      await this.bentoBox.deposit(this.a.address, this.alice.address, this.alice.address, getBigNumber(1), 0)
      const param = this.bentoBox.interface.encodeFunctionData("toShare", [this.a.address, 1, false])
      await expect(
        this.bentoBox.batchFlashLoan(
          this.sneakyFlashLoaner.address,
          [this.sneakyFlashLoaner.address],
          [this.a.address],
          [getBigNumber(1)],
          param
        )
      ).to.be.revertedWith("BentoBoxPlus: Wrong amount")
    })

    it("should allow flashloan", async function () {
      await this.a.approve(this.bentoBox.address, getBigNumber(2))
      await this.bentoBox.deposit(this.a.address, this.alice.address, this.alice.address, 0, getBigNumber(1))

      const param = this.bentoBox.interface.encodeFunctionData("toShare", [this.a.address, 1, false])
      await this.a.transfer(this.flashLoaner.address, getBigNumber(2))
      await this.bentoBox.flashLoan(this.flashLoaner.address, this.flashLoaner.address, this.a.address, getBigNumber(1), param)
      expect(await this.bentoBox.toAmount(this.a.address, getBigNumber(1), false)).to.be.equal(getBigNumber(1).mul(10005).div(10000))
    })

    it("should allow batch flashloan", async function () {
      await this.a.approve(this.bentoBox.address, getBigNumber(2))
      await this.bentoBox.deposit(this.a.address, this.alice.address, this.alice.address, 0, getBigNumber(1))

      const param = this.bentoBox.interface.encodeFunctionData("toShare", [this.a.address, 1, false])
      await this.a.transfer(this.flashLoaner.address, getBigNumber(2))
      await this.bentoBox.batchFlashLoan(this.flashLoaner.address, [this.flashLoaner.address], [this.a.address], [getBigNumber(1)], param)
      expect(await this.bentoBox.toAmount(this.a.address, getBigNumber(1), false)).to.be.equal(getBigNumber(1).mul(10005).div(10000))
    })
  })

  describe("set Strategy", function () {
    it("should allow to set strategy", async function () {
      await this.bentoBox.setStrategy(this.a.address, this.a.address)
    })

    it("should be reverted if 2 weeks are not up", async function () {
      await expect(this.bentoBox.setStrategy(this.a.address, ADDRESS_ZERO)).to.be.revertedWith("StrategyManager: Too early")
    })

    it("should not allow bob to set Strategy", async function () {
      await expect(this.bentoBox.connect(this.bob).setStrategy(this.a.address, this.a.address)).to.be.reverted
    })
  })
})
