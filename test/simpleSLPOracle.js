const timeWarp = require("./helpers/timeWarp");
const truffleAssert = require('./helpers/truffle-assertions');
const {e18, encodePrice, getInitData, getDataParameter} = require("./helpers/utils");
const AssertionError = require('./helpers/assertion-error');

const ReturnFalseERC20 = artifacts.require("ReturnFalseERC20");
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
  let collateral;
  let asset;
  let pair;
  let oracle;
  let oracleData;
  let bentoPair;

  async function addLiquidity() {
    await collateral.transfer(pair.address, token0Amount);
    await asset.transfer(pair.address, token1Amount);
    await pair.mint(accounts[0]);
  }

  beforeEach(async () => {
    bentoBox = await BentoBox.deployed();
    pairMaster = await Pair.deployed();

    collateral = await ReturnFalseERC20.new("Token A", "A", e18(10000000), { from: accounts[0] });
    asset = await ReturnFalseERC20.new("Token B", "B", e18(10000000), { from: accounts[0] });

    const factory = await SushiSwapFactory.new(accounts[0], { from: accounts[0] });

    let tx = await factory.createPair(collateral.address, asset.address);
    pair = await UniswapV2Pair.at(tx.logs[0].args.pair);

    await addLiquidity();
    if (asset.address == (await pair.token0())) {
           oracle = await SimpleSLPOracle0.new();
       } else {
           oracle = await SimpleSLPOracle1.new();
    }
    oracleData = await oracle.getDataParameter(pair.address);
    let initData = await pairMaster.getInitData(collateral.address, asset.address, oracle.address, oracleData);

    tx = await bentoBox.deploy(pairMaster.address, initData);
    bentoPair = await Pair.at(tx.logs[0].args[2]);
  });

  it('should return false on first peek', async () => {
    const result = await oracle.peek(oracleData);
    assert.equal((result)[1].toString(),"0", "without initialization the oracle should have a zero price");
  });

  it('should update and get prices within period', async () => {
    const blockTimestamp = (await pair.getReserves())[2];

    await oracle.get(oracleData);
    await timeWarp.advanceBlocks(5);
    await timeWarp.advanceTime(30);
    await oracle.get(oracleData);
    await timeWarp.advanceBlocks(16);
    await timeWarp.advanceTime(271);
    await oracle.get(oracleData);
    // for coverage
    await oracle.get(oracleData);

    const expectedPrice = e18(1).mul(new web3.utils.BN(5)).div(new web3.utils.BN(10));
    assert.equal((await oracle.peek(oracleData))[1].toString(), expectedPrice.toString(), "amount of collateral to buy 1e18 of assets");
  });

  it('should get prices if Period time is over', async () => {
    const blockTimestamp = (await pair.getReserves())[2];

    await oracle.get(oracleData);
    await timeWarp.advanceTime(30);
    await timeWarp.advanceBlocks(5);
    await oracle.get(oracleData);
    await timeWarp.advanceTime(271);
    await timeWarp.advanceBlocks(15);
    await oracle.get(oracleData);
    await timeWarp.advanceBlocks(25);
    await timeWarp.advanceTime(421);

    const expectedPrice = e18(1).mul(new web3.utils.BN(5)).div(new web3.utils.BN(10));
    assert.equal((await oracle.peek(oracleData))[1].toString(), expectedPrice.toString(), "amount of collateral to buy 1e18 of assets");
  });


  it('should update prices after swap', async () => {
    const blockTimestamp = (await pair.getReserves())[2];
    await oracle.get(oracleData);
    await timeWarp.advanceTime(301);
    await timeWarp.advanceBlocks(20);
    await oracle.get(oracleData);
    let price0 = (await oracle.peek(oracleData))[1];
    await collateral.transfer(pair.address, e18(5));
    await timeWarp.advanceTime(150);
    await timeWarp.advanceBlocks(10);
    await pair.sync();
    await timeWarp.advanceTime(150);
    await timeWarp.advanceBlocks(10);
    await oracle.get(oracleData);
    let price1 = (await oracle.peek(oracleData))[1];

    const rounding = new web3.utils.BN("10000000000000000"); // 10^16

    assert.equal(price0.toString(), e18(1).mul(new web3.utils.BN(5)).div(new web3.utils.BN(10)).toString(), "amount of collateral to buy 1e18 of assets");
    assert.equal(price1.divRound(rounding).toString(), e18(1).mul(new web3.utils.BN(75)).div(new web3.utils.BN(100)).divRound(rounding).toString(), "prices should be exactly half way between price points");
  });
});
