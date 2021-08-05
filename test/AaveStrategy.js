const { ADDRESS_ZERO, setMasterContractApproval, createFixture, getBigNumber, advanceTime } = require("./utilities")
const { expect } = require("chai")
const { ethers } = require("hardhat")

let cmd, fixture

describe.only("AaveStrategy", function () {
    const aave = "0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9"
    const factory = "0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac"
    const usdc = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"

    before(async function () {
        fixture = await createFixture(deployments, this, async (cmd) => {
            await cmd.deploy("sushi", "RevertingERC20Mock", "SUSHI", "SUSHI", 18, getBigNumber("10000000"))
            await cmd.deploy("weth9", "WETH9Mock")
            await cmd.deploy("bentoBox", "BentoBoxMock", this.weth9.address)
            await cmd.deploy("bar", "SushiBarMock", this.sushi.address)
            await cmd.deploy("sushiStrategy", "SushiStrategy", this.bar.address, this.sushi.address)
            // await cmd.deploy("aaveStrategy", "AaveStrategy", aave, factory, this.bentoBox.address, usdc)
        })
        cmd = await fixture()
    })
})
