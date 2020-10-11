const truffleAssert = require('./helpers/truffle-assertions');
const timeWarp = require("./helpers/timeWarp");
const AssertionError = require('./helpers/assertion-error');

const Vault = artifacts.require("Vault");
const A = artifacts.require("TokenA");
const B = artifacts.require("TokenB");
const Pair = artifacts.require("Pair");
const TestOracle = artifacts.require("TestOracle");
const SushiSwapDelegateSwapper = artifacts.require("SushiSwapDelegateSwapper");

function e18(amount) {
  return new web3.utils.BN(amount).mul(new web3.utils.BN("1000000000000000000"));
}

contract('Pair (Shorting)', (accounts) => {
  let a;
  let b;
  let pair_address;
  let pair;
  let vault;
  let swapper;
  const alice = accounts[1];
  const bob = accounts[2];
  const dummy = accounts[4];

  before(async () => {
    a = await A.deployed();
    b = await B.deployed();

    a.transfer(alice, e18(1000));
    b.transfer(bob, e18(1000));

    vault = await Vault.deployed();
    let raw_logs = await web3.eth.getPastLogs({
      fromBlock: 1,
      address: vault.address,
      topics: ['0xbb3432dd011e3a520780a665a087a29ccda830ea796ec3d85f051c7340a59c7f']
    });
    pair_address = "0x" + raw_logs[0].data.slice(raw_logs[0].data.length - 40);
    pair = await Pair.at(pair_address);
    oracle = await TestOracle.at(await pair.oracle());
    await pair.updateExchangeRate();
    swapper = await SushiSwapDelegateSwapper.deployed();
  });

  it('should take deposits', async () => {
    await a.approve(vault.address, e18(100), { from: alice });
    await pair.addA(e18(100), { from: alice });

    await b.approve(vault.address, e18(1000), { from: bob });
    await pair.addB(e18(1000), { from: bob });
  });

  it("should not allow shorting if it doesn't return enough of token A", async () => {
    await truffleAssert.reverts(pair.short(swapper.address, e18(200), e18(200), { from: alice }), 'BentoBox: Swap failed');
  });

  it("should not allow shorting into insolvency", async () => {
    await truffleAssert.reverts(pair.short(swapper.address, e18(300), e18(200), { from: alice }), 'BentoBox: user insolvent');
  });

  it('should allow shorting', async () => {
    await pair.short(swapper.address, e18(250), e18(230), { from: alice });
  });

  it('should have correct balances after short', async () => {
    assert.equal((await pair.users(alice)).shareA.toString(), "337414868790779635185");
    assert.equal((await pair.users(alice)).shareB.toString(), "0");
    assert.equal((await pair.users(alice)).borrowShare.toString(), "250000000000000000000");
  })
});
