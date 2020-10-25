const truffleAssert = require('./helpers/truffle-assertions');
const timeWarp = require("./helpers/timeWarp");

const Vault = artifacts.require("Vault");
const TokenA = artifacts.require("TokenA");
const TokenB = artifacts.require("TokenB");
const SushiSwapFactory = artifacts.require("UniswapV2Factory");
const UniswapV2Pair = artifacts.require("UniswapV2Pair");
const Pair = artifacts.require("Pair");
const TestOracle = artifacts.require("TestOracle");
const SushiSwapDelegateSwapper = artifacts.require("SushiSwapDelegateSwapper");

function e18(amount) {
  return new web3.utils.BN(amount).mul(new web3.utils.BN("1000000000000000000"));
}

contract('Pair', (accounts) => {
  let a;
  let b;
  let pair_address;
  let pair;
  let vault;
  let swapper;
  const alice = accounts[1];
  const bob = accounts[2];
  const dummy = accounts[4];

  before(async () => {
    vault = await Vault.deployed();
    pairMaster = await Pair.deployed();

    a = await TokenA.new({ from: accounts[0] });
    b = await TokenB.new({ from: accounts[0] });

    let factory = await SushiSwapFactory.new(accounts[0], { from: accounts[0] });
    swapper = await SushiSwapDelegateSwapper.new(factory.address, { from: accounts[0] });
    await vault.setSwapper(swapper.address, true);

    let tx = await factory.createPair(a.address, b.address);
    let sushiswappair = await UniswapV2Pair.at(tx.logs[0].args.pair);
    await a.transfer(sushiswappair.address, e18("5000"));
    await b.transfer(sushiswappair.address, e18("5000"));
    await sushiswappair.mint(accounts[0]);

    await a.transfer(alice, e18(1000));
    await b.transfer(bob, e18(1000));

    oracle = await TestOracle.new({ from: accounts[0] });
    let oracleData = await oracle.getInitData("1000000000000000000");

    tx = await vault.deploy(pairMaster.address, a.address, b.address, oracle.address, oracleData);
    let pair_address = tx.logs[0].args[4];
    pair = await Pair.at(pair_address);

    await pair.updateExchangeRate();
  });

  it('should not allow any remove without assets', async () => {
    await truffleAssert.reverts(pair.removeCollateral(e18(1), bob), 'BoringMath: Underflow');
    await truffleAssert.reverts(pair.removeAsset(e18(1), bob), 'BoringMath: Underflow');
  });

  it('should not allow borrowing without any assets', async () => {
    await truffleAssert.reverts(pair.borrow(e18(1), bob), 'BentoBox: not enough liquidity');
  });

  it('should take a deposit of assets', async () => {
    await b.approve(vault.address, e18(300), { from: bob });
    await pair.addAsset(e18(300), { from: bob });
  });

  it('should have correct balances after supply of assets', async () => {
    assert.equal((await pair.totalSupply()).toString(), e18(300).toString());
    assert.equal((await pair.balanceOf(bob)).toString(), e18(300).toString());
  })

  it('should not allow borrowing without any collateral', async () => {
    await truffleAssert.reverts(pair.borrow(e18(1), alice, { from: alice }), 'BentoBox: user insolvent');
  });

  it('should take a deposit of collateral', async () => {
    await a.approve(vault.address, e18(100), { from: alice });
    await pair.addCollateral(e18(100), { from: alice });
  });

  it('should have correct balances after supply of collateral', async () => {
    assert.equal((await pair.totalCollateralShare()).toString(), e18(100).toString());
    assert.equal((await pair.userCollateralShare(alice)).toString(), e18(100).toString());
  })

  it('should allow borrowing with collateral up to 75%', async () => {
    await pair.borrow(e18(75), alice, { from: alice });
  });

  it('should not allow any more borrowing', async () => {
    await truffleAssert.reverts(pair.borrow(100, alice, { from: alice }), 'BentoBox: user insolvent');
  });

  it('should report insolvency due to interest', async () => {
    await pair.accrue();
    assert.equal(await pair.isSolvent(alice, false), false);
  })

  it('should not report open insolvency due to interest', async () => {
    await pair.accrue();
    assert.equal(await pair.isSolvent(alice, true), true);
  })

  it('should not allow open liquidate yet', async () => {
    await b.approve(vault.address, e18(25), { from: bob });
    await truffleAssert.reverts(pair.liquidate([alice], [e18(20)], bob, "0x0000000000000000000000000000000000000000", true, { from: bob }), 'BentoBox: all users are solvent');
  });

  it('should allow closed liquidate', async () => {
    let tx = await pair.liquidate([alice], [e18(10)], bob, swapper.address, false, { from: bob });
  });

  it('should report open insolvency after oracle rate is updated', async () => {
    await oracle.set("1100000000000000000", pair.address);
    await pair.updateExchangeRate();
    assert.equal(await pair.isSolvent(alice, true), false);
  })

  it('should allow open liquidate', async () => {
    await b.approve(vault.address, e18(25), { from: bob });
    await pair.liquidate([alice], [e18(10)], bob, "0x0000000000000000000000000000000000000000", true, { from: bob });
  });

  it('should allow repay', async () => {
    await b.approve(vault.address, e18(100), { from: alice });
    await pair.repay(e18(50), { from: alice });
  });

  it('should allow full repay with funds', async () => {
    let borrowShareLeft = await pair.userBorrowShare(alice);
    await pair.repay(borrowShareLeft, { from: alice });
  });

  it('should allow partial withdrawal of collateral', async () => {
    await pair.removeCollateral(e18(60), alice, { from: alice });
  });

  it('should not allow withdrawal of more than collateral', async () => {
    await truffleAssert.reverts(pair.removeCollateral(e18(100), alice, { from: alice }), "BoringMath: Underflow");
  });

  it('should allow full withdrawal of collateral', async () => {
    let shareALeft = await pair.userCollateralShare(alice);
    await pair.removeCollateral(shareALeft, alice, { from: alice });
  });

  it('should update the interest rate', async () => {
    for (let i = 0; i < 20; i++) {
      await timeWarp.advanceBlock()
    }
    await pair.updateInterestRate({ from: alice });
  });
});
