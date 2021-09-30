const { ADDRESS_ZERO, setMasterContractApproval, createFixture, getBigNumber, advanceTime, advanceTimeAndBlock } = require("./utilities")
const { expect } = require("chai")
const { ethers, network } = require("hardhat")

let cmd, fixture

describe.only("ALCXStrategy", async function () {
    const _alcx = "0xdBdb4d16EdA451D0503b854CF79D55697F90c8DF"
    const factory = "0xc35DADB65012eC5796536bD9864eD8773aBc74C4"

    before(async function () {
        this.timeout(30000)

        await network.provider.request({
            method: "hardhat_reset",
            params: [
                {
                    forking: {
                        jsonRpcUrl: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_API_KEY}`,
                        blockNumber: 13316576,
                    },
                },
            ],
        })

        console.log("hey")

        fixture = await createFixture(deployments, this, async (cmd) => {
            await cmd.deploy("weth9", "WETH9Mock")
            await cmd.deploy("bentoBox", "BentoBoxMock", this.weth9.address)
            await cmd.deploy("alcxStrategy", "ALCXStrategy", [
                _alcx,
                this.bentoBox.address,
                this.alice.address,
                factory,
                this.weth9.address,
            ])
        })
        cmd = await fixture()

        const tokenFactory = await ethers.getContractFactory("RevertingERC20Mock")
        this.alcx = tokenFactory.attach(_alcx)

        const alcxWhale = "0x000000000000000000000000000000000000dEaD"
        await network.provider.request({ method: "hardhat_impersonateAccount", params: [alcxWhale] })
        const signer = await ethers.getSigner(alcxWhale)
        await this.alcx.connect(signer).transfer(this.alice.address, getBigNumber(10000, 18)) // 10k ALCX
        await this.alcx.approve(this.bentoBox.address, getBigNumber(10000, 18))
    })

    it("allows to set strategy", async function () {
        expect((await this.alcx.balanceOf(this.alice.address)).gt(0), "Polygon not forked")
        await this.bentoBox.setStrategy(_alcx, this.alcxStrategy.address)
        expect(await this.bentoBox.pendingStrategy(_alcx)).to.be.equal(this.alcxStrategy.address)
        await advanceTime(1209600, ethers)
        await this.bentoBox.setStrategy(_alcx, this.alcxStrategy.address)
        expect(await this.bentoBox.strategy(_alcx)).to.be.equal(this.alcxStrategy.address)
        await this.bentoBox.setStrategyTargetPercentage(_alcx, 80)
        expect((await this.bentoBox.strategyData(_alcx)).targetPercentage).to.be.equal(80)
        await this.bentoBox.deposit(_alcx, this.alice.address, this.alice.address, getBigNumber(10000, 18), 0) // 5 mil
        expect((await this.bentoBox.strategyData(_alcx)).balance).to.be.equal(0)
        await this.bentoBox.harvest(_alcx, true, 0)
        expect((await this.bentoBox.strategyData(_alcx)).balance).to.be.equal(getBigNumber(8000, 18))
    }).timeout(30000)

    it("reports a profit", async function () {
        const oldBalance = (await this.bentoBox.totals(_alcx)).elastic
        await advanceTimeAndBlock(1209600, ethers)
        await this.alcxStrategy.safeHarvest(getBigNumber(10000000, 18), false, 0, false)
        const newBalance = (await this.bentoBox.totals(_alcx)).elastic
        expect(oldBalance.lt(newBalance))
    })

    it("rebalances", async function () {
        await this.bentoBox.withdraw(_alcx, this.alice.address, this.alice.address, getBigNumber(2000, 18), 0) // withdraw a mil
        const oldBalance = await this.alcx.balanceOf(this.bentoBox.address)
        const oldStrategyAllocation = (await this.bentoBox.strategyData(_alcx)).balance
        await this.alcxStrategy.safeHarvest(0, true, 0, false)
        const newBalance = await this.alcx.balanceOf(this.bentoBox.address)
        const newStrategyAllocation = (await this.bentoBox.strategyData(_alcx)).balance
        expect(oldBalance.lt(newBalance))
        expect(oldStrategyAllocation.gt(newStrategyAllocation))
    })

    it("exits", async function () {
        await cmd.deploy("alcxStrategy2", "ALCXStrategy", [
            _alcx,
            this.bentoBox.address,
            this.alice.address,
            factory,
            this.weth9.address,
        ])
        await this.bentoBox.setStrategy(_alcx, this.alcxStrategy2.address)
        await advanceTime(1209600, ethers)
        await this.bentoBox.setStrategy(_alcx, this.alcxStrategy2.address)
        const balance = await this.alcx.balanceOf(this.bentoBox.address)
        const elastic = (await this.bentoBox.totals(_alcx)).elastic
        expect(balance.eq(elastic))
    })
})
