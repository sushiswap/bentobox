/*
    This is a specification file for smart contract verification with the Certora prover.
    This file is run on symbolicStrategy via script/_runStrategt.sh
	And on SushiStrategy via scripts/_runSushiStrategt.sh
*/

/*
    Declaration of contracts used in the sepc 
*/
using DummyERC20A as tokenInstance 
// The contract that reveives back tokens from the strategy 
// usually it is the bentobox
using Receiver as receiverInstance

/*
    Declaration of methods that are used in the rules.
    envfree indicate that the method is not dependent on the environment (msg.value, msg.sender).
    Methods that are not declared here are assumed to be dependent on env.
*/
methods {
	leave(uint256 share) => NONDET
	receiver() returns (address) envfree
	tokenInstance.balanceOf(address account) returns (uint256) envfree
	compareLEzero(int256 x) returns (bool) envfree
	compareLTzero(int256 x) returns (bool) envfree
	compareGEzero(int256 x) returns (bool) envfree
	compareGTzero(int256 x) returns (bool) envfree
	checkAplusBeqC(uint256 a, int256 b, uint256 c) returns (bool) envfree
	subToInt(uint256 a, uint256 b) returns (int256) envfree
	safeSub(uint256 a, uint256 b) returns (int256) envfree
	compareLEmaxUint255(int256 x ) returns (bool) envfree

	// compound
	exited() returns (bool) envfree

	redeemAllowed(address cToken, address redeemer, uint redeemTokens) => NONDET
	redeemVerify(address cToken, address redeemer, uint redeemAmount, uint redeemTokens) => NONDET
	transferAllowed(address cToken, address src, address dst, uint transferTokens) => NONDET
}

definition MAX_UNSIGNED_INT() returns uint256 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

definition MAX_INT() returns int256 = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
definition MIN_INT() returns int256 = 0x8000000000000000000000000000000000000000000000000000000000000000;

rule integrityHarvest(uint256 balance, uint256 strategyBalanceBefore) {
	require receiver() == receiverInstance;
	
	require strategyBalanceBefore == tokenInstance.balanceOf(currentContract);
	uint256 balanceBefore = tokenInstance.balanceOf(receiverInstance);
	
	env e;
	int256 amountAdded = harvest(e, balance,_);

	require amountAdded < MIN_INT();
	uint256 strategyBalanceAfter = tokenInstance.balanceOf(currentContract);
	uint256 balanceAfter = tokenInstance.balanceOf(receiverInstance);
	
	if (compareGTzero(amountAdded)) {
		// strategy made profit 
		assert checkAplusBeqC(balanceBefore, amountAdded, balanceAfter), "wrong balance transfered to receiver";
	} else {
		// strategy made loss
		assert balanceBefore == balanceAfter, "balance should not change if profit is negative";
	}
	
}

rule integrityWithdraw(uint256 amount, uint256 balance) {
	require receiver() == receiverInstance;
	
	uint256 strategyBalanceBefore = tokenInstance.balanceOf(currentContract);
	uint256 balanceBefore = tokenInstance.balanceOf(receiverInstance);
	
	env e;
	uint256 amountAdded = withdraw(e, amount);
	
	uint256 strategyBalanceAfter = tokenInstance.balanceOf(currentContract);
	uint256 balanceAfter = tokenInstance.balanceOf(receiverInstance);

	mathint t = balanceBefore + amountAdded;
	require t <= MAX_UNSIGNED_INT();
	
	assert strategyBalanceAfter == strategyBalanceBefore - amountAdded, "strategy balance is not correct";
	assert balanceAfter == balanceBefore + amountAdded, "wrong balance transfered to receiver";
}

rule integrityExit(uint256 balance) {
	require receiver() == receiverInstance;

	uint256 strategyBalanceBefore = tokenInstance.balanceOf(currentContract);
	uint256 balanceBefore = tokenInstance.balanceOf(receiverInstance);
	
	env e;
	int256 amountAdded = exit(e, balance);
	
	uint256 strategyBalanceBAfter = tokenInstance.balanceOf(currentContract);
	uint256 balanceAfter = tokenInstance.balanceOf(receiverInstance);

	mathint t = balanceBefore + balance;
	require t <= MAX_UNSIGNED_INT();
	uint256 expectedBalance = balanceBefore + balance;
	assert checkAplusBeqC(expectedBalance, amountAdded, balanceAfter), "wrong balance transfered to receiver";
	assert compareLTzero(amountAdded) => strategyBalanceBefore < balance , "did not send all availaible tokens";
}