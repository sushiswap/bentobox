const assert = require("assert")
const { getBigNumber, prepare, setMasterContractApproval, deploymentsFixture } = require("./utilities")

describe("HelloWorld", function () {
    const APPROVAL_AMOUNT = 1000

    before(async function () {
        await prepare(this, ["HelloWorld", "ReturnFalseERC20Mock"])
    })

    it("Setup", async function () {
        await deploymentsFixture(this, async (cmd) => {
            await cmd.addToken("tokenA", "Token A", "A", 18, this.ReturnFalseERC20Mock)
        })

        await this.HelloWorld.new("helloWorld", this.bentoBox.address, this.tokenA.address)
    })

    it("should reject deposit: no token- nor master contract approval", async function () {
        await assert.rejects(this.helloWorld.deposit(APPROVAL_AMOUNT))
    })

    it("approve BentoBox", async function () {
        await this.tokenA.approve(this.bentoBox.address, getBigNumber(APPROVAL_AMOUNT, await this.tokenA.decimals()))
    })

    it("should reject deposit: user approved, master contract not approved", async function () {
        await assert.rejects(this.helloWorld.deposit(APPROVAL_AMOUNT))
    })

    it("approve master contract", async function () {
        await setMasterContractApproval(this.bentoBox, this.alice, this.alice, this.alicePrivateKey, this.helloWorld.address, true)
    })

    it("should allow deposit", async function () {
        await this.helloWorld.deposit(APPROVAL_AMOUNT)
        assert.equal((await this.helloWorld.balance()).toString(), APPROVAL_AMOUNT.toString())
    })

    it("should allow withdraw", async function () {
        await this.helloWorld.withdraw()
    })
})
