const fs = require('fs');
const truffleAssert = require('./helpers/truffle-assertions');
const AssertionError = require('./helpers/assertion-error');
const BentoBox = artifacts.require("BentoBox");
const Pair = artifacts.require("LendingPair");
const FlashLoaner = artifacts.require("FlashLoaner");
const WETH9 = artifacts.require("WETH9");
const {e18, bn} = require('./helpers/utils');
const ReturnFalseERC20 = artifacts.require("ReturnFalseERC20");
const RevertingERC20 = artifacts.require("RevertingERC20");
const permit = require("./helpers/permit");
const ethereumjsUtil = require('ethereumjs-util');
const {ecsign} = ethereumjsUtil;

contract('BentoBox', (accounts) => {
  let bentoBox;
  let a;
  let b;
  let weth;
  const alice = accounts[1];
  const bob = accounts[2];
  const maki = accounts[3];
  const daveAddress = accounts[4];
  let pairMaster;
  const davePrivateKey = "0x043a569345b08ead19d1d4ba3462b30632feba623a2a85a3b000eb97f709f09f";

  beforeEach(async () => {
    weth = await WETH9.new();
    bentoBox = await BentoBox.new(weth.address);
    a = await ReturnFalseERC20.new("Token A", "A", e18(10000000), { from: accounts[0] });
    b = await RevertingERC20.new("Token B", "B", e18(10000000), { from: accounts[0] });
    await a.transfer(alice, e18(1000));
    await b.transfer(bob, e18(1000));
    pairMaster = await Pair.deployed();
  });

  it('should not allow to approve MasterContract at zero address', async () => {
    await truffleAssert.reverts(bentoBox.setMasterContractApproval("0x0000000000000000000000000000000000000000", true), 'BentoBox: masterContract must be set');
  });

  it('should allow deposit', async () => {
    await a.approve(bentoBox.address, e18(1), { from: alice });
    await bentoBox.deposit(a.address, alice, e18(1), { from: alice });
    let amount = await bentoBox.balanceOf(a.address, alice);
    assert.equal(amount.toString(), e18(1).toString());
  });

  it('should allow deposit with Ethereum', async () => {
    await bentoBox.deposit(weth.address, bob, e18(1), { from: bob, value: e18(1) });
    assert.equal((await weth.balanceOf(bentoBox.address)).toString(), e18(1).toString(), "BentoBox should hold WETH");
    amount = await bentoBox.balanceOf(weth.address, bob);
    assert.equal(amount.toString(), e18(1).toString(), "bob should have weth");
  });
/*
 it('should allow depositWithPermit', async () => {
    await a.transfer(daveAddress, e18(1), {from: alice});
    let nonce = await a.nonces(daveAddress);
    nonce = nonce.toNumber();
    let block = await web3.eth.getBlock("latest");
    const deadline = Number(block.timestamp)+10000;
    const digest = await permit.getApprovalDigest(
        a,
        {owner: daveAddress, spender: bentoBox.address, value: e18(1).toString()},
        nonce,
        deadline
      );
    const {v, r, s} = ecsign(
        Buffer.from(digest.slice(2), 'hex'),
        Buffer.from(davePrivateKey.replace('0x', ''), 'hex')
    );
    await bentoBox.depositWithPermit(a.address, daveAddress, e18(1), deadline, v, r, s, { from: daveAddress });
    let amount = await bentoBox.balanceOf(a.address, daveAddress);
    assert.equal(amount.toString(), e18(1).toString());
  });
  */
  
  it('should not allow deposit without approve', async () => {
    truffleAssert.reverts(bentoBox.deposit(a.address, alice, e18(1), { from: alice }), "TransferFrom failed at ERC20");
    let amount = await bentoBox.balanceOf(a.address, alice);
    assert.equal(amount.toString(), e18(0).toString());
  });

  it('should give back correct token amount', async () => {
    await a.approve(bentoBox.address, e18(1), { from: alice });
    await bentoBox.deposit(a.address, alice, e18(1), { from: alice });
    let amount = await bentoBox.balanceOf(a.address, alice);
    assert.equal(amount.toString(), e18(1).toString());
  });

  it('should calculate correct amount for second deposit', async () => {
    await a.approve(bentoBox.address, e18(3), { from: alice });
    await bentoBox.deposit(a.address, alice, e18(1), { from: alice });
    await bentoBox.deposit(a.address, alice, e18(2), { from: alice });
    let amount = await bentoBox.balanceOf(a.address, alice);
    assert.equal(amount.toString(), e18(3).toString(), "incorrect amount calculation");
    let totalSupply = await bentoBox.totalSupply(a.address);
    assert.equal(totalSupply.toString(), e18(3).toString(), "incorrect total amount");
  });

  it('should allow to deposit for other user', async () => {
    await a.approve(bentoBox.address, e18(3), { from: alice });
    await bentoBox.methods['depositTo(address,address,address,uint256)'](a.address, alice, bob, e18(1), { from: alice });
    let amount = await bentoBox.balanceOf(a.address, bob);
    assert.equal(amount.toString(), e18(1).toString(), "incorrect amount calculation");
    let totalSupply = await bentoBox.totalSupply(a.address);
    assert.equal(totalSupply.toString(), e18(1).toString(), "incorrect total amount");
  });
  /*

  it('should allow to depositWithPermit for other user', async () => {
    await a.transfer(daveAddress, e18(1), {from: alice});
    let nonce = await a.nonces(daveAddress);
    nonce = nonce.toNumber();
    let block = await web3.eth.getBlock("latest");
    const deadline = Number(block.timestamp)+10000;
    const digest = await permit.getApprovalDigest(
        a,
        {owner: daveAddress, spender: bentoBox.address, value: e18(1).toString()},
        nonce,
        deadline
      );
    const {v, r, s} = ecsign(
        Buffer.from(digest.slice(2), 'hex'),
        Buffer.from(davePrivateKey.replace('0x', ''), 'hex')
    );
    await bentoBox.depositWithPermitTo(a.address, daveAddress, alice, e18(1), deadline, v, r, s, { from: daveAddress });
    let amount = await bentoBox.balanceOf(a.address, alice);
    assert.equal(amount.toString(), e18(1).toString());
  });
  */
  it('should allow to withdraw', async () => {
    await a.approve(bentoBox.address, e18(1), { from: alice });
    await bentoBox.deposit(a.address, alice, e18(1), { from: alice });
    await bentoBox.methods['withdraw(address,address,uint256)'](a.address, alice, e18(1), { from: alice });
    assert.equal((await a.balanceOf(alice)).toString(), e18(1000).toString(), "alice should have all of their tokens back");
    let amount = await bentoBox.balanceOf(a.address, alice);
    assert.equal(amount.toString(), e18(0).toString(), "token should be withdrawn");
  });

  it('should allow to withdraw ETH', async () => {
    await bentoBox.deposit(weth.address, bob, e18(1), { from: bob, value: e18(1) });
    await bentoBox.methods['withdraw(address,address,uint256)'](weth.address, bob, e18(1), { from: bob });
    amount = await bentoBox.balanceOf(weth.address, bob);
    assert.equal(amount.toString(), e18(0).toString(), "token should be withdrawn");
  });

  it('should not allow to withdraw larger amount than available', async () => {
    await a.approve(bentoBox.address, e18(1), { from: alice });
    await bentoBox.deposit(a.address, alice, e18(1), { from: alice });
    truffleAssert.underflow(bentoBox.methods['withdraw(address,address,uint256)'](a.address, alice, e18(5), { from: alice }));
  });

  it('should allow to withdraw to other user', async () => {
    await a.approve(bentoBox.address, e18(1), { from: alice });
    await bentoBox.deposit(a.address, alice, e18(1), { from: alice });
    await bentoBox.methods['withdrawFrom(address,address,address,uint256)'](a.address, alice, bob, e18(1), { from: alice });
    assert.equal((await a.balanceOf(alice)).toString(), e18(999).toString(), "alice should not have received the token back");
    assert.equal((await a.balanceOf(bob)).toString(), e18(1).toString(), "bob should have received their tokens");
    let amount = await bentoBox.balanceOf(a.address, alice);
    assert.equal(amount.toString(), e18(0).toString(), "token should be withdrawn");
  });

  it('should not allow transfer from bob', async () => {
    await a.approve(bentoBox.address, e18(1), { from: bob });
    truffleAssert.underflow(bentoBox.transfer(a.address, alice, e18(1), { from: bob }));
  });

  it('should allow transfer to bob by alice', async () => {
    await a.approve(bentoBox.address, e18(1), { from: alice });
    await bentoBox.deposit(a.address, alice, e18(1), { from: alice });
    await bentoBox.transferFrom(a.address, alice, bob, e18(1), { from: alice });
    let amount = await bentoBox.balanceOf(a.address, alice);
    assert.equal(amount.toString(), e18(0).toString(), "token should be transferred");
    amount = await bentoBox.balanceOf(a.address, bob);
    assert.equal(amount.toString(), e18(1).toString(), "token should be transferred");
  });

  it('should allow transfer to bob and maki by alice', async () => {
    await a.approve(bentoBox.address, e18(2), { from: alice });
    await bentoBox.deposit(a.address, alice, e18(2), { from: alice });
    await bentoBox.transferMultipleFrom(a.address, alice, [bob, maki], [e18(1),e18(1)], { from: alice });
    let amount = await bentoBox.balanceOf(a.address, alice);
    assert.equal(amount.toString(), e18(0).toString(), "token should be transferred");
    amount = await bentoBox.balanceOf(a.address, bob);
    assert.equal(amount.toString(), e18(1).toString(), "token should be transferred");
    amount = await bentoBox.balanceOf(a.address, maki);
    assert.equal(amount.toString(), e18(1).toString(), "token should be transferred");
  });

  it('should allow to skim tokens', async () => {
    await a.transfer(bentoBox.address, e18(1), { from: alice });
    let amount = await bentoBox.balanceOf(a.address, bob);
    assert.equal(amount.toString(), e18(0).toString(), "bob should have no tokens");
    await bentoBox.methods['skim(address)'](a.address, { from: bob });
    amount = await bentoBox.balanceOf(a.address, bob);
    assert.equal(amount.toString(), e18(1).toString(), "bob should have tokens");
  });

  it('should allow to skim tokens to other address', async () => {
    await a.transfer(bentoBox.address, e18(1), { from: alice });
    let amount = await bentoBox.balanceOf(a.address, maki);
    assert.equal(amount.toString(), e18(0).toString(), "maki should have no tokens");
    await bentoBox.methods['skimTo(address,address)'](a.address, maki, { from: bob });
    amount = await bentoBox.balanceOf(a.address, maki);
    assert.equal(amount.toString(), e18(1).toString(), "maki should have tokens");
  });

  it('should allow to skim ether', async () => {
    await bentoBox.batch([], true, {from: alice, value: e18(1)})
    await bentoBox.skimETH({from: alice});
    assert.equal((await weth.balanceOf(bentoBox.address)).toString(), e18(1).toString(), "BentoBox should hold WETH");
    amount = await bentoBox.balanceOf(weth.address, alice);
    assert.equal(amount.toString(), e18(1).toString(), "alice should have weth");
  });

  it('should allow to skim ether to other address', async () => {
    await bentoBox.batch([], true, {from: alice, value: e18(1)})
    await bentoBox.skimETHTo(bob, {from: alice});
    assert.equal((await weth.balanceOf(bentoBox.address)).toString(), e18(1).toString(), "BentoBox should hold WETH");
    amount = await bentoBox.balanceOf(weth.address, bob);
    assert.equal(amount.toString(), e18(1).toString(), "bob should have weth");
  });

  it('should allow successfull batch call', async () => {
    await a.approve(bentoBox.address, e18(2), { from: alice });
    let deposit = (BentoBox._json.abi).find(element => element.name == "deposit" && element.inputs.length == 3);
    deposit = web3.eth.abi.encodeFunctionCall(deposit, [a.address, alice, e18(1).toString()]);
    let transferFrom = BentoBox._json.abi.find(element => element.name == "transferFrom");
    transferFrom = web3.eth.abi.encodeFunctionCall(transferFrom, [a.address, alice, bob, e18(1).toString()]);
    await bentoBox.batch([deposit, transferFrom], true, { from: alice });
    let amount = await bentoBox.balanceOf(a.address, bob);
    assert.equal(amount.toString(), e18(1).toString(), "bob should have tokens");
  });

  it('should allow successfull batch call if parameter is false', async () => {
    await a.approve(bentoBox.address, e18(2), { from: alice });
    let deposit = BentoBox._json.abi.find(element => element.name == "deposit" && element.inputs.length == 3);
    deposit = web3.eth.abi.encodeFunctionCall(deposit, [a.address, alice, e18(1).toString()]);
    let transferFrom = BentoBox._json.abi.find(element => element.name == "transferFrom");
    transferFrom = web3.eth.abi.encodeFunctionCall(transferFrom, [a.address, alice, bob, e18(1).toString()]);
    await bentoBox.batch([deposit, transferFrom], false, { from: alice });
    let amount = await bentoBox.balanceOf(a.address, bob);
    assert.equal(amount.toString(), e18(1).toString(), "bob should have tokens");
  });

  it('should not revert on batch if parameter is false', async () => {
    await a.approve(bentoBox.address, e18(2), { from: alice });
    let deposit = BentoBox._json.abi.find(element => element.name == "deposit" && element.inputs.length == 3);
    deposit = web3.eth.abi.encodeFunctionCall(deposit, [a.address, alice, e18(1).toString()]);
    let transferFrom = BentoBox._json.abi.find(element => element.name == "transferFrom");
    transferFrom = web3.eth.abi.encodeFunctionCall(transferFrom, [a.address, alice, bob, e18(2).toString()]);
    await bentoBox.batch([deposit, transferFrom], false, { from: alice });
    let amount = await bentoBox.balanceOf(a.address, alice);
    assert.equal(amount.toString(), e18(1).toString(), "alice should have tokens");
    amount = await bentoBox.balanceOf(a.address, bob);
    assert.equal(amount.toString(), e18(0).toString(), "bob should not have tokens");
  });

  it('should revert on batch if parameter is true', async () => {
    await a.approve(bentoBox.address, e18(2), { from: alice });
    let deposit = BentoBox._json.abi.find(element => element.name == "deposit" && element.inputs.length == 3);
    deposit = web3.eth.abi.encodeFunctionCall(deposit, [a.address, alice, e18(1).toString()]);
    let transferFrom = BentoBox._json.abi.find(element => element.name == "transferFrom");
    transferFrom = web3.eth.abi.encodeFunctionCall(transferFrom, [a.address, alice, bob, e18(2).toString()]);
    truffleAssert.reverts(bentoBox.batch([deposit, transferFrom], true, { from: alice }), 'Transaction failed');
    let amount = await bentoBox.balanceOf(a.address, alice);
    assert.equal(amount.toString(), e18(0).toString(), "alice should not have tokens");
    amount = await bentoBox.balanceOf(a.address, bob);
    assert.equal(amount.toString(), e18(0).toString(), "bob should not have tokens");
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
