const { ADDRESS_ZERO } = require("./utilities")
const { expect } = require("chai")

describe("Ownable", function () {
  before(async function () {
    this.Ownable = await ethers.getContractFactory("OwnableMock")
    const [owner, alice] = await ethers.getSigners()
    this.owner = owner
    this.alice = alice
  })

  beforeEach(async function () {
    this.ownable = await this.Ownable.deploy()
    await this.ownable.deployed()
  })

  describe("Deployment", function () {
    it("Assigns owner", async function () {
      expect(await this.ownable.owner()).to.equal(this.owner.address)
    })
  })

  describe("Renounce Ownership", function () {
    it("Prevents non-owners from renouncement", async function () {
      await expect(
        this.ownable
          .connect(this.alice)
          .renounceOwnership({ from: this.alice.address })
      ).to.be.revertedWith("Ownable: caller is not the owner")
    })

    it("Assigns owner to address zero", async function () {
      expect(this.ownable.renounceOwnership())
        .to.emit(this.ownable, "OwnershipTransferred")
        .withArgs(this.owner.address, ADDRESS_ZERO)

      expect(await this.ownable.owner()).to.equal(ADDRESS_ZERO)
    })
  })

  describe("Transfer Ownership", function () {
    it("Prevents non-owners from transferring", async function () {
      await expect(
        this.ownable
          .connect(this.alice)
          .transferOwnership(this.alice.address, { from: this.alice.address })
      ).to.be.revertedWith("Ownable: caller is not the owner")
    })

    it("Guards ownership against stuck state", async function () {
      await expect(this.ownable.transferOwnership(ADDRESS_ZERO)).to.be.revertedWith(
        "Ownable: new owner is the zero address"
      )
    })

    it("Changes pending owner after transfer", async function () {
      await this.ownable.transferOwnership(this.alice.address)

      expect(await this.ownable.pendingOwner()).to.equal(this.alice.address)
    })
  })

  describe("Transfer Ownership Direct", function () {
    it("Reverts given a zero address as newOwner argument", async function () {
      await expect(this.ownable.transferOwnership(ADDRESS_ZERO)).to.be.revertedWith(
        "Ownable: new owner is the zero address"
      )
    })

    it("Mutates owner", async function () {
      await this.ownable.transferOwnershipDirect(this.alice.address)

      expect(await this.ownable.owner()).to.equal(this.alice.address)
    })

    it("Emit OwnershipTransferred event with expected arguments", async function () {
      expect(this.ownable.transferOwnershipDirect(this.alice.address))
        .to.emit(this.ownable, "OwnershipTransferred")
        .withArgs(this.owner.address, this.alice.address)
    })
  })

  describe("Claim Ownership", function () {
    it("Mutates owner", async function () {
      await this.ownable.transferOwnership(this.alice.address)

      await this.ownable
        .connect(this.alice)
        .claimOwnership({ from: this.alice.address })

      expect(await this.ownable.owner()).to.equal(this.alice.address)
    })

    it("Assigns previous owner to address zero", async function () {
      await this.ownable.transferOwnership(this.alice.address)

      await this.ownable
        .connect(this.alice)
        .claimOwnership({ from: this.alice.address })

      expect(await this.ownable.pendingOwner()).to.equal(ADDRESS_ZERO)
    })

    it("Prevents anybody but pending owner from claiming ownership", async function () {
      await expect(
        this.ownable
          .connect(this.alice)
          .claimOwnership({ from: this.alice.address })
      ).to.be.revertedWith("Ownable: caller is not the pending owner")
    })

    it("Emit OwnershipTransferred event with expected arguments", async function () {
      await this.ownable.transferOwnership(this.alice.address)

      expect(
        this.ownable
          .connect(this.alice)
          .claimOwnership({ from: this.alice.address })
      )
        .to.emit(this.ownable, "OwnershipTransferred")
        .withArgs(this.owner.address, this.alice.address)
    })
  })
})
