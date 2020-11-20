const truffleAssert = require('./helpers/truffle-assertions');
const timeWarp = require("./helpers/timeWarp");

const Vault = artifacts.require("Vault");
const TokenA = artifacts.require("TokenA");
const TokenB = artifacts.require("TokenB");
const SushiSwapFactory = artifacts.require("UniswapV2Factory");
const UniswapV2Pair = artifacts.require("UniswapV2Pair");
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
  let bentoFactory;
  let swapper;
  const alice = accounts[1];
  const bob = accounts[2];
  const dummy = accounts[4];

  before(async () => {
    vault = await Vault.deployed();
    pairMaster = await Pair.deployed();
    bentoFactory = await BentoFactory.deployed();

    a = await TokenA.new({ from: accounts[0] });
    b = await TokenB.new({ from: accounts[0] });

    let factory = await SushiSwapFactory.new(accounts[0], { from: accounts[0] });
    swapper = await SushiSwapDelegateSwapper.new(factory.address, { from: accounts[0] });
    await vault.setSwapper(swapper.address, true);

    let tx = await factory.createPair(a.address, b.address);
    let sushiswappair = await UniswapV2Pair.at(tx.logs[0].args.pair);
    await a.transfer(sushiswappair.address, e18("5000"));
    await b.transfer(sushiswappair.address, e18("5000"));
    await sushiswappair.mint(accounts[0]);

    await a.transfer(alice, e18(1000));
    await b.transfer(bob, e18(1000));

    oracle = await TestOracle.new({ from: accounts[0] });
    let oracleData = await oracle.getInitData("1000000000000000000");

    tx = await bentoFactory.createPair(a.address, b.address, oracle.address, oracleData);
    let pair_address = tx.logs[0].args[2];
    pair = await Pair.at(pair_address);

    await pair.updateExchangeRate();
  });

  it('should take deposits', async () => {
    await a.approve(vault.address, e18(100), { from: alice });
    await pair.addCollateral(e18(100), { from: alice });

    await b.approve(vault.address, e18(1000), { from: bob });
    await pair.addAsset(e18(1000), { from: bob });
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
    assert.equal((await pair.userCollateral(alice)).toString(), "337414868790779635185");
    assert.equal((await pair.balanceOf(alice)).toString(), "0");
    assert.equal((await pair.userBorrowShare(alice)).toString(), "250000000000000000000");
  })

  it('should allow unwinding the short', async () => {
    await pair.unwind(swapper.address, e18(250), e18(337), { from: alice });
  });
});
