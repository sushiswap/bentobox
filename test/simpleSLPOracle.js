const timeWarp = require("./helpers/timeWarp");
const truffleAssert = require('./helpers/truffle-assertions');
const {e18, encodePrice} = require("./helpers/utils");
const AssertionError = require('./helpers/assertion-error');

const TokenA = artifacts.require("TokenA");
const TokenB = artifacts.require("TokenB");
const Vault = artifacts.require("Vault");
const Pair = artifacts.require("Pair");
const SushiSwapFactory = artifacts.require("UniswapV2Factory");
const UniswapV2Pair = artifacts.require("UniswapV2Pair");
const SimpleSLPOracle = artifacts.require("SimpleSLPOracle");

const token0Amount = e18(5);
const token1Amount = e18(10);

contract('SimpleSLPOracle', (accounts) => {
  let vault;
  let pairMaster;
  let a;
  let b;
  let pair;
  let oracle;
  let bentoPair;

  async function addLiquidity() {
    await a.transfer(pair.address, token0Amount);
    await b.transfer(pair.address, token1Amount);
    await pair.mint(accounts[0]);
  }

  beforeEach(async () => {
    vault = await Vault.deployed();
    pairMaster = await Pair.deployed();

    a = await TokenA.new({ from: accounts[0] });
    b = await TokenB.new({ from: accounts[0] });

    const factory = await SushiSwapFactory.new(accounts[0], { from: accounts[0] });

    let tx = await factory.createPair(a.address, b.address);
    pair = await UniswapV2Pair.at(tx.logs[0].args.pair);

    await addLiquidity();
    oracle = await SimpleSLPOracle.new(factory.address, a.address, b.address);
    let oracleData = await oracle.getInitData();

    let initData = await pairMaster.getInitData(a.address, b.address, oracle.address, oracleData);
    tx = await vault.deploy(pairMaster.address, initData);
    bentoPair = await Pair.at(tx.logs[0].args[2]);
  });

  it('update', async () => {
    const blockTimestamp = (await pair.getReserves())[2];
    await timeWarp.advanceTime(30);
    await truffleAssert.reverts(oracle.update(), "SimpleSLPOracle: PERIOD_NOT_ELAPSED");
    await timeWarp.advanceTime(31);
    await oracle.update();
    await timeWarp.advanceTime(61);
    await oracle.update();

    const expectedPrice = encodePrice(token0Amount, token1Amount);

    // token address flickering
    assert.equal((await oracle.price0Average()).toString(), expectedPrice[0].toString());
    assert.equal((await oracle.price1Average()).toString(), expectedPrice[1].toString());

    // different prices
    assert.equal((await oracle.peek(bentoPair.address)).toString(), token0Amount.div(10).toString()); // or token0Amount); ?
  });
});