const timeWarp = require("./helpers/timeWarp");
const truffleAssert = require('./helpers/truffle-assertions');
const {e18, e9, encodePrice, getInitData, getDataParameter} = require("./helpers/utils");
const AssertionError = require('./helpers/assertion-error');
const ReturnFalseERC20 = artifacts.require("ReturnFalseERC20");
const SushiSwapFactory = artifacts.require("UniswapV2Factory");
const UniswapV2Pair = artifacts.require("UniswapV2Pair");
const SimpleSLPOracle0 = artifacts.require("SimpleSLPTWAP0Oracle");
const SimpleSLPOracle1 = artifacts.require("SimpleSLPTWAP1Oracle");
const CompositeOracle = artifacts.require("CompositeOracle");

const collateralAmount = e18(400); // sushi
const token1Amount = e18(1);   // eth
const assetAmount = e18(500); // dai
const rounding = e9(10000000);

contract('CompositeOracle', (accounts) => {
  let collateral;
  let tokenB;
  let asset;
  let pairA;
  let pairB;
  let oracleA;
  let oracleB;
  let compositeOracle;
  let oracleData;

  beforeEach(async () => {

    // a is collateral to pairA
    collateral = await ReturnFalseERC20.new("Token A", "A", e18(10000000), { from: accounts[0] });
    tokenB = await ReturnFalseERC20.new("Token B", "B", e18(10000000), { from: accounts[0] });
    asset = await ReturnFalseERC20.new("Token C", "C", e18(10000000), { from: accounts[0] });

    const factory = await SushiSwapFactory.new(accounts[0], { from: accounts[0] });

    // set up first uni pair
    let tx = await factory.createPair(collateral.address, tokenB.address);
    pairA = await UniswapV2Pair.at(tx.logs[0].args.pair);

    await collateral.transfer(pairA.address, collateralAmount);
    await tokenB.transfer(pairA.address, token1Amount);
    await pairA.mint(accounts[0]);
    if (tokenB.address == (await pairA.token0())) {
           oracleA = await SimpleSLPOracle0.new();
       } else {
           oracleA = await SimpleSLPOracle1.new();
    }
    const oracleDataA = await oracleA.getDataParameter(pairA.address, 0, false);

    // set up second uni pair
    tx = await factory.createPair(tokenB.address, asset.address);
    pairB = await UniswapV2Pair.at(tx.logs[0].args.pair);

    await tokenB.transfer(pairB.address, token1Amount);
    await asset.transfer(pairB.address, assetAmount);
    await pairB.mint(accounts[0]);

    if (asset.address == (await pairA.token0())) {
           oracleB = await SimpleSLPOracle0.new();
       } else {
           oracleB = await SimpleSLPOracle1.new();
    }

    const oracleDataB = await oracleB.getDataParameter(pairB.address, 0, false);

    // set up composite oracle
    compositeOracle = await CompositeOracle.new();
    oracleData = await compositeOracle.getDataParameter(oracleA.address, oracleB.address, oracleDataA, oracleDataB);
  });

  it('update', async () => {
    // update both pairs
    await compositeOracle.get(oracleData);
    await timeWarp.advanceTime(61);
    await compositeOracle.get(oracleData);

    // check the composite oracle
    const expectedPrice = encodePrice(collateralAmount, assetAmount);
    const price = (await compositeOracle.peek(oracleData))[1];
    console.log(price.toString());
    assert.equal(price.divRound(rounding).toString(), collateralAmount.mul(new web3.utils.BN("100")).div(assetAmount).toString());
  });

  it('should update prices after swap', async () => {
    // update exchange rate
    await compositeOracle.get(oracleData);
    await timeWarp.advanceTime(61);
    await compositeOracle.get(oracleData);

    // check the composite oracle
    const price0 = (await compositeOracle.peek(oracleData))[1];

    // check expectations
    const oldPrice = collateralAmount.mul(new web3.utils.BN("100")).div(assetAmount);
    assert.equal(price0.divRound(rounding).toString(), oldPrice.toString());

    // update the exchange rate
    // double the sushi price
    await collateral.transfer(pairA.address, e18(400));
    await pairA.sync();
    await timeWarp.advanceTime(61);
    // read exchange rate again
    await compositeOracle.get(oracleData);
    let price1 = (await compositeOracle.peek(oracleData))[1];

    // check expectations
    const newPrice = oldPrice.add((collateralAmount.mul(new web3.utils.BN("100")).mul(new web3.utils.BN("2"))).div(assetAmount)).divRound(new web3.utils.BN("2"));
    assert.equal(price1.divRound(rounding).toString(), newPrice.toString(), "prices should be exactly half way between price points");
  });
});
