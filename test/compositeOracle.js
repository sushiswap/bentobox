const fs = require('fs');
const timeWarp = require("./helpers/timeWarp");
const truffleAssert = require('./helpers/truffle-assertions');
const {e18, encodePrice, getInitData, getDataParameter} = require("./helpers/utils");
const AssertionError = require('./helpers/assertion-error');
const TokenA = artifacts.require("TokenA");
const TokenB = artifacts.require("TokenB");
const BentoBox = artifacts.require("BentoBox");
const Pair = artifacts.require("LendingPair");
const SushiSwapFactory = artifacts.require("UniswapV2Factory");
const UniswapV2Pair = artifacts.require("UniswapV2Pair");
const SimpleSLPOracle = artifacts.require("SimpleSLPOracle");
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
  let compositeOracle;

  beforeEach(async () => {
    bentoBox = await BentoBox.deployed();
    pairMaster = await Pair.deployed();

    a = await TokenA.new({ from: accounts[0] });
    b = await TokenB.new({ from: accounts[0] });
    c = await TokenB.new({ from: accounts[0] });

    const factory = await SushiSwapFactory.new(accounts[0], { from: accounts[0] });

    // set up first bento pair
    let tx = await factory.createPair(a.address, b.address);
    pairA = await UniswapV2Pair.at(tx.logs[0].args.pair);

    await a.transfer(pairA.address, token0Amount);
    await b.transfer(pairA.address, token1Amount);
    await pairA.mint(accounts[0]);
    oracleA = await SimpleSLPOracle.new();
    const oracleDataA = getDataParameter(SimpleSLPOracle._json.abi, []);

    // set up second bento pair
    tx = await factory.createPair(b.address, c.address);
    pairB = await UniswapV2Pair.at(tx.logs[0].args.pair);

    await b.transfer(pairB.address, token1Amount);
    await c.transfer(pairB.address, token2Amount);
    await pairB.mint(accounts[0]);
    oracleB = await SimpleSLPOracle.new();
    const oracleDataB = getDataParameter(SimpleSLPOracle._json.abi, []);

    // set up composite oracle
    compositeOracle = await CompositeOracle.new();
    oracleData = getDataParameter(CompositeOracle._json.abi, []);
    initData = getInitData(Pair._json.abi, [a.address, c.address, compositeOracle.address, oracleData])
    tx = await bentoBox.deploy(pairMaster.address, initData);
    bentoPairC = await Pair.at(tx.logs[0].args[2]);
  });

  // it('update', async () => {
  //   // update both pairs
  //   await timeWarp.advanceTime(61);
  //   await oracleA.update(compositeOracle.address);
  //   await oracleB.update(compositeOracle.address);

  //   // check the composite oracle
  //   const expectedPrice = encodePrice(token0Amount, token2Amount);
  //   const price = await compositeOracle.peek(bentoPairC.address);
  //   const rounding = new web3.utils.BN("10000000000000000"); // 10^16
  //   assert.equal(price.divRound(rounding).toString(), token2Amount.mul(new web3.utils.BN("100")).div(token0Amount).toString());
  // });
});
