/*
    This is a specification file for smart contract verification with the Certora prover.
    This file is run on symbolicStrategy via  script/_runStrategt.sh
	And on SushiStrategy via scripts/_runSushiStrategt.sh
*/

/*
    Declaration of contracts used in the sepc 
*/
using DummyERC20A as tokenInstance 
using Owner as ownerInstance

/*
    Declaration of methods that are used in the rules.
    envfree indicate that the method is not dependent on the environment (msg.value, msg.sender).
    Methods that are not declared here are assumed to be dependent on env.
*/
methods {
	leave(uint256 share) => NONDET
	owner() returns (address) envfree
	tokenInstance.balanceOf(address account) returns (uint256) envfree
	compareLEzero(int256 x) returns (bool) envfree
	compareLTzero(int256 x) returns (bool) envfree
	compareGEzero(int256 x) returns (bool) envfree
	compareGTzero(int256 x) returns (bool) envfree
	checkAplusBeqC(uint256 a, int256 b, uint256 c)  returns (bool) envfree
	subToInt(uint256 a, uint256 b) returns (int256) envfree
	safeSub(uint256 a, uint256 b) returns (int256) envfree
	compareLEmaxUint255(int256 x ) returns (bool) envfree
}

definition MAX_UNSIGNED_INT() returns uint256 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

definition MAX_INT() returns int256 = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
definition MIN_INT() returns int256 = 0x8000000000000000000000000000000000000000000000000000000000000000;

rule integrityHarvest(uint256 balance, uint256 strategyBalanceBefore) {
	require owner() == ownerInstance;
	
	require strategyBalanceBefore == tokenInstance.balanceOf(currentContract);
	uint256 balanceBefore = tokenInstance.balanceOf(ownerInstance);
	
	env e;
	int256  amountAdded = harvest(e, balance,_);

	require amountAdded < MIN_INT();
	uint256 strategyBalanceAfter = tokenInstance.balanceOf(currentContract);
	uint256 balanceAfter = tokenInstance.balanceOf(ownerInstance);
	
	if (compareGTzero(amountAdded)) {
		// strategy made profit 
		assert checkAplusBeqC(balanceBefore, amountAdded, balanceAfter), "wrong balance transfered to owner";
	} else {
		// strategy made loss
		assert balanceBefore == balanceAfter, "balance should not change if profit is negative";
	}
	
}

rule integrityWithdraw(uint256 amount, uint256 balance) {
	require owner() == ownerInstance;
	
	uint256 strategyBalanceBefore = tokenInstance.balanceOf(currentContract);
	uint256 balanceBefore = tokenInstance.balanceOf(ownerInstance);
	
	env e;
	uint256 amountAdded = withdraw(e, amount);
	
	uint256 strategyBalanceAfter = tokenInstance.balanceOf(currentContract);
	uint256 balanceAfter = tokenInstance.balanceOf(ownerInstance);

	mathint t = balanceBefore + amountAdded;
	require t <= MAX_UNSIGNED_INT();
	
	assert balanceAfter == balanceBefore + amountAdded, "wrong balance transfered to owner";
	assert strategyBalanceAfter == strategyBalanceBefore  - amountAdded, "strategy balance is not correct";
}

rule integrityExit(uint256 balance) {
	require owner() == ownerInstance;

	uint256 strategyBalanceBefore = tokenInstance.balanceOf(currentContract);
	uint256 balanceBefore = tokenInstance.balanceOf(ownerInstance);
	
	env e;
	int256 amountAdded = exit(e, balance);
	
	uint256 strategyBalanceBAfter = tokenInstance.balanceOf(currentContract);
	uint256 balanceAfter = tokenInstance.balanceOf(ownerInstance);

	mathint t = balanceBefore + balance;
	require t <= MAX_UNSIGNED_INT();
	uint256 expectedBalance = balanceBefore + balance;
	assert checkAplusBeqC(expectedBalance, amountAdded, balanceAfter), "wrong balance transfered to owner";
	assert compareLTzero(amountAdded) =>  strategyBalanceBefore < balance , "did not send all availaible tokens";
}
