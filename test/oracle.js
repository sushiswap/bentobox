const truffleAssert = require('./helpers/truffle-assertions');
const timeWarp = require("./helpers/timeWarp");
const AssertionError = require('./helpers/assertion-error');

const Vault = artifacts.require("Vault");
const PeggedOracle = artifacts.require("PeggedOracle");

function e18(amount) {
    return new web3.utils.BN(amount).mul(new web3.utils.BN("1000000000000000000"));
}

contract('PeggedOracle', (accounts) => {
    let vault;
    let oracle;
    let pair_address;
    const alice = accounts[1];
    const bob = accounts[2];
    const dummy = accounts[4];

    before(async () => {
        vault = await Vault.deployed();
        oracle = await PeggedOracle.deployed();
        pair_address = await vault.pairs(0);
    });

    it('should return 0 on rate request for non-existant pair', async () => {
        let result = await oracle.peek("0x9e6e344f94305d36eA59912b0911fE2c9149Ed3E");
        assert.equal(result.toString(), "0");
    });

    it('should return 1e18 on rate request for deployed pair', async () => {
        let result = await oracle.peek(pair_address);
        assert.equal(result.toString(), "1000000000000000000");
    });

});
