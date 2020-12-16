const { ethers } = require("hardhat")
const { expect, assert } = require("chai")
const { getApprovalDigest } = require("./utilities")
const { ecsign } = require("ethereumjs-util")

describe("BentoBox", function () {
  before(async function () {
    this.WETH9 = await ethers.getContractFactory("WETH9Mock")

    this.BentoBox = await ethers.getContractFactory("BentoBox")

    this.LendingPair = await ethers.getContractFactory("LendingPair")

    this.ERC20 = await ethers.getContractFactory("ERC20Mock")

    this.ReturnFalseERC20 = await ethers.getContractFactory(
      "ReturnFalseERC20Mock"
    )

    this.RevertingERC20 = await ethers.getContractFactory("RevertingERC20Mock")

    this.PeggedOracle = await ethers.getContractFactory("PeggedOracle")

    this.signers = await ethers.getSigners()

    this.alice = this.signers[0]

    this.bob = this.signers[1]

    this.carol = this.signers[2]

    this.carolPrivateKey =
      "0x94890218f2b0d04296f30aeafd13655eba4c5bbf1770273276fee52cbe3f2cb4"
  })

  beforeEach(async function () {
    this.weth9 = await this.WETH9.deploy()
    await this.weth9.deployed()

    this.bentoBox = await this.BentoBox.deploy(this.weth9.address)
    await this.bentoBox.deployed()

    this.erc20 = await this.ERC20.deploy(10000000)
    await this.erc20.deployed()

    this.a = await this.ReturnFalseERC20.deploy("Token A", "A", 10000000)

    await this.a.deployed()

    this.b = await this.RevertingERC20.deploy("Token B", "B", 10000000)

    await this.b.deployed()

    // Alice has all tokens for a and b since creator

    // await this.a.transfer(this.alice.address, parseUnits("1000"));

    // Bob has 1000 b tokens
    await this.b.transfer(this.bob.address, 1000)

    this.lendingPair = await this.LendingPair.deploy(this.bentoBox.address)
    await this.lendingPair.deployed()

    this.peggedOracle = await this.PeggedOracle.deploy()
    await this.peggedOracle.deployed()
  })

  describe("Deploy", function () {
    it("Emits LogDeploy event with correct arguments", async function () {
      const data = await this.lendingPair.getInitData(
        this.a.address,
        this.b.address,
        this.peggedOracle.address,
        await this.peggedOracle.getDataParameter("0")
      )

      expect(this.bentoBox.deploy(this.lendingPair.address, data))
        .to.emit(this.bentoBox, "LogDeploy")
        .withArgs(
          this.lendingPair.address,
          data,
          "0xa936eEBB5A8F82a38dF9fC58E736b9eeF16A6A44"
        )
    })
  })

  describe("Master Contract Approved", function () {
    it("Returns false for pair which has not been set", async function () {
      expect(
        await this.bentoBox.masterContractApproved(
          this.lendingPair.address,
          this.alice.address
        )
      ).to.be.false
    })

    it("Returns true for pair which has been set", async function () {
      this.bentoBox.setMasterContractApproval(this.lendingPair.address, true)

      expect(
        await this.bentoBox.masterContractApproved(
          this.lendingPair.address,
          this.alice.address
        )
      ).to.be.true
    })
  })

  describe("Set Master Contract Approval", function () {
    it("Reverts with address zero", async function () {
      expect(
        this.bentoBox.setMasterContractApproval(
          "0x0000000000000000000000000000000000000000",
          true
        )
      ).to.be.revertedWith("BentoBox: masterContract must be set")
    })

    it("Emits LogSetMasterContractApproval event with correct arguments", async function () {
      expect(
        this.bentoBox.setMasterContractApproval(this.lendingPair.address, true)
      )
        .to.emit(this.bentoBox, "LogSetMasterContractApproval")
        .withArgs(this.lendingPair.address, this.alice.address, true)
    })

    it("Should allow to retract approval of masterContract", async function () {
      await this.bentoBox.setMasterContractApproval(
        this.lendingPair.address,
        true
      )

      await this.bentoBox.setMasterContractApproval(
        this.lendingPair.address,
        false
      )

      expect(
        await this.bentoBox.masterContractApproved(
          this.lendingPair.address,
          this.alice.address
        )
      ).to.be.false
    })
  })

  describe("Deposit", function () {
    it("Reverts with to address zero", async function () {
      expect(
        this.bentoBox.deposit(
          this.a.address,
          "0x0000000000000000000000000000000000000000",
          1
        )
      ).to.be.revertedWith("BentoBox: Transfer not approved")
    })

    it("Reverts without approval", async function () {
      expect(
        this.bentoBox.deposit(this.a.address, this.alice.address, 1)
      ).to.be.revertedWith("BentoBox: TransferFrom failed at ERC20")

      expect(
        await this.bentoBox.balanceOf(this.a.address, this.alice.address)
      ).to.be.equal(0)
    })

    it("Mutates balanceOf correctly", async function () {
      await this.a.approve(this.bentoBox.address, 1)

      await this.bentoBox.deposit(this.a.address, this.alice.address, 1)

      const amount = await this.bentoBox.balanceOf(
        this.a.address,
        this.alice.address
      )
      assert.equal(amount, 1)
    })

    it("Mutates balanceOf for BentoBox and WETH correctly", async function () {
      await this.bentoBox
        .connect(this.bob)
        .deposit(this.weth9.address, this.bob.address, 1, {
          from: this.bob.address,
          value: 1,
        })

      await this.bentoBox.connect(this.bob).skimETH({ from: this.bob.address })

      expect(
        await this.weth9.balanceOf(this.bentoBox.address),
        "BentoBox should hold WETH"
      ).to.be.equal(1)

      expect(
        await this.bentoBox.balanceOf(this.weth9.address, this.bob.address),
        "bob should have weth"
      ).to.be.equal(1)
    })

    it("Mutates balanceOf and totalSupply for two deposits correctly", async function () {
      await this.a.approve(this.bentoBox.address, 3)

      await this.bentoBox.deposit(this.a.address, this.alice.address, 1)

      await this.bentoBox.deposit(this.a.address, this.alice.address, 2)

      expect(
        await this.bentoBox.balanceOf(this.a.address, this.alice.address),
        "incorrect amount calculation"
      ).to.be.equal(3)

      expect(
        await this.bentoBox.totalSupply(this.a.address),
        "incorrect total amount"
      ).to.be.equal(3)
    })

    it("Emits LogDeposit event with correct arguments", async function () {
      await this.a.approve(this.bentoBox.address, 1)

      expect(this.bentoBox.deposit(this.a.address, this.alice.address, 1))
        .to.emit(this.bentoBox, "LogDeposit")
        .withArgs(this.a.address, this.alice.address, this.alice.address, 1)
    })
  })

  describe("Deposit To", function () {
    it("Reverts with address zero", async function () {
      await this.a.approve(this.bentoBox.address, 1)

      expect(
        this.bentoBox.depositTo(
          this.a.address,
          this.alice.address,
          "0x0000000000000000000000000000000000000000",
          1
        )
      ).to.be.revertedWith("BentoBox: to not set")
    })

    it("Mutates balanceOf and totalSupply correctly", async function () {
      await this.a.approve(this.bentoBox.address, 1)

      await this.bentoBox.depositTo(
        this.a.address,
        this.alice.address,
        this.bob.address,
        1
      )

      expect(
        await this.bentoBox.balanceOf(this.a.address, this.alice.address),
        "incorrect amount calculation"
      ).to.be.equal(0)

      expect(
        await this.bentoBox.balanceOf(this.a.address, this.bob.address),
        "incorrect amount calculation"
      ).to.be.equal(1)

      expect(
        await this.bentoBox.totalSupply(this.a.address),
        "incorrect total amount"
      ).to.be.equal(1)
    })
  })

  // TODO: Cover these
  describe("Deposit With Permit", function () {
    it("Mutates balanceOf given a valid signiture and balance of token", async function () {
      await this.a.transfer(this.carol.address, 1)

      const nonce = await this.a.nonces(this.carol.address)

      const deadline =
        (await this.alice.provider._internalBlockNumber).respTime + 10000

      const digest = await getApprovalDigest(
        this.a,
        {
          owner: this.carol.address,
          spender: this.bentoBox.address,
          value: 1,
        },
        nonce,
        deadline,
        this.alice.provider._network.chainId
      )
      const { v, r, s } = ecsign(
        Buffer.from(digest.slice(2), "hex"),
        Buffer.from(this.carolPrivateKey.replace("0x", ""), "hex")
      )

      await this.bentoBox
        .connect(this.carol)
        .depositWithPermit(
          this.a.address,
          this.carol.address,
          1,
          deadline,
          v,
          r,
          s,
          { from: this.carol.address }
        )

      const amount = await this.bentoBox.balanceOf(
        this.a.address,
        this.carol.address
      )

      expect(amount).to.be.equal(1)
    })
  })

  // TODO: Cover
  describe("Deposit To With Permit", function () {
    //
  })

  describe("Withdraw", function () {
    it("Reverts when address zero is passed as to argument", async function () {
      expect(
        this.bentoBox.withdraw(
          this.a.address,
          "0x0000000000000000000000000000000000000000",
          1
        )
      ).to.be.revertedWith("BentoBox: to not set")
    })

    it("Reverts when attempting to withdraw larger amount than available", async function () {
      await this.a.approve(this.bentoBox.address, 1)

      await this.bentoBox.deposit(this.a.address, this.alice.address, 1)

      expect(
        this.bentoBox.withdraw(this.a.address, this.alice.address, 2)
      ).to.be.revertedWith("BoringMath: Underflow")
    })

    it("Mutates balanceOf of Token and BentoBox correctly", async function () {
      await this.a.approve(this.bentoBox.address, 1)

      await this.bentoBox.deposit(this.a.address, this.alice.address, 1)

      await this.bentoBox.withdraw(this.a.address, this.alice.address, 1)

      expect(
        await this.a.balanceOf(this.alice.address),
        "alice should have all of their tokens back"
      ).to.equal(10000000)

      expect(
        await this.bentoBox.balanceOf(this.a.address, this.alice.address),
        "token should be withdrawn"
      ).to.equal(0)
    })

    it("Mutates balanceOf on BentoBox for WETH correctly", async function () {
      await this.bentoBox
        .connect(this.bob)
        .deposit(this.weth9.address, this.bob.address, 1, {
          from: this.bob.address,
          value: 1,
        })

      await this.bentoBox
        .connect(this.bob)
        .withdraw(this.weth9.address, this.bob.address, 1, {
          from: this.bob.address,
        })

      expect(
        await this.bentoBox.balanceOf(this.weth9.address, this.bob.address),
        "token should be withdrawn"
      ).to.be.equal(0)
    })

    // "BentoBox: ETH transfer failed"
    it("Reverts when attempting to withdraw eth without any", async function () {
      expect(
        this.bentoBox.withdraw(this.weth9.address, this.alice.address, 1)
      ).to.be.revertedWith("BoringMath: Underflow")
    })

    it("Emits LogWithdraw event with expected arguments", async function () {
      await this.a.approve(this.bentoBox.address, 1)

      this.bentoBox.deposit(this.a.address, this.alice.address, 1)

      expect(this.bentoBox.withdraw(this.a.address, this.alice.address, 1))
        .to.emit(this.bentoBox, "LogWithdraw")
        .withArgs(this.a.address, this.alice.address, this.alice.address, 1)
    })
  })

  describe("Withdraw From", function () {
    it("Reverts when address zero is passed as to argument", async function () {
      await this.a.approve(this.bentoBox.address, 1)

      await this.bentoBox.deposit(this.a.address, this.alice.address, 1)

      expect(
        this.bentoBox.withdrawFrom(
          this.a.address,
          this.alice.address,
          "0x0000000000000000000000000000000000000000",
          1
        )
      ).to.be.revertedWith("BentoBox: to not set")
    })

    it("Mutates bentoBox balanceOf and token balanceOf for from and to correctly", async function () {
      await this.a.approve(this.bentoBox.address, 1)

      await this.bentoBox.deposit(this.a.address, this.alice.address, 1)

      await this.bentoBox.withdrawFrom(
        this.a.address,
        this.alice.address,
        this.bob.address,
        1
      )

      expect(
        await this.a.balanceOf(this.alice.address),
        "bob should have received their tokens"
      ).to.be.equal(9999999)

      expect(
        await this.a.balanceOf(this.bob.address),
        "bob should have received their tokens"
      ).to.be.equal(1)

      expect(
        await this.bentoBox.balanceOf(this.a.address, this.alice.address),
        "token should be withdrawn"
      ).to.be.equal(0)
    })
  })

  describe("Transfer", function () {
    it("Reverts when address zero is given as to argument", async function () {
      await this.a.approve(this.bentoBox.address, 1)

      await this.bentoBox.deposit(this.a.address, this.alice.address, 1)

      expect(
        this.bentoBox.transfer(
          this.alice.address,
          "0x0000000000000000000000000000000000000000",
          1
        )
      ).to.be.revertedWith("BentoBox: to not set")
    })

    it("Reverts when attempting to transfer larger amount than available", async function () {
      await this.a.connect(this.bob).approve(this.bentoBox.address, 1, {
        from: this.bob.address,
      })

      expect(
        this.bentoBox
          .connect(this.bob)
          .transfer(this.a.address, this.alice.address, 1, {
            from: this.bob.address,
          })
      ).to.be.revertedWith("BoringMath: Underflow")
    })

    it("Mutates balanceOf for from and to correctly", async function () {
      await this.a.approve(this.bentoBox.address, 1)

      await this.bentoBox.deposit(this.a.address, this.alice.address, 1)

      await this.bentoBox.transferFrom(
        this.a.address,
        this.alice.address,
        this.bob.address,
        1
      )

      expect(
        await this.bentoBox.balanceOf(this.a.address, this.alice.address),
        "token should be transferred"
      ).to.be.equal(0)

      expect(
        await this.bentoBox.balanceOf(this.a.address, this.bob.address),
        "token should be transferred"
      ).to.be.equal(1)
    })

    it("Emits LogTransfer event with expected arguments", async function () {
      await this.a.approve(this.bentoBox.address, 1)

      this.bentoBox.deposit(this.a.address, this.alice.address, 1)

      expect(this.bentoBox.transfer(this.a.address, this.bob.address, 1))
        .to.emit(this.bentoBox, "LogTransfer")
        .withArgs(this.a.address, this.alice.address, this.bob.address, 1)
    })
  })

  describe("Transfer Multiple", function () {
    it("Reverts if first to argument is address zero", async function () {
      expect(
        this.bentoBox.transferMultiple(
          this.a.address,
          ["0x0000000000000000000000000000000000000000"],
          [1]
        )
      ).to.be.reverted
    })

    it("should allow transfer multiple from alice to bob and carol", async function () {
      await this.a.approve(this.bentoBox.address, 2)

      await this.bentoBox.deposit(this.a.address, this.alice.address, 2)

      // await this.bentoBox.transferMultipleFrom(
      //   this.a.address,
      //   this.alice.address,
      //   [this.bob.address, this.carol.address],
      //   [1, 1]
      // )

      await this.bentoBox.transferMultiple(
        this.a.address,
        [this.bob.address, this.carol.address],
        [1, 1],
        { from: this.alice.address }
      )

      assert.equal(
        await this.bentoBox.balanceOf(this.a.address, this.alice.address),
        0,
        "token should be transferred"
      )

      assert.equal(
        await this.bentoBox.balanceOf(this.a.address, this.bob.address),
        1,
        "token should be transferred"
      )

      assert.equal(
        await this.bentoBox.balanceOf(this.a.address, this.carol.address),
        1,
        "token should be transferred"
      )
    })
  })

  describe("Skim", function () {
    it("Skims tokens to from address", async function () {
      await this.a.transfer(this.bentoBox.address, 1)

      expect(
        await this.bentoBox.balanceOf(this.a.address, this.bob.address),
        "bob should have no tokens"
      ).to.be.equal(0)

      await this.bentoBox
        .connect(this.bob)
        .skim(this.a.address, { from: this.bob.address })

      expect(
        await this.bentoBox.balanceOf(this.a.address, this.bob.address),
        "bob should have tokens"
      ).to.be.equal(1)
    })

    it("Emits LogDeposit event with expected arguments", async function () {
      await this.a.transfer(this.bentoBox.address, 1)

      expect(
        this.bentoBox
          .connect(this.bob)
          .skim(this.a.address, { from: this.bob.address })
      )
        .to.emit(this.bentoBox, "LogDeposit")
        .withArgs(this.a.address, this.bentoBox.address, this.bob.address, 1)
    })
  })

  describe("Skim To", function () {
    it("Reverts when address zero is passed as to argument", async function () {
      expect(
        this.bentoBox.skimTo(
          this.a.address,
          "0x0000000000000000000000000000000000000000"
        )
      ).to.be.revertedWith("BentoBox: to not set")
    })

    it("Skims tokens to address", async function () {
      await this.a.transfer(this.bentoBox.address, 1)

      expect(
        await this.bentoBox.balanceOf(this.a.address, this.carol.address),
        "maki should have no tokens"
      ).to.equal(0)

      await this.bentoBox
        .connect(this.bob)
        .skimTo(this.a.address, this.carol.address, { from: this.bob.address })

      expect(
        await this.bentoBox.balanceOf(this.a.address, this.carol.address),
        "maki should have tokens"
      ).to.equal(1)
    })
  })

  describe("Skim ETH", function () {
    it("Skims ether to from address", async function () {
      await this.bentoBox.batch([], true, {
        value: 1,
      })

      await this.bentoBox.skimETH()

      expect(
        await this.weth9.balanceOf(this.bentoBox.address),
        "BentoBox should hold WETH"
      ).to.equal(1)

      amount = await this.bentoBox.balanceOf(
        this.weth9.address,
        this.alice.address
      )

      expect(amount, "alice should have weth").to.equal(1)
    })
  })

  describe("Skim ETH To", function () {
    it("Reverts given address zero as to agrument", async function () {
      expect(
        this.bentoBox.skimETHTo("0x0000000000000000000000000000000000000000")
      ).to.be.revertedWith("BentoBox: to not set")
    })

    it("should allow to skim ether to other address", async function () {
      await this.bentoBox.batch([], true, { value: 1 })

      await this.bentoBox.skimETHTo(this.bob.address)

      assert.equal(
        await this.weth9.balanceOf(this.bentoBox.address),
        1,
        "BentoBox should hold WETH"
      )

      amount = await this.bentoBox
        .connect(this.bob)
        .balanceOf(this.weth9.address, this.bob.address)

      assert.equal(amount, 1, "bob should have weth")
    })
  })

  describe("Batch", function () {
    it("Batches calls with revertOnFail true", async function () {
      await this.a.approve(this.bentoBox.address, 2)

      const deposit = this.bentoBox.interface.encodeFunctionData("deposit", [
        this.a.address,
        this.alice.address,
        1,
      ])

      const transferFrom = this.bentoBox.interface.encodeFunctionData(
        "transferFrom",
        [this.a.address, this.alice.address, this.bob.address, 1]
      )

      await this.bentoBox.batch([deposit, transferFrom], true)

      assert.equal(
        await this.bentoBox.balanceOf(this.a.address, this.bob.address),
        1,
        "bob should have tokens"
      )
    })

    it("Batches calls with revertOnFail false", async function () {
      await this.a.approve(this.bentoBox.address, 2)

      const deposit = this.bentoBox.interface.encodeFunctionData("deposit", [
        this.a.address,
        this.alice.address,
        1,
      ])

      const transferFrom = this.bentoBox.interface.encodeFunctionData(
        "transferFrom",
        [this.a.address, this.alice.address, this.bob.address, 1]
      )

      await this.bentoBox.batch([deposit, transferFrom], false)

      const amount = await this.bentoBox.balanceOf(
        this.a.address,
        this.bob.address
      )

      assert.equal(amount, 1, "bob should have tokens")
    })

    it("Does not revert on fail if revertOnFail is set to false", async function () {
      await this.a.approve(this.bentoBox.address, 2)

      const deposit = this.bentoBox.interface.encodeFunctionData("deposit", [
        this.a.address,
        this.alice.address,
        1,
      ])

      const transferFrom = this.bentoBox.interface.encodeFunctionData(
        "transferFrom",
        [this.a.address, this.alice.address, this.bob.address, 2]
      )

      await this.bentoBox.batch([deposit, transferFrom], false)

      let amount = await this.bentoBox.balanceOf(
        this.a.address,
        this.alice.address
      )
      assert.equal(amount, 1, "alice should have tokens")

      amount = await this.bentoBox.balanceOf(this.a.address, this.bob.address)
      assert.equal(amount, 0, "bob should not have tokens")
    })

    it("Reverts on fail if revertOnFail is set to true", async function () {
      await this.a.approve(this.bentoBox.address, 2)

      const deposit = this.bentoBox.interface.encodeFunctionData("deposit", [
        this.a.address,
        this.alice.address,
        1,
      ])

      const transferFrom = this.bentoBox.interface.encodeFunctionData(
        "transferFrom",
        [this.a.address, this.alice.address, this.bob.address, 2]
      )

      expect(
        this.bentoBox.connect(this.alice).batch([deposit, transferFrom], true, {
          from: this.alice.address,
        })
      ).to.be.revertedWith("Transaction failed")

      expect(
        await this.bentoBox.balanceOf(this.a.address, this.alice.address),
        "alice should not have tokens"
      ).to.be.equal(0)

      expect(
        await this.bentoBox.balanceOf(this.a.address, this.bob.address),
        "bob should not have tokens"
      ).to.be.equal(0)
    })
  })
})
