const { ADDRESS_ZERO, setMasterContractApproval, createFixture, getBigNumber, advanceTime, advanceTimeAndBlock } = require("./utilities")
const { expect } = require("chai")
const { ethers, network } = require("hardhat")

let cmd, fixture

describe("AaveStrategy", async function () {
    // polygon addresses
    const lendingPool = "0x8dff5e27ea6b7ac08ebfdf9eb090f32ee9a30fcf"
    const factory = "0xc35DADB65012eC5796536bD9864eD8773aBc74C4"
    const _wmatic = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270"
    const _weth = "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619"
    const _usdc = "0x2791bca1f2de4661ed88a30c99a7a9449aa84174"
    const _aUsdc = "0x1a13f4ca1d028320a707d99520abfefca3998b7f"
    const incentiveControler = "0x357D51124f59836DeD84c8a1730D72B749d8BC23"

    before(async function () {
        this.timeout(30000)

        await network.provider.request({
            method: "hardhat_reset",
            params: [
                {
                    forking: {
                        jsonRpcUrl: `https://polygon-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
                        blockNumber: 19001343,
                    },
                },
            ],
        })

        fixture = await createFixture(deployments, this, async (cmd) => {
            await cmd.deploy("weth9", "WETH9Mock")
            await cmd.deploy("bentoBox", "BentoBoxMock", this.weth9.address)
            await cmd.deploy("aaveStrategy", "AaveStrategy", _wmatic, lendingPool, incentiveControler, [
                _usdc,
                this.bentoBox.address,
                this.alice.address,
                factory,
                _weth,
            ])
        })
        cmd = await fixture()

        const tokenFactory = await ethers.getContractFactory("RevertingERC20Mock")
        this.aUsdc = tokenFactory.attach(_aUsdc)
        this.usdc = tokenFactory.attach(_usdc)
        this.wmatic = tokenFactory.attach(_wmatic)

        const usdcWhale = "0xBA12222222228d8Ba445958a75a0704d566BF2C8"
        await network.provider.request({ method: "hardhat_impersonateAccount", params: [usdcWhale] })
        const signer = await ethers.getSigner(usdcWhale)
        await this.usdc.connect(signer).transfer(this.alice.address, getBigNumber(5000000, 6)) // 100k usdc
        await this.usdc.approve(this.bentoBox.address, getBigNumber(5000000, 6))
    })

    it("allows to set strategy", async function () {
        expect((await this.usdc.balanceOf(this.alice.address)).gt(0), "Polygon not forked")
        expect((await this.usdc.balanceOf(_aUsdc)).gt(0), "Polygon not forked")
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
    }).timeout(30000)

    it("claims rewards", async function () {
        const oldWmaticBalance = await this.wmatic.balanceOf(this.aaveStrategy.address)
        await advanceTimeAndBlock(1209600, ethers) // 2 weeks of yield
        await this.aaveStrategy.safeHarvest(0, true, 0, true)
        const newWmaticBalance = await this.wmatic.balanceOf(this.aaveStrategy.address)
        expect(oldWmaticBalance.lt(newWmaticBalance))
    })

    it("reports a profit", async function () {
        const oldBalance = (await this.bentoBox.totals(_usdc)).elastic
        await advanceTimeAndBlock(1209600, ethers)
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
        await cmd.deploy("aaveStrategy2", "AaveStrategy", _wmatic, lendingPool, incentiveControler, [
            _usdc,
            this.bentoBox.address,
            this.alice.address,
            factory,
            _weth,
        ])
        await this.bentoBox.setStrategy(_usdc, this.aaveStrategy2.address)
        await advanceTime(1209600, ethers)
        await this.bentoBox.setStrategy(_usdc, this.aaveStrategy2.address)
        const balance = await this.usdc.balanceOf(this.bentoBox.address)
        const elastic = (await this.bentoBox.totals(_usdc)).elastic
        expect(balance.eq(elastic))
    })
})
