const fs = require('fs');
const truffleAssert = require('./helpers/truffle-assertions');
const AssertionError = require('./helpers/assertion-error');
const BentoBox = artifacts.require("BentoBox");
const Pair = artifacts.require("LendingPair");
const FlashLoaner = artifacts.require("FlashLoaner");
const TokenA = artifacts.require("TokenA");
const TokenB = artifacts.require("TokenB");
const bentoJSON = JSON.parse(fs.readFileSync("./build/contracts/BentoBox.json", "utf8"));
const {e18} = require('./helpers/utils');

contract('BentoBox', (accounts) => {
  let bentoBox;
  let a;
  let b;
  const alice = accounts[1];
  const bob = accounts[2];
  const maki = accounts[3];
  let pairMaster;
  beforeEach(async () => {
    bentoBox = await BentoBox.deployed();
    a = await TokenA.new({ from: accounts[0] });
    b = await TokenB.new({ from: accounts[0] });
    await a.transfer(alice, e18(1000));
    await b.transfer(bob, e18(1000));
    pairMaster = await Pair.deployed();
  });

  it('should allow deposit', async () => {
    await a.approve(bentoBox.address, e18(1), { from: alice });
    await bentoBox.deposit(a.address, alice, e18(1), { from: alice });
    let share = await bentoBox.shareOf(a.address, alice);
    assert.equal(share.toString(), e18(1).toString());
  });

  it('should not allow deposit without approve', async () => {
    truffleAssert.reverts(bentoBox.deposit(a.address, alice, e18(1), { from: alice }), "BentoBox: TransferFrom failed at ERC20");
    let share = await bentoBox.shareOf(a.address, alice);
    assert.equal(share.toString(), e18(0).toString());
  });

  it('should allow depositShare', async () => {
    await a.approve(bentoBox.address, e18(1), { from: alice });
    await bentoBox.methods['depositShare(address,address,uint256)'](a.address, alice, e18(1), { from: alice });
    let share = await bentoBox.shareOf(a.address, alice);
    assert.equal(share.toString(), e18(1).toString());
  });

  it('should give back correct token amount', async () => {
    await a.approve(bentoBox.address, e18(1), { from: alice });
    await bentoBox.deposit(a.address, alice, e18(1), { from: alice });
    let amount = await bentoBox.toAmount(a.address, e18(1));
    assert.equal(amount.toString(), e18(1).toString());
  });

  it('should calculate correct share for second deposit', async () => {
    await a.approve(bentoBox.address, e18(3), { from: alice });
    await bentoBox.deposit(a.address, alice, e18(1), { from: alice });
    await bentoBox.deposit(a.address, alice, e18(2), { from: alice });
    let share = await bentoBox.shareOf(a.address, alice);
    assert.equal(share.toString(), e18(3).toString(), "incorrect share calculation");
    let totalShare = await bentoBox.totalShare(a.address);
    assert.equal(totalShare.toString(), e18(3).toString(), "incorrect total share");
  });

  it('should allow to deposit for other user', async () => {
    await a.approve(bentoBox.address, e18(3), { from: alice });
    await bentoBox.methods['depositTo(address,address,address,uint256)'](a.address, alice, bob, e18(1), { from: alice });
    let share = await bentoBox.shareOf(a.address, bob);
    assert.equal(share.toString(), e18(1).toString(), "incorrect share calculation");
    let totalShare = await bentoBox.totalShare(a.address);
    assert.equal(totalShare.toString(), e18(1).toString(), "incorrect total share");
  });

  it('should allow depositShare to other User', async () => {
    await a.approve(bentoBox.address, e18(1), { from: alice });
    await bentoBox.methods['depositShareTo(address,address,address,uint256)'](a.address, alice, bob, e18(1), { from: alice });
    let share = await bentoBox.shareOf(a.address, bob);
    assert.equal(share.toString(), e18(1).toString(), "incorrect share calculation");
  });

  it('should allow to withdraw', async () => {
    await a.approve(bentoBox.address, e18(1), { from: alice });
    await bentoBox.deposit(a.address, alice, e18(1), { from: alice });
    await bentoBox.methods['withdraw(address,address,uint256)'](a.address, alice, e18(1), { from: alice });
    assert.equal((await a.balanceOf(alice)).toString(), e18(1000).toString(), "alice should have all of their tokens back");
    let share = await bentoBox.shareOf(a.address, alice);
    assert.equal(share.toString(), e18(0).toString(), "token should be withdrawn");
  });

  it('should allow to withdrawShare', async () => {
    await a.approve(bentoBox.address, e18(1), { from: alice });
    await bentoBox.deposit(a.address, alice, e18(1), { from: alice });
    await bentoBox.methods['withdrawShare(address,address,uint256)'](a.address, alice, e18(1), { from: alice });
    assert.equal((await a.balanceOf(alice)).toString(), e18(1000).toString(), "alice should have all of their tokens back");
    let share = await bentoBox.shareOf(a.address, alice);
    assert.equal(share.toString(), e18(0).toString(), "token should be withdrawn");
  });

  it('should allow to withdraw to other user', async () => {
    await a.approve(bentoBox.address, e18(1), { from: alice });
    await bentoBox.deposit(a.address, alice, e18(1), { from: alice });
    await bentoBox.methods['withdrawFrom(address,address,address,uint256)'](a.address, alice, bob, e18(1), { from: alice });
    assert.equal((await a.balanceOf(alice)).toString(), e18(999).toString(), "alice should not have received the token back");
    assert.equal((await a.balanceOf(bob)).toString(), e18(1).toString(), "bob should have received their tokens");
    let share = await bentoBox.shareOf(a.address, alice);
    assert.equal(share.toString(), e18(0).toString(), "token should be withdrawn");
  });

  it('should allow to withdrawShare to other user', async () => {
    await a.approve(bentoBox.address, e18(1), { from: alice });
    await bentoBox.deposit(a.address, alice, e18(1), { from: alice });
    await bentoBox.methods['withdrawShareFrom(address,address,address,uint256)'](a.address, alice, bob, e18(1), { from: alice });
    assert.equal((await a.balanceOf(alice)).toString(), e18(999).toString(), "alice should not have received the token back");
    assert.equal((await a.balanceOf(bob)).toString(), e18(1).toString(), "bob should have received their tokens");
    let share = await bentoBox.shareOf(a.address, alice);
    assert.equal(share.toString(), e18(0).toString(), "token should be withdrawn");
  });

  it('should allow transfer to bob by alice', async () => {
    await a.approve(bentoBox.address, e18(1), { from: alice });
    await bentoBox.deposit(a.address, alice, e18(1), { from: alice });
    await bentoBox.transfer(a.address, alice, bob, e18(1), { from: alice });
    let share = await bentoBox.shareOf(a.address, alice);
    assert.equal(share.toString(), e18(0).toString(), "token should be transferred");
    share = await bentoBox.shareOf(a.address, bob);
    assert.equal(share.toString(), e18(1).toString(), "token should be transferred");
  });

  it('should allow transferShare to bob by alice', async () => {
    await a.approve(bentoBox.address, e18(1), { from: alice });
    await bentoBox.deposit(a.address, alice, e18(1), { from: alice });
    await bentoBox.transferShare(a.address, alice, bob, e18(1), { from: alice });
    let share = await bentoBox.shareOf(a.address, alice);
    assert.equal(share.toString(), e18(0).toString(), "token should be transferred");
    share = await bentoBox.shareOf(a.address, bob);
    assert.equal(share.toString(), e18(1).toString(), "token should be transferred");
  });

  it('should allow transfer to bob and maki by alice', async () => {
    await a.approve(bentoBox.address, e18(2), { from: alice });
    await bentoBox.deposit(a.address, alice, e18(2), { from: alice });
    await bentoBox.transferMultiple(a.address, alice, [bob, maki], [e18(1),e18(1)], { from: alice });
    let share = await bentoBox.shareOf(a.address, alice);
    assert.equal(share.toString(), e18(0).toString(), "token should be transferred");
    share = await bentoBox.shareOf(a.address, bob);
    assert.equal(share.toString(), e18(1).toString(), "token should be transferred");
    share = await bentoBox.shareOf(a.address, maki);
    assert.equal(share.toString(), e18(1).toString(), "token should be transferred");
  });

  it('should allow transferShare to bob and maki by alice', async () => {
    await a.approve(bentoBox.address, e18(2), { from: alice });
    await bentoBox.deposit(a.address, alice, e18(2), { from: alice });
    await bentoBox.transferMultipleShare(a.address, alice, [bob, maki], [e18(1),e18(1)], { from: alice });
    let share = await bentoBox.shareOf(a.address, alice);
    assert.equal(share.toString(), e18(0).toString(), "token should be transferred");
    share = await bentoBox.shareOf(a.address, bob);
    assert.equal(share.toString(), e18(1).toString(), "token should be transferred");
    share = await bentoBox.shareOf(a.address, maki);
    assert.equal(share.toString(), e18(1).toString(), "token should be transferred");
  });

  it('should allow to skim tokens', async () => {
    await a.transfer(bentoBox.address, e18(1), { from: alice });
    let share = await bentoBox.shareOf(a.address, bob);
    assert.equal(share.toString(), e18(0).toString(), "bob should have no tokens");
    await bentoBox.methods['skim(address)'](a.address, { from: bob });
    share = await bentoBox.shareOf(a.address, bob);
    assert.equal(share.toString(), e18(1).toString(), "bob should have tokens");
  });

  it('should allow to skim tokens to other address', async () => {
    await a.transfer(bentoBox.address, e18(1), { from: alice });
    let share = await bentoBox.shareOf(a.address, maki);
    assert.equal(share.toString(), e18(0).toString(), "maki should have no tokens");
    await bentoBox.methods['skimTo(address,address)'](a.address, maki, { from: bob });
    share = await bentoBox.shareOf(a.address, maki);
    assert.equal(share.toString(), e18(1).toString(), "maki should have tokens");
  });

  it('should allow to skim ether', async () => {
    // TODO: look up how to mint ETH to BentoBox
  });

  it('should allow to skim ether to other address', async () => {
    // TODO: look up how to mint ETH to BentoBox
  });

  it('should allow flashloan', async () => {
    await a.transfer(bentoBox.address, e18(2), { from: alice });
    await a.approve(bentoBox.address, e18(2), { from: alice });
    await bentoBox.deposit(a.address, alice, e18(1), { from: alice });

    let param = web3.eth.abi.encodeParameter('bool', true);
    let flashLoaner = await FlashLoaner.new({ from: accounts[0] });
    await a.transfer(flashLoaner.address, e18(2), { from: alice });
    await bentoBox.flashLoan(a.address, e18(1),flashLoaner.address, param, { from: maki });
    let amount = await bentoBox.toAmount(a.address, e18(1));
    assert.equal(amount.toString(), e18(1).mul(new web3.utils.BN(1.0005)).toString());

  });

  it('should allow successfull batch call', async () => {
    await a.approve(bentoBox.address, e18(2), { from: alice });
    let deposit = bentoJSON.abi.find(element => element.name == "deposit" && element.inputs.length == 3);
    deposit = web3.eth.abi.encodeFunctionCall(deposit, [a.address, alice, e18(1)]);
    let transfer = bentoJSON.abi.find(element => element.name == "transfer");
    transfer = web3.eth.abi.encodeFunctionCall(transfer, [a.address, alice, bob, e18(1)]);
    await bentoBox.batch([deposit, transfer], true, { from: alice });
    let share = await bentoBox.shareOf(a.address, bob);
    assert.equal(share.toString(), e18(1).toString(), "bob should have tokens");
  });

  it('should allow successfull batch call if parameter is false', async () => {
    await a.approve(bentoBox.address, e18(2), { from: alice });
    let deposit = bentoJSON.abi.find(element => element.name == "deposit" && element.inputs.length == 3);
    deposit = web3.eth.abi.encodeFunctionCall(deposit, [a.address, alice, e18(1)]);
    let transfer = bentoJSON.abi.find(element => element.name == "transfer");
    transfer = web3.eth.abi.encodeFunctionCall(transfer, [a.address, alice, bob, e18(1)]);
    await bentoBox.batch([deposit, transfer], false, { from: alice });
    let share = await bentoBox.shareOf(a.address, bob);
    assert.equal(share.toString(), e18(1).toString(), "bob should have tokens");
  });

  it('should not revert on batch if parameter is false', async () => {
    await a.approve(bentoBox.address, e18(2), { from: alice });
    let deposit = bentoJSON.abi.find(element => element.name == "deposit" && element.inputs.length == 3);
    deposit = web3.eth.abi.encodeFunctionCall(deposit, [a.address, alice, e18(1)]);
    let transfer = bentoJSON.abi.find(element => element.name == "transfer");
    transfer = web3.eth.abi.encodeFunctionCall(transfer, [a.address, alice, bob, e18(2)]);
    await bentoBox.batch([deposit, transfer], false, { from: alice });
    let share = await bentoBox.shareOf(a.address, alice);
    assert.equal(share.toString(), e18(1).toString(), "alice should have tokens");
    share = await bentoBox.shareOf(a.address, bob);
    assert.equal(share.toString(), e18(0).toString(), "bob should not have tokens");
  });

  it('should revert on batch if parameter is true', async () => {
    await a.approve(bentoBox.address, e18(2), { from: alice });
    let deposit = bentoJSON.abi.find(element => element.name == "deposit" && element.inputs.length == 3);
    deposit = web3.eth.abi.encodeFunctionCall(deposit, [a.address, alice, e18(1)]);
    let transfer = bentoJSON.abi.find(element => element.name == "transfer");
    transfer = web3.eth.abi.encodeFunctionCall(transfer, [a.address, alice, bob, e18(2)]);
    truffleAssert.reverts(bentoBox.batch([deposit, transfer], true, { from: alice }), 'BentoBox: Transaction failed');
    let share = await bentoBox.shareOf(a.address, alice);
    assert.equal(share.toString(), e18(0).toString(), "alice should not have tokens");
    share = await bentoBox.shareOf(a.address, bob);
    assert.equal(share.toString(), e18(0).toString(), "bob should not have tokens");
  });

  it("masterContract should not be approved in base case", async () => {
    let approved = await bentoBox.masterContractApproved(pairMaster.address, alice);
    assert.equal(approved, false);
  });


  it("should allow to approve masterContract", async () => {
    await bentoBox.setMasterContractApproval(pairMaster.address, true, { from: alice });
    let approved = await bentoBox.masterContractApproved(pairMaster.address, alice);
    assert.equal(approved, true);
  });

  it("should allow to retract approval of masterContract", async () => {
    await bentoBox.setMasterContractApproval(pairMaster.address, true, { from: alice });
    await bentoBox.setMasterContractApproval(pairMaster.address, false, { from: alice });
    let approved = await bentoBox.masterContractApproved(pairMaster.address, alice);
    assert.equal(approved, false);
  });



});
