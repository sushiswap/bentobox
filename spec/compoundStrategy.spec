/*
    This is a specification file for smart contract verification using the Certora prover.
    This file is run on compoundStrategy via script/runCompoundStrategy.sh
*/

/*
    Declaration of contracts used in the sepc 
*/
using DummyERC20A as tokenInstance 
// The contract that reveives back tokens from the strategy 
// usually it is the bentobox
using Receiver as receiverInstance
using Owner as ownerInstance

/*
    Declaration of methods that are used in the rules.
    envfree indicate that the method is not dependent on the environment (msg.value, msg.sender).
    Methods that are not declared here are assumed to be dependent on env.
*/
methods {
	leave(uint256 share) => NONDET
	receiver() returns (address) envfree
	owner() returns (address) envfree
	tokenBalanceOf(address token, address account) returns (uint256) envfree
	compareLEzero(int256 x) returns (bool) envfree
	compareLTzero(int256 x) returns (bool) envfree
	compareGEzero(int256 x) returns (bool) envfree
	compareGTzero(int256 x) returns (bool) envfree
	checkAplusBeqC(uint256 a, int256 b, uint256 c) returns (bool) envfree
	subToInt(uint256 a, uint256 b) returns (int256) envfree
	safeSub(uint256 a, uint256 b) returns (int256) envfree
	compareLEmaxUint255(int256 x ) returns (bool) envfree

	//IERC20 methods to be called to one of the tokens (DummyERC201, DummyWeth)
	balanceOf(address) => DISPATCHER(true) 
	totalSupply() => DISPATCHER(true)
	transferFrom(address from, address to, uint256 amount) => DISPATCHER(true)
	transfer(address to, uint256 amount) => DISPATCHER(true)
	permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) => NONDET
	
	// compound
	exited() returns (bool) envfree

	redeemAllowed(address cToken, address redeemer, uint redeemTokens) => NONDET
	redeemVerify(address cToken, address redeemer, uint redeemAmount, uint redeemTokens) => NONDET
	transferAllowed(address cToken, address src, address dst, uint transferTokens) => NONDET
	mintAllowed(address, address, uint) => NONDET

	// factory
	getPair(address tokenA, address tokenB) => NONDET
	getReserves() => NONDET
	swap(uint256 amount0Out, uint256 amount1Out, address to, bytes data) => NONDET 

	// to solve the havoc on to.call{value: value}(data)
	nop(bytes) => NONDET
}

definition MAX_UNSIGNED_INT() returns uint256 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

definition MAX_INT() returns int256 = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
definition MIN_INT() returns int256 = 0x8000000000000000000000000000000000000000000000000000000000000000;

/*
At any given time, except during function execution, the CompoundStrategy contract doesn’t hold any tokens, all are invested in the Compound protocol or passed back to BentoBox.
*/
rule allTokensAreInvested(uint256 amount, address to, bytes data) {
	env e;

	method f;
	calldataarg args;

	if (f.selector == skim(uint256).selector) {
		require amount == tokenBalanceOf(tokenInstance, currentContract);

		skim(e, amount);
	} else {
		require tokenBalanceOf(tokenInstance, currentContract) == 0;

		f(e, args);
	}

	assert(tokenBalanceOf(tokenInstance, currentContract) == 0, "all not invested");
}

/* No one except the owner can use the strategy after it has been exited */
/* The exited data field is never false once it is true*/
rule onceExitedIsTrueThenItIsNeverFalse() {
	env e;

	require exited() == true;

	method f;
	calldataarg args;

	f(e, args);

	assert(exited() == true, "exited became false");
}

/* Methods revert if the strategy has been exited except if they are called by the owner */
rule ifExitedIsTrueThenMethodsRevertExceptOwner() {
	env e;

	require exited() == true;
	method f;
	calldataarg args;

	require !f.isView && f.selector != claimOwnership().selector;
	require e.msg.sender != owner();
	f@withrevert(e, args);
	
	assert(lastReverted, "Methods didn't revert");
}

/* Transfers excess tokens above balance. On a positive profit, BentoBox’s balance increases and the return value is the profit above balance. On negative profit, the negative profit is returned. */
rule integrityHarvest(uint256 balance, uint256 strategyBalanceBefore) {
	require receiver() == receiverInstance;
	env e;
	uint256 balanceBefore = tokenBalanceOf(tokenInstance, receiverInstance);
		
	int256 amountAdded = harvest(e, balance,_);

	require amountAdded < MIN_INT();
	uint256 balanceAfter = tokenBalanceOf(tokenInstance, receiverInstance);
	
	if (compareGTzero(amountAdded)) {
		// strategy made profit 
		assert checkAplusBeqC(balanceBefore, amountAdded, balanceAfter), "wrong balance transfered to receiver";
	} else {
		// strategy made loss
		assert balanceBefore == balanceAfter, "balance should not change if profit is negative";
	}
}

/* A withdraw operation increases the BentoBox’s balance by the withdrawn amount */
rule integrityWithdraw(uint256 amount, uint256 balance) {
	require receiver() == receiverInstance;
	env e;
	uint256 balanceBefore = tokenBalanceOf(tokenInstance,receiverInstance);
		
	uint256 amountAdded = withdraw(e, amount);
	
	uint256 balanceAfter = tokenBalanceOf(tokenInstance,receiverInstance);

	mathint t = balanceBefore + amountAdded;
	require t <= MAX_UNSIGNED_INT();
	
	assert balanceAfter == balanceBefore + amountAdded, "wrong balance transfered to receiver";
}

/* The exit operation transfers all of the strategy's assets to BentoBox */
rule integrityExit(uint256 balance) {
	require receiver() == receiverInstance;
	env e;
	uint256 balanceBefore = tokenBalanceOf(tokenInstance,receiverInstance);
		
	int256 amountAdded = exit(e, balance);
	
	uint256 balanceAfter = tokenBalanceOf(tokenInstance,receiverInstance);

	mathint t = balanceBefore + balance;
	require t <= MAX_UNSIGNED_INT();
	uint256 expectedBalance = balanceBefore + balance;
	assert checkAplusBeqC(expectedBalance, amountAdded, balanceAfter), "wrong balance transfered to receiver";
}