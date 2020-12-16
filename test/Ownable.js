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

  it("has an owner", async function () {
    expect(await this.ownable.owner()).to.equal(this.owner.address)
  })

  describe("transfer ownership", function () {
    it("changes pending owner after transfer", async function () {
      await this.ownable.transferOwnership(this.alice.address)

      expect(await this.ownable.pendingOwner()).to.equal(this.alice.address)
    })

    it("prevents non-owners from transferring", async function () {
      expect(
        this.ownable
          .connect(this.alice)
          .transferOwnership(this.alice.address, { from: this.alice.address })
      ).to.be.revertedWith("Ownable: caller is not the owner")
    })

    it("guards ownership against stuck state", async function () {
      expect(this.ownable.transferOwnership(ADDRESS_ZERO)).to.be.revertedWith(
        "Ownable: new owner is the zero address"
      )
    })
  })

  describe("transfer ownership direct", function () {
    it("changes owner", async function () {
      expect(this.ownable.transferOwnershipDirect(this.alice.address))
        .to.emit(this.ownable, "OwnershipTransferred")
        .withArgs(this.owner.address, this.alice.address)

      expect(await this.ownable.owner()).to.equal(this.alice.address)
    })
  })

  describe("renounce ownership", function () {
    it("loses owner after renouncement", async function () {
      expect(this.ownable.renounceOwnership())
        .to.emit(this.ownable, "OwnershipTransferred")
        .withArgs(this.owner.address, ADDRESS_ZERO)

      expect(await this.ownable.owner()).to.equal(ADDRESS_ZERO)
    })

    it("prevents non-owners from renouncement", async function () {
      expect(
        this.ownable
          .connect(this.alice)
          .renounceOwnership({ from: this.alice.address })
      ).to.be.revertedWith("Ownable: caller is not the owner")
    })
  })

  describe("claim ownership", function () {
    it("changes owner after pending owner claims ownership", async function () {
      await this.ownable.transferOwnership(this.alice.address)

      await this.ownable
        .connect(this.alice)
        .claimOwnership({ from: this.alice.address })

      expect(await this.ownable.owner()).to.equal(this.alice.address)
    })

    it("prevents anybody but pending owner from claiming ownership", async function () {
      expect(
        this.ownable
          .connect(this.alice)
          .claimOwnership({ from: this.alice.address })
      ).to.be.revertedWith("Ownable: caller is not the pending owner")
    })
  })
})
