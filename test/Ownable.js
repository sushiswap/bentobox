const { ADDRESS_ZERO, createFixture } = require("./utilities")
const { expect } = require("chai")

let cmd, fixture

describe("Ownable", function () {
    before(async function () {
        fixture = await createFixture(deployments, this, async (cmd) => {
            await cmd.deploy("ownable", "BentoBoxMock", ADDRESS_ZERO)
        })
    })

    beforeEach(async function () {
        cmd = await fixture()
    })

    describe("Deployment", function () {
        it("Assigns owner", async function () {
            expect(await this.ownable.owner()).to.equal(this.alice.address)
        })
    })

    describe("Renounce Ownership", function () {
        it("Prevents non-owners from renouncement", async function () {
            await expect(this.ownable.connect(this.bob).transferOwnership(ADDRESS_ZERO, true, true)).to.be.revertedWith(
                "Ownable: caller is not the owner"
            )
        })

        it("Assigns owner to address zero", async function () {
            await expect(this.ownable.transferOwnership(ADDRESS_ZERO, true, true))
                .to.emit(this.ownable, "OwnershipTransferred")
                .withArgs(this.alice.address, ADDRESS_ZERO)

            expect(await this.ownable.owner()).to.equal(ADDRESS_ZERO)
        })
    })

    describe("Transfer Ownership", function () {
        it("Prevents non-owners from transferring", async function () {
            await expect(
                this.ownable.connect(this.bob).transferOwnership(this.bob.address, false, false, { from: this.bob.address })
            ).to.be.revertedWith("Ownable: caller is not the owner")
        })

        it("Changes pending owner after transfer", async function () {
            await this.ownable.transferOwnership(this.bob.address, false, false)

            expect(await this.ownable.pendingOwner()).to.equal(this.bob.address)
        })
    })

    describe("Transfer Ownership Direct", function () {
        it("Reverts given a zero address as newOwner argument", async function () {
            await expect(this.ownable.transferOwnership(ADDRESS_ZERO, true, false)).to.be.revertedWith("Ownable: zero address")
        })

        it("Mutates owner", async function () {
            await this.ownable.transferOwnership(this.bob.address, true, false)

            expect(await this.ownable.owner()).to.equal(this.bob.address)
        })

        it("Emit OwnershipTransferred event with expected arguments", async function () {
            await expect(this.ownable.transferOwnership(this.bob.address, true, false))
                .to.emit(this.ownable, "OwnershipTransferred")
                .withArgs(this.alice.address, this.bob.address)
        })
    })

    describe("Claim Ownership", function () {
        it("Mutates owner", async function () {
            await this.ownable.transferOwnership(this.bob.address, false, false)

            await this.ownable.connect(this.bob).claimOwnership({ from: this.bob.address })

            expect(await this.ownable.owner()).to.equal(this.bob.address)
        })

        it("Assigns previous owner to address zero", async function () {
            await this.ownable.transferOwnership(this.bob.address, false, false)

            await this.ownable.connect(this.bob).claimOwnership({ from: this.bob.address })

            expect(await this.ownable.pendingOwner()).to.equal(ADDRESS_ZERO)
        })

        it("Prevents anybody but pending owner from claiming ownership", async function () {
            await expect(this.ownable.connect(this.bob).claimOwnership({ from: this.bob.address })).to.be.revertedWith(
                "Ownable: caller != pending owner"
            )
        })

        it("Emit OwnershipTransferred event with expected arguments", async function () {
            await this.ownable.transferOwnership(this.bob.address, false, false)

            await expect(this.ownable.connect(this.bob).claimOwnership({ from: this.bob.address }))
                .to.emit(this.ownable, "OwnershipTransferred")
                .withArgs(this.alice.address, this.bob.address)
        })
    })
})
