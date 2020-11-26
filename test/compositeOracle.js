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

const sushiAmount = e18(400); // sushi
const ethAmount = e18(1);   // eth
const daiAmount = e18(500); // dai
const rounding = e9(10000000);

contract('CompositeOracle', (accounts) => {
  let sushiToken;
  let ethToken;
  let daiToken;
  let pairSushiEth;
  let pairDaiEth;
  let oracleSushiEth;
  let oracleDaiEth;
  let compositeOracle;
  let compositeOracleData;

  beforeEach(async () => {

    sushiToken = await ReturnFalseERC20.new("Sushi", "SHI", e18(10000000), { from: accounts[0] });
    ethToken = await ReturnFalseERC20.new("WETH", "ETH", e18(10000000), { from: accounts[0] });
    daiToken = await ReturnFalseERC20.new("DAI", "DAI", e18(10000000), { from: accounts[0] });

    const factory = await SushiSwapFactory.new(accounts[0], { from: accounts[0] });

    // set up Sushi / Eth uni pair
    let tx = await factory.createPair(sushiToken.address, ethToken.address);
    pairSushiEth = await UniswapV2Pair.at(tx.logs[0].args.pair);

    await sushiToken.transfer(pairSushiEth.address, sushiAmount);
    await ethToken.transfer(pairSushiEth.address, ethAmount);
    await pairSushiEth.mint(accounts[0]);

    // set up Sushi / Eth oracle 
    // ETH is the asset
    // Sushi is the collateral
    if (ethToken.address == (await pairSushiEth.token0())) {
           oracleSushiEth = await SimpleSLPOracle0.new();
       } else {
           oracleSushiEth = await SimpleSLPOracle1.new();
    }
    const oracleDataA = await oracleSushiEth.getDataParameter(pairSushiEth.address, 0, false);

    // set up Dai / Eth uni pair
    tx = await factory.createPair(ethToken.address, daiToken.address);
    pairDaiEth = await UniswapV2Pair.at(tx.logs[0].args.pair);

    await ethToken.transfer(pairDaiEth.address, ethAmount);
    await daiToken.transfer(pairDaiEth.address, daiAmount);
    await pairDaiEth.mint(accounts[0]);

    // set up Dai / Eth oracle
    // DAI is the asset
    // ETH is the collateral
    if (daiToken.address == (await pairDaiEth.token0())) {
           oracleDaiEth = await SimpleSLPOracle0.new();
       } else {
           oracleDaiEth = await SimpleSLPOracle1.new();
    }
    const oracleDataB = await oracleDaiEth.getDataParameter(pairDaiEth.address, 0, false);

    // set up composite oracle
    // Sushi is the collateral
    // DAI is the asset
    compositeOracle = await CompositeOracle.new();
    compositeOracleData = await compositeOracle.getDataParameter(oracleSushiEth.address, oracleDaiEth.address, oracleDataA, oracleDataB);
  });

  it('update', async () => {
    // update both pairs
    await compositeOracle.get(compositeOracleData);
    await timeWarp.advanceTime(61);
    await compositeOracle.get(compositeOracleData);

    // check the composite oracle
    const expectedPrice = encodePrice(sushiAmount, daiAmount);
    const price = (await compositeOracle.peek(compositeOracleData))[1];
    // oracle returns "the amount of callateral unit to buy 10^18 of asset units"
    // expectation: 0.8 of Sushi to buy 1 DAI
    assert.equal(price.divRound(rounding).toString(), '80');
  });

  it('should update prices after swap', async () => {
    // update exchange rate
    await compositeOracle.get(compositeOracleData);
    await timeWarp.advanceTime(61);
    await compositeOracle.get(compositeOracleData);

    // check the composite oracle
    const price0 = (await compositeOracle.peek(compositeOracleData))[1];

    // check expectations
    const oldPrice = sushiAmount.mul(new web3.utils.BN("100")).div(daiAmount);
    assert.equal(price0.divRound(rounding).toString(), oldPrice.toString());

    // half the sushi price
    await timeWarp.advanceTime(30);
    await sushiToken.transfer(pairSushiEth.address, e18(400));
    await pairSushiEth.sync();
    await timeWarp.advanceTime(30);
    // read exchange rate again half way
    await compositeOracle.get(compositeOracleData);
    let price1 = (await compositeOracle.peek(compositeOracleData))[1];

    // check expectations
    // oracle returns "the amount of callateral unit to buy 10^18 of asset units"
    // expectation: 1.2 of Sushi to buy 1 DAI
    assert.equal(price1.divRound(e9(100000000)).toString(), '12', "prices should be exactly half way between price points");

    // read exchange rate with final exchange rate
    await timeWarp.advanceTime(61);
    await compositeOracle.get(compositeOracleData);
    let price2 = (await compositeOracle.peek(compositeOracleData))[1];
    // oracle returns "the amount of callateral unit to buy 10^18 of asset units"
    // expectation: 1.6 of Sushi to buy 1 DAI
    assert.equal(price2.divRound(rounding).toString(), "160");
  });
});
