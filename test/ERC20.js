const { ethers } = require("hardhat")
const { expect, assert } = require("chai")

describe("ERC20", function () {
  before(async function () {
    this.WETH9 = await ethers.getContractFactory("WETH9")

    this.ERC20 = await ethers.getContractFactory("TestERC20")

    this.signers = await ethers.getSigners()

    this.owner = this.signers[0]

    this.alice = this.signers[1]

    this.bob = this.signers[2]

    this.carol = this.signers[3]
  })

  beforeEach(async function () {
    this.weth9 = await this.WETH9.deploy()
    await this.weth9.deployed()

    this.token = await this.ERC20.deploy(10000)
    await this.token.deployed()
  })

  // You can nest describe calls to create subsections.
  describe("Deployment", function () {
    it("Assigns the total supply of tokens to the owner", async function () {
      const ownerBalance = await this.token.balanceOf(this.owner.address)
      expect(await this.token.totalSupply()).to.equal(ownerBalance)
    })

    // TODO: Ask about this one (Why is it needed?)
    it("Succeeds in creating over 2^256 - 1 (max) tokens", async function () {
      // 2^256 - 1
      const token = await this.ERC20.deploy(
        "115792089237316195423570985008687907853269984665640564039457584007913129639935"
      )
      await token.deployed()

      const totalSupply = await token.totalSupply()
      expect(totalSupply).to.be.equal(
        "115792089237316195423570985008687907853269984665640564039457584007913129639935"
      )
    })
  })

  describe("Transfer", function () {
    it("Succeeds transfering 10000 from owner to alice", async function () {
      await expect(() =>
        this.token.transfer(this.alice.address, 10000)
      ).to.changeTokenBalances(
        this.token,
        [this.owner, this.alice],
        [-10000, 10000]
      )
    })

    it("Fails tranfering 10001 from owner to alice", async function () {
      await expect(() =>
        this.token.transfer(this.alice.address, 10001)
      ).to.changeTokenBalances(this.token, [this.owner, this.alice], [-0, 0])
    })

    it("Succeeds for zero value transfer", async function () {
      await expect(() =>
        this.token.transfer(this.alice.address, 0)
      ).to.changeTokenBalances(this.token, [this.owner, this.alice], [-0, 0])
    })

    it("Reverts when transfering eth without approval", async function () {
      const initialOwnerBalance = await this.token.balanceOf(this.owner.address)

      await expect(this.weth9.transfer(this.token.address, 10)).to.revertedWith(
        "WETH9: Error"
      )

      expect(await this.token.balanceOf(this.owner.address)).to.equal(
        initialOwnerBalance
      )
    })

    it("Emits Transfer event with expected arguments", async function () {
      expect(
        this.token.connect(this.owner).transfer(this.alice.address, 2666, {
          from: this.owner.address,
        })
      )
        .to.emit(this.token, "Transfer")
        .withArgs(this.owner.address, this.alice.address, 2666)
    })

    it("Emits Transfer event for zero value transfer with expected arguments", async function () {
      expect(this.token.transfer(this.alice.address, 0))
        .to.emit(this.token, "Transfer")
        .withArgs(this.owner.address, this.alice.address, 0)
    })
  })

  describe("Approve", function () {
    it("approvals: msg.sender should approve 100 to this.alice.address", async function () {
      await this.token.approve(this.alice.address, 100)
      const allowance = await this.token.allowance(
        this.owner.address,
        this.alice.address
      )
      expect(allowance).to.equal(100)
    })

    it("approvals: msg.sender approves this.alice.address of 100 & withdraws 20 once.", async function () {
      const balance0 = await this.token.balanceOf(this.owner.address)
      assert.strictEqual(balance0, 10000)

      await this.token.approve(this.alice.address, 100) // 100
      const balance2 = await this.token.balanceOf(this.bob.address)
      assert.strictEqual(balance2, 0, "balance2 not correct")

      await this.token
        .connect(this.alice)
        .transferFrom(this.owner.address, this.bob.address, 20, {
          from: this.alice.address,
        }) // -20
      const allowance01 = await this.token.allowance(
        this.owner.address,
        this.alice.address
      )
      assert.strictEqual(allowance01, 80) // =80

      const balance22 = await this.token.balanceOf(this.bob.address)
      assert.strictEqual(balance22, 20)

      const balance02 = await this.token.balanceOf(this.owner.address)
      assert.strictEqual(balance02, 9980)
    })

    // should approve 100 of msg.sender & withdraw 50, twice. (should succeed)
    it("approvals: msg.sender approves this.alice.address of 100 & withdraws 20 twice.", async function () {
      await this.token.approve(this.alice.address, 100)
      const allowance01 = await this.token.allowance(
        this.owner.address,
        this.alice.address
      )
      assert.strictEqual(allowance01, 100)

      await this.token
        .connect(this.alice)
        .transferFrom(this.owner.address, this.bob.address, 20, {
          from: this.alice.address,
        })
      const allowance012 = await this.token.allowance(
        this.owner.address,
        this.alice.address
      )
      assert.strictEqual(allowance012, 80)

      const balance2 = await this.token.balanceOf(this.bob.address)
      assert.strictEqual(balance2, 20)

      const balance0 = await this.token.balanceOf(this.owner.address)
      assert.strictEqual(balance0, 9980)

      // FIRST tx done.
      // onto next.
      await this.token
        .connect(this.alice)
        .transferFrom(this.owner.address, this.bob.address, 20, {
          from: this.alice.address,
        })
      const allowance013 = await this.token.allowance(
        this.owner.address,
        this.alice.address
      )
      assert.strictEqual(allowance013, 60)

      const balance22 = await this.token.balanceOf(this.bob.address)
      assert.strictEqual(balance22, 40)

      const balance02 = await this.token.balanceOf(this.owner.address)
      assert.strictEqual(balance02, 9960)
    })

    // should approve 100 of msg.sender & withdraw 50 & 60 (should fail).
    it("approvals: msg.sender approves this.alice.address of 100 & withdraws 50 & 60 (2nd tx should fail)", async function () {
      await this.token.approve(this.alice.address, 100)
      const allowance01 = await this.token.allowance(
        this.owner.address,
        this.alice.address
      )
      assert.strictEqual(allowance01, 100)

      await this.token
        .connect(this.alice)
        .transferFrom(this.owner.address, this.bob.address, 50, {
          from: this.alice.address,
        })
      const allowance012 = await this.token.allowance(
        this.owner.address,
        this.alice.address
      )
      assert.strictEqual(allowance012, 50)

      const balance2 = await this.token.balanceOf(this.bob.address)
      assert.strictEqual(balance2, 50)

      let balance0 = await this.token.balanceOf(this.owner.address)
      assert.strictEqual(balance0, 9950)

      await this.token
        .connect(this.alice)
        .transferFrom(this.owner.address, this.bob.address, 60, {
          from: this.alice.address,
        })

      balance0 = await this.token.balanceOf(this.owner.address)
      assert.strictEqual(balance0, 9950)
    })

    it("approvals: attempt withdrawal from account with no allowance (should fail)", async function () {
      await this.token
        .connect(this.alice)
        .transferFrom(this.owner.address, this.bob.address, 60, {
          from: this.alice.address,
        })

      const balance0 = await this.token.balanceOf(this.owner.address)
      assert.strictEqual(balance0, 10000)
    })

    it("approvals: allow this.alice.address 100 to withdraw from this.owner.address. Withdraw 60 and then approve 0 & attempt transfer.", async function () {
      await this.token.approve(this.alice.address, 100)
      await this.token
        .connect(this.alice)
        .transferFrom(this.owner.address, this.bob.address, 60, {
          from: this.alice.address,
        })
      await this.token.approve(this.alice.address, 0)

      await this.token
        .connect(this.alice)
        .transferFrom(this.owner.address, this.bob.address, 10, {
          from: this.alice.address,
        })

      const balance0 = await this.token.balanceOf(this.owner.address)
      assert.strictEqual(balance0, 9940)
    })

    it("approvals: approve max (2^256 - 1)", async function () {
      await this.token.approve(
        this.alice.address,
        "115792089237316195423570985008687907853269984665640564039457584007913129639935"
      )

      expect(
        await this.token.allowance(this.owner.address, this.alice.address)
      ).to.equal(
        "115792089237316195423570985008687907853269984665640564039457584007913129639935"
      )
    })

    // should approve max of msg.sender & withdraw 20 with changing allowance (should succeed).
    it("approvals: msg.sender approves this.alice.address of max (2^256 - 1) & withdraws 20", async function () {
      const balance0 = await this.token.balanceOf(this.owner.address)
      expect(balance0).to.equal(10000)

      const max =
        "115792089237316195423570985008687907853269984665640564039457584007913129639935"
      await this.token.approve(this.alice.address, max)
      const balance2 = await this.token.balanceOf(this.bob.address)
      expect(balance2).to.equal(0)

      await this.token
        .connect(this.alice)
        .transferFrom(this.owner.address, this.bob.address, 20, {
          from: this.alice.address,
        })

      const allowance01 = await this.token.allowance(
        this.owner.address,
        this.alice.address
      )
      const maxMinus20 =
        "115792089237316195423570985008687907853269984665640564039457584007913129639915"
      expect(allowance01).to.equal(maxMinus20)

      const balance22 = await this.token.balanceOf(this.bob.address)
      expect(balance22).to.equal(20)

      const balance02 = await this.token.balanceOf(this.owner.address)
      expect(balance02).to.equal(9980)
    })

    it("Emits Approval event with expected arguments", async function () {
      expect(
        this.token.connect(this.owner).approve(this.alice.address, "2666", {
          from: this.owner.address,
        })
      )
        .to.emit(this.token, "Approval")
        .withArgs(this.owner.address, this.alice.address, 2666)
    })
  })
})
