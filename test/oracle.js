const truffleAssert = require('./helpers/truffle-assertions');
const timeWarp = require("./helpers/timeWarp");
const AssertionError = require('./helpers/assertion-error');

const Vault = artifacts.require("Vault");
const PeggedOracle = artifacts.require("PeggedOracle");

function e18(amount) {
    return new web3.utils.BN(amount).mul(new web3.utils.BN("1000000000000000000"));
}

contract('PeggedOracle', (accounts) => {
    let oracle;

    before(async () => {
        oracle = await PeggedOracle.new({ from: accounts[0] });
        await oracle.init("1000000000000000000", "0x30a0911731f6eC80c87C4b99f27c254639A3Abcd");
    });

    it('should return 0 on rate request for non-existant pair', async () => {
        let result = await oracle.peek("0x9e6e344f94305d36eA59912b0911fE2c9149Ed3E");
        assert.equal(result.toString(), "0");
    });

    it('should return 1e18 on rate request for deployed pair', async () => {
        let result = await oracle.peek("0x30a0911731f6eC80c87C4b99f27c254639A3Abcd");
        assert.equal(result.toString(), "1000000000000000000");
    });

});
