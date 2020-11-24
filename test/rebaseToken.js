const truffleAssert = require('./helpers/truffle-assertions');
const AssertionError = require('./helpers/assertion-error');
const BentoBox = artifacts.require("BentoBox");
const Pair = artifacts.require("LendingPair");
const RebaseToken = artifacts.require("RebaseToken");
const {e9} = require('./helpers/utils');

contract('Rebase Token', (accounts) => {
  let bentoBox;
  let rebaseToken;
  const alice = accounts[1];
  const bob = accounts[2];
  const maki = accounts[3];

  beforeEach(async () => {
    bentoBox = await BentoBox.deployed();
    rebaseToken = await RebaseToken.new("Rebase Token", "RBT", { from: accounts[0] });
    await rebaseToken.transfer(alice, e9(1000));
    await rebaseToken.transfer(bob, e9(1000));
    let total = await rebaseToken.totalSupply();
    // double the supply
    await rebaseToken.rebase(total);
  });

  it('should give back correct token amount after rebase', async () => {
    // deposit
    await rebaseToken.approve(bentoBox.address, e9(1), { from: alice });
    await bentoBox.deposit(rebaseToken.address, alice, e9(1), { from: alice });
    let share = await bentoBox.shareOf(rebaseToken.address, alice);
    assert.equal(share.toString(), e9(1).toString());
    let amount = await bentoBox.toAmount(rebaseToken.address, e9(1));
    assert.equal(amount.toString(), e9(1).toString());
    // rebase
    let total = await rebaseToken.totalSupply();
    await rebaseToken.rebase(`-${total / 2}`);
    // sync and check
    await bentoBox.sync(rebaseToken.address);
    share = await bentoBox.shareOf(rebaseToken.address, alice);
    assert.equal(share.toString(), e9(1).toString());
    amount = await bentoBox.toAmount(rebaseToken.address, e9(1));
    assert.equal(amount.toString(), '499999999');
  });

  it('should calculate correct share for second deposit', async () => {
    // first deposit
    await rebaseToken.approve(bentoBox.address, e9(100), { from: alice });
    await bentoBox.deposit(rebaseToken.address, alice, e9(2), { from: alice });
    // rebase
    let total = await rebaseToken.totalSupply();
    await rebaseToken.rebase(`-${total / 2}`);
    // sync 
    await bentoBox.sync(rebaseToken.address);
    // second deposit
    await bentoBox.deposit(rebaseToken.address, alice, e9(2), { from: alice });
    let share = await bentoBox.shareOf(rebaseToken.address, alice);
    assert.equal(share.toString(), '6000000004', "incorrect share calculation");
    let totalShare = await bentoBox.totalShare(rebaseToken.address);
    assert.equal(totalShare.toString(), '6000000004', "incorrect total share");
  });

  it('should allow to withdraw', async () => {
    await rebaseToken.approve(bentoBox.address, e9(2), { from: alice });
    await bentoBox.deposit(rebaseToken.address, alice, e9(2), { from: alice });
    // rebase
    let total = await rebaseToken.totalSupply();
    await rebaseToken.rebase(`-${total / 2}`);
    // sync 
    await bentoBox.sync(rebaseToken.address);
    // withdraw
    await bentoBox.methods['withdraw(address,address,uint256)'](rebaseToken.address, alice, '999999999', { from: alice });
    assert.equal((await rebaseToken.balanceOf(alice)).toString(), '999999999999', "alice should have all of their tokens back");
    let share = await bentoBox.shareOf(rebaseToken.address, alice);
    assert.equal(share.toString(), e9(0).toString(), "token should be withdrawn");
  });

  it('should allow to withdrawShare', async () => {
    await rebaseToken.approve(bentoBox.address, e9(1), { from: alice });
    await bentoBox.deposit(rebaseToken.address, alice, e9(1), { from: alice });
    // rebase
    let total = await rebaseToken.totalSupply();
    await rebaseToken.rebase(total);
    // sync 
    await bentoBox.sync(rebaseToken.address);
    // withdraw
    await bentoBox.methods['withdrawShare(address,address,uint256)'](rebaseToken.address, alice, e9(1), { from: alice });
    assert.equal((await rebaseToken.balanceOf(alice)).toString(), e9(4000).toString(), "alice should have all of their tokens back");
    let share = await bentoBox.shareOf(rebaseToken.address, alice);
    assert.equal(share.toString(), e9(0).toString(), "token should be withdrawn");
  });

});
