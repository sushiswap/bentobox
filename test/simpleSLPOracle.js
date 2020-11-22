const fs = require('fs');
const timeWarp = require("./helpers/timeWarp");
const truffleAssert = require('./helpers/truffle-assertions');
const {e18, encodePrice} = require("./helpers/utils");
const { oracle } = require("../build/contracts/SimpleSLPOracle.json");
const lendingPair = JSON.parse(fs.readFileSync("./build/contracts/LendingPair.json", "utf8"));
const {getInitData} = require("./helpers/getInitData");
const AssertionError = require('./helpers/assertion-error');

const TokenA = artifacts.require("TokenA");
const TokenB = artifacts.require("TokenB");
const BentoBox = artifacts.require("BentoBox");
const Pair = artifacts.require("LendingPair");
const SushiSwapFactory = artifacts.require("UniswapV2Factory");
const UniswapV2Pair = artifacts.require("UniswapV2Pair");
const SimpleSLPOracle = artifacts.require("SimpleSLPOracle");

const token0Amount = e18(5);
const token1Amount = e18(10);

contract('SimpleSLPOracle', (accounts) => {
  let bentoBox;
  let pairMaster;
  let a;
  let b;
  let pair;
  let oracle;
  let oracleData;
  let bentoPair;

  async function addLiquidity() {
    await a.transfer(pair.address, token0Amount);
    await b.transfer(pair.address, token1Amount);
    await pair.mint(accounts[0]);
  }

  beforeEach(async () => {
    bentoBox = await BentoBox.deployed();
    pairMaster = await Pair.deployed();

    a = await TokenA.new({ from: accounts[0] });
    b = await TokenB.new({ from: accounts[0] });

    const factory = await SushiSwapFactory.new(accounts[0], { from: accounts[0] });

    let tx = await factory.createPair(a.address, b.address);
    pair = await UniswapV2Pair.at(tx.logs[0].args.pair);

    await addLiquidity();
    oracle = await SimpleSLPOracle.new();
    oracleData = getInitData(oracle.abi, [pair.address, a.address]);
    let initData = getInitData(lendingPair.abi, [a.address, b.address, oracle.address, oracleData])
    tx = await bentoBox.deploy(pairMaster.address, initData);
    bentoPair = await Pair.at(tx.logs[0].args[2]);
  });

  it('update', async () => {
    const blockTimestamp = (await pair.getReserves())[2];
    await timeWarp.advanceTime(30);
    await truffleAssert.reverts(oracle.update(bentoPair.address), "SimpleSLPOracle: PERIOD_NOT_ELAPSED");
    await timeWarp.advanceTime(31);
    await oracle.update(bentoPair.address);

    const expectedPrice = encodePrice(token0Amount, token1Amount);
    const pairInfo = await oracle.pairs(bentoPair.address);
    assert.equal(pairInfo.priceAverage.toString(), expectedPrice[0].toString());
    assert.equal((await oracle.peek(bentoPair.address)).toString(), token1Amount.mul(new web3.utils.BN(2)).div(new web3.utils.BN(10)).toString());
  });
});
