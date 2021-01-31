const { ADDRESS_ZERO, setMasterContractApproval, prepare, deploymentsFixture, deploy } = require("./utilities")
const { expect } = require("chai")
const { LendingPair } = require("./utilities/lendingpair")

describe("MasterContractManager", function () {
  before(async function () {
    await prepare(this, ["MasterContractManagerMock", "MaliciousMasterContractMock"])
  })

  beforeEach(async function () {
    await deploymentsFixture(this, (cmd) => {})
    this.mcmanager = await this.MasterContractManagerMock.deploy()
    await this.mcmanager.deployed()
  })

  describe("Master Contract Approved", function () {
    it("Returns false for pair which has not been set", async function () {
      expect(await this.mcmanager.masterContractApproved(this.lendingPair.address, this.alice.address)).to.be.false
    })

    it("Returns true for pair which has been set", async function () {
      await setMasterContractApproval(this.mcmanager, this.carol, this.carol, this.carolPrivateKey, this.lendingPair.address, true, false)

      expect(await this.mcmanager.masterContractApproved(this.lendingPair.address, this.carol.address)).to.be.true
    })
  })

  describe("whitelist Master Contract", function () {
    it("Reverts if caller is not the owner", async function () {
      await expect(this.mcmanager.connect(this.bob).whitelistMasterContract(this.lendingPair.address, true)).to.be.revertedWith(
        "Ownable: caller is not the owner"
      )
    })

    it("Allows to WhiteList MasterContract", async function () {
      await this.mcmanager.connect(this.alice).whitelistMasterContract(this.lendingPair.address, true)
      expect(await this.mcmanager.whitelistedMasterContracts(this.lendingPair.address)).to.be.true
    })
  })

  describe("Set Master Contract Approval with WhiteList", function () {
    it("Reverts with address zero as masterContract", async function () {
      await expect(setMasterContractApproval(this.mcmanager, this.carol, this.carol, "", ADDRESS_ZERO, true, true)).to.be.revertedWith(
        "MasterCMgr: masterC not set"
      )
    })

    it("Reverts with non whiteListed master contract", async function () {
      await expect(
        setMasterContractApproval(this.mcmanager, this.carol, this.carol, "", "0x0000000000000000000000000000000000000001", true, true)
      ).to.be.revertedWith("MasterCMgr: not whitelisted")
    })

    it("Reverts with user not equal to sender", async function () {
      await this.mcmanager.whitelistMasterContract(this.lendingPair.address, true)
      await expect(
        setMasterContractApproval(this.mcmanager, this.carol, this.alice, "", this.lendingPair.address, true, true)
      ).to.be.revertedWith("MasterCMgr: user not sender")
    })

    it("Reverts with contract being a clone", async function () {
      await deploy(this, [["badMaster", this.MaliciousMasterContractMock]])
      const deployTx = await this.bentoBox.deploy(this.badMaster.address, "0x")
      const cloneAddress = (await deployTx.wait()).events[0].args.cloneAddress
      const badMasterClone = await this.badMaster.attach(cloneAddress)

      await expect(badMasterClone.attack(this.bentoBox.address)).to.be.revertedWith("MasterCMgr: user is clone")
    })

    it("Emits LogSetMasterContractApproval event with correct arguments", async function () {
      await this.mcmanager.whitelistMasterContract(this.lendingPair.address, true)
      await expect(setMasterContractApproval(this.mcmanager, this.alice, this.alice, "", this.lendingPair.address, true, true))
        .to.emit(this.mcmanager, "LogSetMasterContractApproval")
        .withArgs(this.lendingPair.address, this.alice.address, true)
    })

    it("Should allow to retract approval of masterContract", async function () {
      await this.mcmanager.whitelistMasterContract(this.lendingPair.address, true)

      await setMasterContractApproval(this.mcmanager, this.carol, this.carol, this.carolPrivateKey, this.lendingPair.address, true, true)

      await setMasterContractApproval(this.mcmanager, this.carol, this.carol, this.carolPrivateKey, this.lendingPair.address, false, true)

      expect(await this.mcmanager.masterContractApproved(this.lendingPair.address, this.alice.address)).to.be.false
    })
  })

  describe("setMasterContractApproval with Permit", function () {
    it("Reverts with address zero as user", async function () {
      let test = "0x7465737400000000000000000000000000000000000000000000000000000000"
      await expect(
        this.mcmanager.setMasterContractApproval("0x0000000000000000000000000000000000000000", this.lendingPair.address, true, 0, test, test)
      ).to.be.revertedWith("MasterCMgr: User cannot be 0")
    })
    it("Reverts if signature is incorrect", async function () {
      await expect(
        setMasterContractApproval(this.mcmanager, this.bob, this.bob, this.carolPrivateKey, this.lendingPair.address, true, false)
      ).to.be.revertedWith("MasterCMgr: Invalid Signature")
    })
  })
})
