const { ethers } = require("hardhat")
const { expect, assert } = require("chai")
const {
  ADDRESS_ZERO,
  getApprovalDigest,
  getDomainSeparator,
} = require("./utilities")
const { ecsign } = require("ethereumjs-util")

describe("ERC20", function () {
  before(async function () {
    this.WETH9 = await ethers.getContractFactory("WETH9Mock")

    this.ERC20 = await ethers.getContractFactory("ERC20Mock")

    this.signers = await ethers.getSigners()

    this.owner = this.signers[0]

    this.alice = this.signers[1]

    this.bob = this.signers[2]

    this.carol = this.signers[3]

    this.bobPrivateKey =
      "0x94890218f2b0d04296f30aeafd13655eba4c5bbf1770273276fee52cbe3f2cb4"
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
    it("Succeeds transfering 10000 tokens from owner to alice", async function () {
      expect(() =>
        this.token.transfer(this.alice.address, 10000)
      ).to.changeTokenBalances(
        this.token,
        [this.owner, this.alice],
        [-10000, 10000]
      )
    })

    it("Returns true on success", async function () {
      expect(await this.token.callStatic.transfer(this.alice.address, 10000)).to
        .be.true
    })

    it("Fails transfering 10001 tokens from owner to alice", async function () {
      expect(this.token.transfer(this.alice.address, 10001)).to.be.revertedWith(
        "LendingPair: balance too low"
      )
    })

    it("Succeeds for zero value transfer", async function () {
      expect(() =>
        this.token.transfer(this.alice.address, 0)
      ).to.changeTokenBalances(this.token, [this.owner, this.alice], [-0, 0])
    })

    it("Reverts when transfering eth without approval", async function () {
      const initialOwnerBalance = await this.token.balanceOf(this.owner.address)

      // TODO: This isn't right...
      // Need to loopback on original version of this test and see what's up
      expect(this.weth9.transfer(this.token.address, 10)).to.revertedWith(
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

    it("Emits Transfer event with expected arguments for zero value transfer ", async function () {
      expect(this.token.transfer(this.alice.address, 0))
        .to.emit(this.token, "Transfer")
        .withArgs(this.owner.address, this.alice.address, 0)
    })
  })

  describe("Approve", function () {
    it("approvals: msg.sender should approve 100 to this.alice.address", async function () {
      await this.token.approve(this.alice.address, 100)
      expect(
        await this.token.allowance(this.owner.address, this.alice.address)
      ).to.equal(100)
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

      expect(
        this.token
          .connect(this.alice)
          .transferFrom(this.owner.address, this.bob.address, 60, {
            from: this.alice.address,
          })
      ).to.be.revertedWith("LendingPair: allowance too low")
    })

    it("approvals: attempt withdrawal from account with no allowance (should fail)", async function () {
      expect(
        this.token
          .connect(this.alice)
          .transferFrom(this.owner.address, this.bob.address, 60, {
            from: this.alice.address,
          })
      ).to.be.revertedWith("LendingPair: allowance too low")
    })

    it("approvals: allow this.alice.address 100 to withdraw from this.owner.address. Withdraw 60 and then approve 0 & attempt transfer.", async function () {
      await this.token.approve(this.alice.address, 100)
      await this.token
        .connect(this.alice)
        .transferFrom(this.owner.address, this.bob.address, 60, {
          from: this.alice.address,
        })
      await this.token.approve(this.alice.address, 0)

      expect(
        this.token
          .connect(this.alice)
          .transferFrom(this.owner.address, this.bob.address, 10, {
            from: this.alice.address,
          })
      ).to.be.revertedWith("LendingPair: allowance too low")
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

  describe("Permit", function () {
    // This is a test of our utility function.
    it("Returns correct DOMAIN_SEPARATOR for token and chainId", async function () {
      expect(await this.token.DOMAIN_SEPARATOR()).to.be.equal(
        getDomainSeparator(
          this.token.address,
          this.alice.provider._network.chainId
        )
      )
    })

    it("Reverts when address zero is passed as owner argument", async function () {
      const nonce = await this.token.nonces(this.bob.address)

      const deadline =
        (await this.alice.provider._internalBlockNumber).respTime + 10000

      const digest = await getApprovalDigest(
        this.token,
        {
          owner: this.bob.address,
          spender: this.alice.address,
          value: 1,
        },
        nonce,
        deadline,
        this.alice.provider._network.chainId
      )

      const { v, r, s } = ecsign(
        Buffer.from(digest.slice(2), "hex"),
        Buffer.from(this.bobPrivateKey.replace("0x", ""), "hex")
      )

      expect(
        this.token
          .connect(this.bob)
          .permit(ADDRESS_ZERO, this.alice.address, 1, deadline, v, r, s, {
            from: this.bob.address,
          })
      ).to.be.revertedWith("Owner cannot be 0")
    })

    it("Succeessfully executes a permit", async function () {
      const nonce = await this.token.nonces(this.bob.address)

      const deadline =
        (await this.alice.provider._internalBlockNumber).respTime + 10000

      const digest = await getApprovalDigest(
        this.token,
        {
          owner: this.bob.address,
          spender: this.alice.address,
          value: 1,
        },
        nonce,
        deadline,
        this.alice.provider._network.chainId
      )
      const { v, r, s } = ecsign(
        Buffer.from(digest.slice(2), "hex"),
        Buffer.from(this.bobPrivateKey.replace("0x", ""), "hex")
      )

      await this.token
        .connect(this.bob)
        .permit(this.bob.address, this.alice.address, 1, deadline, v, r, s, {
          from: this.bob.address,
        })
    })

    it("Emits Approval event with expected arguments on successful execution of permit", async function () {
      const nonce = await this.token.nonces(this.bob.address)

      const deadline =
        (await this.alice.provider._internalBlockNumber).respTime + 10000

      const digest = await getApprovalDigest(
        this.token,
        {
          owner: this.bob.address,
          spender: this.alice.address,
          value: 1,
        },
        nonce,
        deadline,
        this.alice.provider._network.chainId
      )

      const { v, r, s } = ecsign(
        Buffer.from(digest.slice(2), "hex"),
        Buffer.from(this.bobPrivateKey.replace("0x", ""), "hex")
      )

      expect(
        this.token
          .connect(this.bob)
          .permit(this.bob.address, this.alice.address, 1, deadline, v, r, s, {
            from: this.bob.address,
          })
      )
        .to.emit(this.token, "Approval")
        .withArgs(this.bob.address, this.alice.address, 1)
    })

    it("Reverts on expired deadline", async function () {
      let nonce = await this.token.nonces(this.bob.address)

      const deadline = 0

      const digest = await getApprovalDigest(
        this.token,
        {
          owner: this.bob.address,
          spender: this.alice.address,
          value: 1,
        },
        nonce,
        deadline,
        this.alice.provider._network.chainId
      )
      const { v, r, s } = ecsign(
        Buffer.from(digest.slice(2), "hex"),
        Buffer.from(this.bobPrivateKey.replace("0x", ""), "hex")
      )

      expect(
        this.token
          .connect(this.bob)
          .permit(this.bob.address, this.alice.address, 1, deadline, v, r, s, {
            from: this.bob.address,
          })
      ).to.be.revertedWith("Expired")
    })

    it("Reverts on invalid signiture", async function () {
      let nonce = await this.token.nonces(this.bob.address)

      const deadline =
        (await this.bob.provider._internalBlockNumber).respTime + 10000

      const digest = await getApprovalDigest(
        this.token,
        {
          owner: this.bob.address,
          spender: this.alice.address,
          value: 1,
        },
        nonce,
        deadline,
        this.alice.provider._network.chainId
      )
      const { v, r, s } = ecsign(
        Buffer.from(digest.slice(2), "hex"),
        Buffer.from(this.bobPrivateKey.replace("0x", ""), "hex")
      )

      expect(
        this.token
          .connect(this.bob)
          .permit(this.bob.address, this.alice.address, 1, deadline, v, r, s, {
            from: this.bob.address,
          })
      ).to.be.revertedWith("Invalid Signature")
    })
  })
})
