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

    a = await MockERC20.new("Token A", "A", e18(10000000), { from: accounts[0] });
    b = await MockERC20.new("Token B", "B", e18(10000000), { from: accounts[0] });

    const factory = await SushiSwapFactory.new(accounts[0], { from: accounts[0] });

    let tx = await factory.createPair(a.address, b.address);
    pair = await UniswapV2Pair.at(tx.logs[0].args.pair);

    await addLiquidity();
    if (a.address == (await pair.token0())) {
           oracle = await SimpleSLPOracle0.new();
       } else {
           oracle = await SimpleSLPOracle1.new();
    }
    oracleData = await oracle.getDataParameter(pair.address);
    let initData = getInitData(Pair._json.abi, [a.address, b.address, oracle.address, oracleData])

    tx = await bentoBox.deploy(pairMaster.address, initData);
    bentoPair = await Pair.at(tx.logs[0].args[2]);
  });

  it('update', async () => {
    const blockTimestamp = (await pair.getReserves())[2];

    await oracle.get(oracleData);
    await timeWarp.advanceTime(30);
    await oracle.get(oracleData);
    await timeWarp.advanceTime(31);
    //await oracle.get(oracleData);
    await oracle.get(oracleData);

    const expectedPrice = encodePrice(token0Amount, token1Amount);
    assert.equal((await oracle.pairs(pair.address)).priceAverage.toString(), expectedPrice[0].toString());
    assert.equal((await oracle.peek(oracleData))[1].toString(), token1Amount.mul(new web3.utils.BN(2)).div(new web3.utils.BN(10)).toString(), "token1 should be 0.5x of token0");
  });

  it('should update prices after swap', async () => {
    const blockTimestamp = (await pair.getReserves())[2];
    await oracle.get(oracleData);
    await timeWarp.advanceTime(61);
    await oracle.get(oracleData);
    let price0 = (await oracle.peek(oracleData))[1];
    await a.transfer(pair.address, e18(5));
    await timeWarp.advanceTime(30);
    await pair.sync();
    await timeWarp.advanceTime(30);
    await oracle.get(oracleData);
    let price1 = (await oracle.peek(oracleData))[1];

    const rounding = new web3.utils.BN("100000000000000000"); // 10^16

    assert.equal(price0.toString(), token1Amount.mul(new web3.utils.BN(2)).div(new web3.utils.BN(10)).toString(), "token1 should be 0.5x of token0");
    assert.equal(price1.divRound(rounding).toString(), token1Amount.mul(new web3.utils.BN(15)).div(new web3.utils.BN(100)).divRound(rounding).toString(), "prices should be exactly half way between price points");
  });
});
