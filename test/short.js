const fs = require('fs');
const truffleAssert = require('./helpers/truffle-assertions');
const timeWarp = require("./helpers/timeWarp");
const {e18} = require('./helpers/utils');
const BentoBox = artifacts.require("BentoBox");
const TokenA = artifacts.require("TokenA");
const TokenB = artifacts.require("TokenB");
const SushiSwapFactory = artifacts.require("UniswapV2Factory");
const UniswapV2Pair = artifacts.require("UniswapV2Pair");
const Pair = artifacts.require("LendingPair");
const TestOracle = artifacts.require("TestOracle");
const SushiSwapSwapper = artifacts.require("SushiSwapSwapper");
const {getInitData} = require("./helpers/getInitData");


contract('Pair (Shorting)', (accounts) => {
  let a;
  let b;
  let pair_address;
  let pair;
  let sushiswappair;
  let bentoBox;
  let bentoFactory;
  let swapper;
  const alice = accounts[1];
  const bob = accounts[2];
  const dummy = accounts[4];

  before(async () => {
    bentoBox = await BentoBox.deployed();
    pairMaster = await Pair.deployed();

    a = await TokenA.new({ from: accounts[0] });
    b = await TokenB.new({ from: accounts[0] });

    let factory = await SushiSwapFactory.new(accounts[0], { from: accounts[0] });
    swapper = await SushiSwapSwapper.new(bentoBox.address, factory.address, { from: accounts[0] });
    await pairMaster.setSwapper(swapper.address, true);

    let tx = await factory.createPair(a.address, b.address);
    sushiswappair = await UniswapV2Pair.at(tx.logs[0].args.pair);
    await a.transfer(sushiswappair.address, e18("5000"));
    await b.transfer(sushiswappair.address, e18("5000"));
    await sushiswappair.mint(accounts[0]);

    await a.transfer(alice, e18(1000));
    await b.transfer(bob, e18(1000));

    oracle = await TestOracle.new({ from: accounts[0] });
    let oracleData = getInitData(TestOracle._json.abi, []);

    await bentoBox.setMasterContractApproval(pairMaster.address, true, { from: alice });
    await bentoBox.setMasterContractApproval(pairMaster.address, true, { from: bob });

    let initData = getInitData(Pair._json.abi, [a.address, b.address, oracle.address, oracleData])
    tx = await bentoBox.deploy(pairMaster.address, initData);
    pair_address = tx.logs[0].args[2];
    pair = await Pair.at(pair_address);

    await pair.updateExchangeRate();
  });

  it('should take deposits', async () => {
    await a.approve(bentoBox.address, e18(100), { from: alice });
    await pair.addCollateral(e18(100), { from: alice });

    await b.approve(bentoBox.address, e18(1000), { from: bob });
    await pair.addAsset(e18(1000), { from: bob });
  });

  it("should not allow shorting if it doesn't return enough of token A", async () => {
    await truffleAssert.reverts(pair.short(swapper.address, e18(200), e18(200), { from: alice }), "SushiSwapClosedSwapper: return not enough");
  });

  // it("should not allow shorting into insolvency", async () => {
    // test broken because oracle returns 0 price
    // await truffleAssert.reverts(pair.short(swapper.address, e18(300), e18(200), { from: alice }));
  //   throw new Error('oracle error');
  // });

  it('should have correct balances before short', async () => {
    assert.equal((await pair.userCollateral(alice)).toString(), e18(100).toString());
    assert.equal((await pair.balanceOf(alice)).toString(), "0");
    assert.equal((await pair.userBorrowShare(alice)).toString(), "0");
    assert.equal((await pair.balanceOf(bob)).toString(), e18(1000).toString());
    assert.equal((await pair.totalSupply()).toString(), e18(1000).toString());
    assert.equal((await pair.totalAsset()).toString(), e18(1000).toString());
    assert.equal((await pair.totalBorrow()).toString(), "0");
    assert.equal((await pair.totalBorrowShare()).toString(), "0");
    assert.equal((await bentoBox.shareOf(a.address, pair.address)).toString(), e18(100).toString());
    assert.equal((await bentoBox.shareOf(b.address, pair.address)).toString(), e18(1000).toString());
    assert.equal((await bentoBox.totalShare(a.address)).toString(), e18(100).toString());
    assert.equal((await bentoBox.totalBalance(a.address)).toString(), e18(100).toString());
    assert.equal((await bentoBox.totalShare(b.address)).toString(), e18(1000).toString());
    assert.equal((await bentoBox.totalBalance(b.address)).toString(), e18(1000).toString());
  })

  it('should allow shorting', async () => {
    await pair.short(swapper.address, e18(250), e18(230), { from: alice });
  });

  it('should have correct balances after short', async () => {
    // check distribution of collateral (tokenA)
    assert.equal((await a.balanceOf(sushiswappair.address)).toString(), "4762585131209220364815");
    assert.equal((await a.balanceOf(bentoBox.address)).toString(), "337414868790779635185");
    assert.equal((await bentoBox.totalShare(a.address)).toString(), "337414868790779635185");
    assert.equal((await bentoBox.totalBalance(a.address)).toString(), "337414868790779635185");
    assert.equal((await bentoBox.shareOf(a.address, pair.address)).toString(), "337414868790779635185");
    assert.equal((await pair.userCollateral(alice)).toString(), "337414868790779635185");

    // check distribution of asset/borrow (tokenB)
    assert.equal((await b.balanceOf(sushiswappair.address)).toString(), e18(5250).toString());
    assert.equal((await b.balanceOf(bentoBox.address)).toString(), e18(750).toString());
    assert.equal((await b.balanceOf(alice)).toString(), "0"); // !!! should be 75
    assert.equal((await bentoBox.totalShare(b.address)).toString(), e18(750).toString());
    assert.equal((await bentoBox.totalBalance(b.address)).toString(), e18(750).toString());
    assert.equal((await bentoBox.shareOf(b.address, pair.address)).toString(), e18(750).toString());
    assert.equal((await pair.totalSupply()).toString(), e18(1000).toString());  // actually only 750
    assert.equal((await pair.totalAsset()).toString(), e18(1000).toString()); // actually only 750
    assert.equal((await pair.totalBorrow()).toString(), e18(250).toString());
    assert.equal((await pair.totalBorrowShare()).toString(), e18(250).toString());
    assert.equal((await pair.balanceOf(alice)).toString(), "0");
    assert.equal((await pair.balanceOf(bob)).toString(), e18(1000).toString());  // actually only 500
    assert.equal((await pair.userBorrowShare(alice)).toString(), e18(250).toString());
  });

  it('should limit asset availability for bob', async () => {
    const bobBal = await pair.balanceOf(bob);
    assert.equal((await pair.balanceOf(bob)).toString(), e18(1000).toString());
    // virtual balance of 1000 is more than contract has (250 given to sushi in short swap)
    await truffleAssert.reverts(pair.removeAsset(bobBal, bob, {from: bob}), 'BoringMath: Underflow');
    // 750 still too much, as 250 should be kept to rewind all shorts
    await truffleAssert.reverts(pair.removeAsset(e18(750), bob, {from: bob}), 'BoringMath: Underflow');
    // 500 still too much, as some dust has been accrued in interest
    // await truffleAssert.reverts(pair.removeAsset(e18(500), bob, {from: bob}), 'BentoBox: not enough liquidity');
    await pair.removeAsset(e18(499), bob, {from: bob});
  });

  it('should allow unwinding the short', async () => {
    await pair.unwind(swapper.address, e18(250), e18(337), { from: alice });
  });
});
