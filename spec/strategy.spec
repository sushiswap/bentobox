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

/* Transfers excess tokens above balance. On a positive profit, BentoBox’s balance increases and the return value is the profit above balance. On negative profit, the negative profit is returned. */
rule integrityHarvest(uint256 balance) {
	require receiver() == receiverInstance;
	env e;
	uint256 balanceBefore = tokenInstance.balanceOf(receiverInstance);

	int256 amountAdded = harvest(e, balance,_);

	require amountAdded < MIN_INT();
	uint256 balanceAfter = tokenInstance.balanceOf(receiverInstance);
	
	if (compareGTzero(amountAdded)) {
		// strategy made profit 
		assert checkAplusBeqC(balanceBefore, amountAdded, balanceAfter), "wrong balance transfered to receiver";
	} else {
		// strategy made loss
		assert balanceBefore == balanceAfter, "balance should not change if profit is negative";
	}
}

/* A withdraw operation increases the BentoBox’s balance by the withdrawn amount */
rule integrityWithdraw(uint256 amount) {
	require receiver() == receiverInstance;
	
	uint256 balanceBefore = tokenInstance.balanceOf(receiverInstance);
	
	env e;
	uint256 actualAmount = withdraw(e, amount);
	
	uint256 balanceAfter = tokenInstance.balanceOf(receiverInstance);

	mathint t = balanceBefore + actualAmount;
	require t <= MAX_UNSIGNED_INT();
	
	assert balanceAfter == balanceBefore + actualAmount, "wrong balance transfered to receiver";
}

rule strategyIntegrityWithdraw(uint256 amount) {
	require receiver() == receiverInstance;
	
	uint256 strategyBalanceBefore = tokenInstance.balanceOf(currentContract);

	env e;
	uint256 actualAmount = withdraw(e, amount);

	mathint t = strategyBalanceBefore - actualAmount;
	require t >= 0;
	
	uint256 strategyBalanceAfter = tokenInstance.balanceOf(currentContract);

	assert strategyBalanceAfter == strategyBalanceBefore - actualAmount, "strategy balance is not correct";
}

/* The exit operation transfers all of the strategy's assets to BentoBox */
rule integrityExit(uint256 balance) {
	require receiver() == receiverInstance;

	uint256 balanceBefore = tokenInstance.balanceOf(receiverInstance);
	
	env e;
	int256 amountAdded = exit(e, balance);
	
	uint256 balanceAfter = tokenInstance.balanceOf(receiverInstance);

	mathint t = balanceBefore + balance;
	require t <= MAX_UNSIGNED_INT();
	uint256 expectedBalance = balanceBefore + balance;
	assert checkAplusBeqC(expectedBalance, amountAdded, balanceAfter), "wrong balance transfered to receiver";
}

rule strategyIntegrityExit(uint256 balance) {
	uint256 strategyBalanceBefore = tokenInstance.balanceOf(currentContract);
	
	env e;
	int256 amountAdded = exit(e, balance);

	assert compareLTzero(amountAdded) => strategyBalanceBefore < balance,
	"exit returned a negative amountAdded, but there was a positive profit w.r.t. balance";

	uint256 strategyBalanceAfter = tokenInstance.balanceOf(currentContract);
	
	
	assert strategyBalanceAfter == 0, "did not send all available tokens to receiver";
}