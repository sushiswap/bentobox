const fs = require('fs');
const timeWarp = require("./helpers/timeWarp");
const truffleAssert = require('./helpers/truffle-assertions');
const {e18, encodePrice, getInitData, getDataParameter} = require("./helpers/utils");
const AssertionError = require('./helpers/assertion-error');
const MockERC20 = artifacts.require("MockERC20");
const BentoBox = artifacts.require("BentoBox");
const Pair = artifacts.require("LendingPair");
const SushiSwapFactory = artifacts.require("UniswapV2Factory");
const UniswapV2Pair = artifacts.require("UniswapV2Pair");
const SimpleSLPOracle0 = artifacts.require("SimpleSLPTWAP0Oracle");
const SimpleSLPOracle1 = artifacts.require("SimpleSLPTWAP1Oracle");
const CompositeOracle = artifacts.require("CompositeOracle");

const collateralAmount = e18(400); // sushi
const token1Amount = e18(1);   // eth
const assetAmount = e18(500); // dai

contract('CompositeOracle', (accounts) => {
  let bentoBox;
  let pairMaster;
  let collateral;
  let b;
  let asset;
  let pairA;
  let pairB;
  let oracleA;
  let oracleB;
  let bentoPairA;
  let bentoPairB;
  let bentoPairC;
  let oracleDataA;
  let oracleDataB;
  let compositeOracle;
  let oracleData;

  beforeEach(async () => {
    bentoBox = await BentoBox.deployed();
    pairMaster = await Pair.deployed();

    collateral = await MockERC20.new("Token A", "A", e18(10000000), { from: accounts[0] });
    b = await MockERC20.new("Token B", "B", e18(10000000), { from: accounts[0] });
    asset = await MockERC20.new("Token C", "C", e18(10000000), { from: accounts[0] });

    const factory = await SushiSwapFactory.new(accounts[0], { from: accounts[0] });

    // set up first bento pair
    let tx = await factory.createPair(collateral.address, b.address);
    pairA = await UniswapV2Pair.at(tx.logs[0].args.pair);

    await collateral.transfer(pairA.address, collateralAmount);
    await b.transfer(pairA.address, token1Amount);
    await pairA.mint(accounts[0]);
    if (b.address == (await pairA.token0())) {
           oracleA = await SimpleSLPOracle0.new();
       } else {
           oracleA = await SimpleSLPOracle1.new();
    }
    oracleDataA = await oracleA.getDataParameter(pairA.address);

    // set up second bento pair
    tx = await factory.createPair(b.address, asset.address);
    pairB = await UniswapV2Pair.at(tx.logs[0].args.pair);

    await b.transfer(pairB.address, token1Amount);
    await asset.transfer(pairB.address, assetAmount);
    await pairB.mint(accounts[0]);

    if (asset.address == (await pairA.token0())) {
           oracleB = await SimpleSLPOracle0.new();
       } else {
           oracleB = await SimpleSLPOracle1.new();
    }

    oracleDataB = await oracleB.getDataParameter(pairB.address);

    // set up composite oracle
    compositeOracle = await CompositeOracle.new();
    oracleData = await compositeOracle.getDataParameter(oracleA.address, oracleB.address, oracleDataA, oracleDataB);
    console.log(oracleData);
    initData = getInitData(Pair._json.abi, [collateral.address, asset.address, compositeOracle.address, oracleData])
    tx = await bentoBox.deploy(pairMaster.address, initData);
    bentoPairC = await Pair.at(tx.logs[0].args[2]);
  });

  it('update', async () => {
    // update both pairs
    await compositeOracle.get(oracleData);
    await timeWarp.advanceTime(61);
    await compositeOracle.get(oracleData);

    // check the composite oracle
    const expectedPrice = encodePrice(collateralAmount, assetAmount);
    const price = (await compositeOracle.peek(oracleData))[1];
    const rounding = new web3.utils.BN("100000000000000000"); // 10^16
    console.log("price", price.toString());
    assert.equal(price.divRound(rounding).toString(), collateralAmount.mul(new web3.utils.BN("100")).div(assetAmount).toString());
  });

  it('should update prices after swap', async () => {
    // update both pairs
    await compositeOracle.get(oracleData);
    await timeWarp.advanceTime(61);
    await compositeOracle.get(oracleData);

    // check the composite oracle
    const price0 = (await compositeOracle.peek(oracleData))[1];
    await collateral.transfer(pairA.address, e18(400));
    await timeWarp.advanceTime(30);
    await pairA.sync();
    await timeWarp.advanceTime(30);
    await compositeOracle.get(oracleData);
    let price1 = (await compositeOracle.peek(oracleData))[1];

    const rounding = new web3.utils.BN("100000000000000000"); // 10^16
    const oldPrice = collateralAmount.mul(new web3.utils.BN("100")).div(assetAmount);
    const newPrice = oldPrice.add((collateralAmount.mul(new web3.utils.BN("100")).mul(new web3.utils.BN("2"))).div(assetAmount)).divRound(new web3.utils.BN("2"));
    assert.equal(price0.divRound(rounding).toString(), oldPrice.toString());
    assert.equal(price1.divRound(rounding).toString(), newPrice.toString(), "prices should be exactly half way between price points");
  });
});
