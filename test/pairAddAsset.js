const truffleAssert = require('./helpers/truffle-assertions');
const timeWarp = require("./helpers/timeWarp");
const permit = require("./helpers/permit");
const {e9, assertBN, encodePrice, getInitData, getDataParameter, sansBorrowFee, signERC2612Permit} = require("./helpers/utils");
const BentoBox = artifacts.require("BentoBox");
const RebaseToken = artifacts.require("RebaseToken");
const RevertingERC20 = artifacts.require("RevertingERC20");
const SushiSwapFactory = artifacts.require("UniswapV2Factory");
const UniswapV2Pair = artifacts.require("UniswapV2Pair");
const Pair = artifacts.require("LendingPair");
const TestOracle = artifacts.require("TestOracle");
const SushiSwapSwapper = artifacts.require("SushiSwapSwapper");
const ethereumjsUtil = require('ethereumjs-util');
const {ecsign} = ethereumjsUtil;

contract('LendingPair', (accounts) => {
  let a;
  let b;
  let pair_address;
  let pair;
  let bentoBox;
  let bentoFactory;
  let swapper;
  const alice = accounts[1];
  const bob = accounts[2];
  const charlie = accounts[3]
  const charliePrivateKey = "0x328fb00abf72d3c33b7732c3cdfdfd93300fcfef0807952f8f766a1b09f17b94";
  const charlieAddress = "0xCa6f9b85Ece7F9Dc8e6461cF639992eC7c275aEE";

  before(async () => {
    bentoBox = await BentoBox.deployed();
    pairMaster = await Pair.deployed();

    a = await RevertingERC20.new("Token B", "B", e18(10000000), { from: accounts[0] });
    b = await RebaseToken.new("Rebase Token", "RBT", { from: accounts[0] });

    let factory = await SushiSwapFactory.new(accounts[0], { from: accounts[0] });
    swapper = await SushiSwapSwapper.new(bentoBox.address, factory.address, { from: accounts[0] });
    await pairMaster.setSwapper(swapper.address, true);

    let tx = await factory.createPair(a.address, b.address);
    let sushiswappair = await UniswapV2Pair.at(tx.logs[0].args.pair);
    await a.transfer(sushiswappair.address, e18("5000"));
    await b.transfer(sushiswappair.address, e9("5000"));
    await sushiswappair.mint(accounts[0]);

    await a.transfer(alice, e18(1000));
    await b.transfer(bob, e9(1000));
    await b.transfer(charlie, e9(1000));

    oracle = await TestOracle.new({ from: accounts[0] });
    await oracle.set(e18(1000000000), accounts[0]);
    let oracleData = await oracle.getDataParameter();

    await bentoBox.setMasterContractApproval(pairMaster.address, true, { from: alice });
    await bentoBox.setMasterContractApproval(pairMaster.address, true, { from: bob });
    await bentoBox.setMasterContractApproval(pairMaster.address, true, { from: charlie });
    let initData = await pairMaster.getInitData(a.address, b.address, oracle.address, oracleData);
    tx = await bentoBox.deploy(pairMaster.address, initData);
    pair_address = tx.logs[0].args[2];
    pair = await Pair.at(pair_address);

    await pair.updateExchangeRate();
  });

  it('should take a deposit of assets', async () => {
    await b.approve(bentoBox.address, e9(100), { from: bob });
    await pair.addAsset(e9(100), { from: bob });
  });

  it('should have correct balances after supply of assets', async () => {
    assertBN(await pair.totalSupply(), e9(100));
    assertBN(await pair.balanceOf(bob), e9(100));
  })

  it('should take a deposit of collateral', async () => {
    await a.approve(bentoBox.address, e18(1000), { from: alice });
    await pair.addCollateral(e18(1000), { from: alice });
  });

  it('should allow borrowing with collateral up to 100%', async () => {
    await pair.borrow(e9(100), alice, { from: alice });
    console.log((await b.balanceOf(bentoBox.address)).toString(), "bentoBox amount");
  });

  it('should allow charlie to add assets and get same share', async () => {
    let total = await b.totalSupply();
    await b.rebase(`-${total / 2}`);
    // sync and check
    await bentoBox.sync(b.address);
    await b.approve(bentoBox.address, e18(50), { from: charlie });
    let assetShare = await bentoBox.toShare(b.address, e9(50));
    await pair.addAsset(e9(50), { from: charlie });
    console.log("assetShare", assetShare.toString(), "total Supply", (await pair.totalSupply()).toString(), "bob", (await pair.balanceOf(bob)).toString(), "charlie", (await pair.balanceOf(charlie)).toString());
  });
});
