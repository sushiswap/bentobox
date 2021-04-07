const { setMasterContractApproval, createFixture, ADDRESS_ZERO } = require("./utilities")
const { expect } = require("chai")

let cmd, fixture

describe("MasterContractManager", function () {
    before(async function () {
        fixture = await createFixture(deployments, this, async (cmd) => {
            await cmd.deploy("weth9", "WETH9Mock")
            await cmd.deploy("bentoBox", "BentoBoxMock", this.weth9.address)

            await cmd.deploy("masterContractMock", "MasterContractMock", this.bentoBox.address)
            await cmd.deploy("badMaster", "MaliciousMasterContractMock")
        })
    })

    beforeEach(async function () {
        cmd = await fixture()
    })

    describe("Master Contract Approved", function () {
        it("Returns false for pair which has not been set", async function () {
            expect(await this.bentoBox.masterContractApproved(this.masterContractMock.address, this.alice.address)).to.be.false
        })

        it("Returns true for pair which has been set", async function () {
            await setMasterContractApproval(
                this.bentoBox,
                this.carol,
                this.carol,
                this.carolPrivateKey,
                this.masterContractMock.address,
                true,
                false
            )

            expect(await this.bentoBox.masterContractApproved(this.masterContractMock.address, this.carol.address)).to.be.true
        })
    })

    describe("whitelist Master Contract", function () {
        it("Reverts if caller is not the owner", async function () {
            await expect(this.bentoBox.connect(this.bob).whitelistMasterContract(this.masterContractMock.address, true)).to.be.revertedWith(
                "Ownable: caller is not the owner"
            )
        })

        it("Reverts if whitelisting address(0) as MasterContract", async function () {
            await expect(this.bentoBox.connect(this.alice).whitelistMasterContract(ADDRESS_ZERO, true)).to.be.revertedWith(
                "MasterCMgr: Cannot approve 0"
            )
            expect(await this.bentoBox.whitelistedMasterContracts(ADDRESS_ZERO)).to.be.false
        })

        it("Allows to WhiteList MasterContract", async function () {
            await this.bentoBox.connect(this.alice).whitelistMasterContract(this.masterContractMock.address, true)
            expect(await this.bentoBox.whitelistedMasterContracts(this.masterContractMock.address)).to.be.true
        })
    })

    describe("Set Master Contract Approval with WhiteList", function () {
        it("Reverts with address zero as masterContract", async function () {
            await expect(setMasterContractApproval(this.bentoBox, this.carol, this.carol, "", ADDRESS_ZERO, true, true)).to.be.revertedWith(
                "MasterCMgr: masterC not set"
            )
        })

        it("Reverts with non whiteListed master contract", async function () {
            await expect(
                setMasterContractApproval(this.bentoBox, this.carol, this.carol, "", "0x0000000000000000000000000000000000000001", true, true)
            ).to.be.revertedWith("MasterCMgr: not whitelisted")
        })

        it("Reverts with user not equal to sender", async function () {
            await this.bentoBox.whitelistMasterContract(this.masterContractMock.address, true)
            await expect(
                setMasterContractApproval(this.bentoBox, this.carol, this.alice, "", this.masterContractMock.address, true, true)
            ).to.be.revertedWith("MasterCMgr: user not sender")
        })

        it("Reverts with contract being a clone", async function () {
            const deployTx = await this.bentoBox.deploy(this.badMaster.address, "0x", true)
            const cloneAddress = (await deployTx.wait()).events[0].args.cloneAddress
            const badMasterClone = await this.badMaster.attach(cloneAddress)

            await expect(badMasterClone.attack(this.bentoBox.address)).to.be.revertedWith("MasterCMgr: user is clone")
        })

        it("Emits LogSetMasterContractApproval event with correct arguments", async function () {
            await this.bentoBox.whitelistMasterContract(this.masterContractMock.address, true)
            await expect(setMasterContractApproval(this.bentoBox, this.alice, this.alice, "", this.masterContractMock.address, true, true))
                .to.emit(this.bentoBox, "LogSetMasterContractApproval")
                .withArgs(this.masterContractMock.address, this.alice.address, true)
        })

        it("Should allow to retract approval of masterContract", async function () {
            await this.bentoBox.whitelistMasterContract(this.masterContractMock.address, true)

            await setMasterContractApproval(
                this.bentoBox,
                this.carol,
                this.carol,
                this.carolPrivateKey,
                this.masterContractMock.address,
                true,
                true
            )

            await setMasterContractApproval(
                this.bentoBox,
                this.carol,
                this.carol,
                this.carolPrivateKey,
                this.masterContractMock.address,
                false,
                true
            )

            expect(await this.bentoBox.masterContractApproved(this.masterContractMock.address, this.alice.address)).to.be.false
        })
    })

    describe("setMasterContractApproval with Permit", function () {
        it("Reverts with address zero as user", async function () {
            let test = "0x7465737400000000000000000000000000000000000000000000000000000000"
            await expect(
                this.bentoBox.setMasterContractApproval(
                    "0x0000000000000000000000000000000000000000",
                    this.masterContractMock.address,
                    true,
                    0,
                    test,
                    test
                )
            ).to.be.revertedWith("MasterCMgr: User cannot be 0")
        })
        it("Reverts if signature is incorrect", async function () {
            await expect(
                setMasterContractApproval(this.bentoBox, this.bob, this.bob, this.carolPrivateKey, this.masterContractMock.address, true, false)
            ).to.be.revertedWith("MasterCMgr: Invalid Signature")
        })
    })
})
