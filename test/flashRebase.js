const truffleAssert = require('./helpers/truffle-assertions');
const timeWarp = require("./helpers/timeWarp");
const {e18, e9, getInitData, getDataParameter, sansBorrowFee} = require("./helpers/utils");
const BentoBox = artifacts.require("BentoBox");
const SushiSwapFactory = artifacts.require("UniswapV2Factory");
const UniswapV2Pair = artifacts.require("UniswapV2Pair");
const Pair = artifacts.require("LendingPair");
const RebaseToken = artifacts.require("RebaseToken");
const TestOracle = artifacts.require("TestOracle");
const SushiSwapSwapper = artifacts.require("SushiSwapSwapper");
const FlashLoanRebaseSkimmer = artifacts.require("FlashLoanRebaseSkimmer");

contract('FlashRebase', (accounts) => {
  let a;
  let b;
  let pair_address;
  let pair;
  let bentoBox;
  let bentoFactory;
  let swapper;
  const alice = accounts[1];
  const bob = accounts[2];
  const eve = accounts[3];

  before(async () => {
    bentoBox = await BentoBox.deployed();
    pairMaster = await Pair.deployed();

    a = await RebaseToken.new("Rebase Token A", "RBA", { from: accounts[0] });
    b = await RebaseToken.new("Rebase Token B", "RBB", { from: accounts[0] });

    let factory = await SushiSwapFactory.new(accounts[0], { from: accounts[0] });
    swapper = await SushiSwapSwapper.new(bentoBox.address, factory.address, { from: accounts[0] });
    await pairMaster.setSwapper(swapper.address, true);

    let tx = await factory.createPair(a.address, b.address);
    let sushiswappair = await UniswapV2Pair.at(tx.logs[0].args.pair);
    await a.transfer(sushiswappair.address, e9("5000")); // collateral
    await b.transfer(sushiswappair.address, e9("5000")); // asset
    await sushiswappair.mint(accounts[0]);

    await a.transfer(alice, e9(1000));
    await b.transfer(bob, e9(1000));

    oracle = await TestOracle.new({ from: accounts[0] });
    await oracle.set(e18(1), accounts[0]);

    await bentoBox.setMasterContractApproval(pairMaster.address, true, { from: alice });
    await bentoBox.setMasterContractApproval(pairMaster.address, true, { from: bob });

    let initData = await pairMaster.getInitData(a.address, b.address, oracle.address, "0x");
    tx = await bentoBox.deploy(pairMaster.address, initData);
    pair_address = tx.logs[0].args[2];
    pair = await Pair.at(pair_address);
  });


  it('rebase token without sync() breaks bento', async () => {
    // add liquidity
    await a.approve(bentoBox.address, e9(1000), {from: alice});
    await bentoBox.deposit(a.address, alice, e9(1000), {from: alice});

    // call flashloan
    const flrs = await FlashLoanRebaseSkimmer.new();
    const tx = await bentoBox.flashLoan(a.address, e9(500), flrs.address, "0x", {from: eve});

    // check profits
    const balance = await a.balanceOf(eve);
    assert.equal(balance.toString(), "499750000000");
  });

  

});
