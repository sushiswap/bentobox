const truffleAssert = require('./helpers/truffle-assertions');
const timeWarp = require("./helpers/timeWarp");
const AssertionError = require('./helpers/assertion-error');
const {e18} = require('./helpers/utils');

const BentoBox = artifacts.require("BentoBox");
const PeggedOracle = artifacts.require("PeggedOracle");

contract('PeggedOracle', (accounts) => {
    let oracle;
    let data;

    before(async () => {
        oracle = await PeggedOracle.new({ from: accounts[0] });
        data = await oracle.getDataParameter("1000000000000000000");
    });

    it('should return 1e18 on rate request', async () => {
        let result = await oracle.peek(data);
        assert.equal(result[1].toString(), "1000000000000000000");
    });
});
