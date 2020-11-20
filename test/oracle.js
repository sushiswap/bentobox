const truffleAssert = require('./helpers/truffle-assertions');
const timeWarp = require("./helpers/timeWarp");
const AssertionError = require('./helpers/assertion-error');
const {e18} = require('./helpers/utils');

const Vault = artifacts.require("Vault");
const PeggedOracle = artifacts.require("PeggedOracle");

contract('PeggedOracle', (accounts) => {
    let oracle;

    before(async () => {
        oracle = await PeggedOracle.new({ from: accounts[0] });
        await oracle.init("1000000000000000000");
    });

    it('should return 0 on rate request for non-existant pair', async () => {
        let result = await oracle.peek("0x9e6e344f94305d36eA59912b0911fE2c9149Ed3E");
        assert.equal(result.toString(), "0");
    });

    it('should return 1e18 on rate request for deployed pair', async () => {
        let result = await oracle.peek(accounts[0]);
        assert.equal(result.toString(), "1000000000000000000");
    });

});
