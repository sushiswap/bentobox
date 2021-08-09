const { ADDRESS_ZERO, setMasterContractApproval, createFixture, getBigNumber, advanceTime } = require("./utilities")
const { expect } = require("chai")
const { ethers, network } = require("hardhat")

let cmd, fixture

describe.only("AaveStrategy", function () {

    const lendingPool = "0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9"
    const factory = "0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac"
    const _usdc = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"
    const _aUsdc = "0xbcca60bb61934080951369a648fb03df4f96263c"

    before(async function () {
        fixture = await createFixture(deployments, this, async (cmd,) => {
            await cmd.deploy("sushi", "RevertingERC20Mock", "SUSHI", "SUSHI", 18, getBigNumber("10000000"))
            await cmd.deploy("weth9", "WETH9Mock")
            await cmd.deploy("bentoBox", "BentoBoxMock", this.weth9.address)
            await cmd.deploy("bar", "SushiBarMock", this.sushi.address)
            await cmd.deploy("aaveStrategy", "AaveStrategyNew", lendingPool, _usdc, this.bentoBox.address, this.alice.address, factory, [])
        })
        cmd = await fixture()

        const tokenFactory = await ethers.getContractFactory("RevertingERC20Mock")
        this.aUsdc = tokenFactory.attach(_aUsdc)
        this.usdc = tokenFactory.attach(_usdc)

        // get some mainnet usdc to alice - send from 0x39AA which has a bunch of usdc
        const usdcWhale = "0x39AA39c021dfbaE8faC545936693aC917d5E7563";
        await network.provider.request({ method: "hardhat_impersonateAccount", params: [usdcWhale] });
        await network.provider.send("hardhat_setBalance", [usdcWhale, "0x1000000000000000000",]);
        const signer = await ethers.getSigner(usdcWhale)
        await this.usdc.connect(signer).transfer(this.alice.address, getBigNumber(10000000, 6),) // 10 million
        await this.usdc.approve(this.bentoBox.address, getBigNumber(10000000, 6))
    })

    it("allows to set strategy", async function () {
        expect((await this.usdc.balanceOf(this.alice.address)).gt(0), "Mainnet not forked");
        expect((await this.usdc.balanceOf(_aUsdc)).gt(0), "Mainnet not forked");
        await this.bentoBox.setStrategy(_usdc, this.aaveStrategy.address)
        expect(await this.bentoBox.pendingStrategy(_usdc)).to.be.equal(this.aaveStrategy.address)
        await advanceTime(1209600, ethers)
        await this.bentoBox.setStrategy(_usdc, this.aaveStrategy.address)
        expect(await this.bentoBox.strategy(_usdc)).to.be.equal(this.aaveStrategy.address)
        await this.bentoBox.setStrategyTargetPercentage(_usdc, 80)
        expect((await this.bentoBox.strategyData(_usdc)).targetPercentage).to.be.equal(80)
        await this.bentoBox.deposit(_usdc, this.alice.address, this.alice.address, getBigNumber(5000000, 6), 0) // 5 mil
        expect((await this.bentoBox.strategyData(_usdc)).balance).to.be.equal(0)
        await this.bentoBox.harvest(_usdc, true, 0)
        expect((await this.bentoBox.strategyData(_usdc)).balance).to.be.equal(getBigNumber(4000000, 6))
    })

    it("reports a profit", async function () {
        await advanceTime(1209600, ethers) // 2 weeks of yield
        const oldBalance = (await this.bentoBox.totals(_usdc)).elastic
        await this.aaveStrategy.safeHarvest(getBigNumber(10000000, 6), false, 0, false)
        const newBalance = (await this.bentoBox.totals(_usdc)).elastic
        expect(oldBalance.lt(newBalance))
    })

    it("rebalances", async function () {
        await this.bentoBox.withdraw(_usdc, this.alice.address, this.alice.address, getBigNumber(1000000, 6), 0) // withdraw a mil
        const oldBalance = await this.usdc.balanceOf(this.bentoBox.address)
        const oldStrategyAllocation = (await this.bentoBox.strategyData(_usdc)).balance
        await this.aaveStrategy.safeHarvest(0, true, 0, false)
        const newBalance = await this.usdc.balanceOf(this.bentoBox.address)
        const newStrategyAllocation = (await this.bentoBox.strategyData(_usdc)).balance
        expect(oldBalance.lt(newBalance))
        expect(oldStrategyAllocation.gt(newStrategyAllocation))
    })

    it("exits", async function () {
        await cmd.deploy("aaveStrategy2", "AaveStrategyNew", lendingPool, _usdc, this.bentoBox.address, this.alice.address, factory, [])
        await this.bentoBox.setStrategy(_usdc, this.aaveStrategy2.address)
        await advanceTime(1209600, ethers)
        await this.bentoBox.setStrategy(_usdc, this.aaveStrategy2.address)
        const balance = await this.usdc.balanceOf(this.bentoBox.address)
        const elastic = (await this.bentoBox.totals(_usdc)).elastic
        expect(balance.eq(elastic))
    })

})
