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

const token0Amount = e18(400); // sushi
const token1Amount = e18(1);   // eth
const token2Amount = e18(500); // dai

contract('CompositeOracle', (accounts) => {
  let bentoBox;
  let pairMaster;
  let a;
  let b;
  let c;
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

    a = await MockERC20.new("Token A", "A", e18(10000000), { from: accounts[0] });
    b = await MockERC20.new("Token B", "B", e18(10000000), { from: accounts[0] });
    c = await MockERC20.new("Token C", "C", e18(10000000), { from: accounts[0] });

    const factory = await SushiSwapFactory.new(accounts[0], { from: accounts[0] });

    // set up first bento pair
    let tx = await factory.createPair(a.address, b.address);
    pairA = await UniswapV2Pair.at(tx.logs[0].args.pair);

    await a.transfer(pairA.address, token0Amount);
    await b.transfer(pairA.address, token1Amount);
    await pairA.mint(accounts[0]);
    if (a.address == (await pairA.token0())) {
           oracleA = await SimpleSLPOracle0.new();
       } else {
           oracleA = await SimpleSLPOracle1.new();
    }
    oracleDataA = await oracleA.getDataParameter(pairA.address);

    // set up second bento pair
    tx = await factory.createPair(b.address, c.address);
    pairB = await UniswapV2Pair.at(tx.logs[0].args.pair);

    await b.transfer(pairB.address, token1Amount);
    await c.transfer(pairB.address, token2Amount);
    await pairB.mint(accounts[0]);

    if (b.address == (await pairA.token0())) {
           oracleB = await SimpleSLPOracle0.new();
       } else {
           oracleB = await SimpleSLPOracle1.new();
    }

    oracleDataB = await oracleB.getDataParameter(pairB.address);

    // set up composite oracle
    compositeOracle = await CompositeOracle.new();
    oracleData = await compositeOracle.getDataParameter(oracleA.address, oracleB.address, oracleDataA, oracleDataB);
    initData = getInitData(Pair._json.abi, [a.address, c.address, compositeOracle.address, oracleData])
    tx = await bentoBox.deploy(pairMaster.address, initData);
    bentoPairC = await Pair.at(tx.logs[0].args[2]);
  });

  it('update', async () => {
    // update both pairs
    await compositeOracle.get(oracleData);
    await timeWarp.advanceTime(61);
    await compositeOracle.get(oracleData);

    // check the composite oracle
    const expectedPrice = encodePrice(token0Amount, token2Amount);
    const price = (await compositeOracle.peek(oracleData))[1];
    const rounding = new web3.utils.BN("10000000000000000"); // 10^16
    assert.equal(price.divRound(rounding).toString(), token2Amount.mul(new web3.utils.BN("100")).div(token0Amount).toString());
  });

  it('should update prices after swap', async () => {
    await compositeOracle.get(oracleData);
    await timeWarp.advanceTime(61);
    await compositeOracle.get(oracleData);
    let price0 = (await compositeOracle.peek(oracleData))[1];
    await a.transfer(pairA.address, e18(400));
    await timeWarp.advanceTime(30);
    await pairA.sync();
    await timeWarp.advanceTime(30);
    await compositeOracle.get(oracleData);
    let price1 = (await compositeOracle.peek(oracleData))[1];

    const rounding = new web3.utils.BN("10000000000000000"); // 10^16
    const oldPrice = token2Amount.mul(new web3.utils.BN("100")).div(token0Amount);
    const newPrice = oldPrice.add((token2Amount.mul(new web3.utils.BN("100"))).div(token0Amount.mul(new web3.utils.BN("2")))).divRound(new web3.utils.BN("2"));
    assert.equal(price0.divRound(rounding).toString(), oldPrice.toString());
    assert.equal(price1.divRound(rounding).toString(), newPrice.toString(), "prices should be exactly half way between price points");
  });
});
