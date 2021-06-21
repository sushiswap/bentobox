import "./spec/strategy.spec"
import "./spec/IERC20_methods_summaries.spec"
/*
    This is a specification file for smart contract verification using the Certora prover.
    This file is run on compoundStrategy via script/runCompoundStrategy.sh
*/
/*
    Declaration of contracts used in the sepc 
*/
using Owner as ownerInstance

/*
    Declaration of methods that are used in the rules.
    envfree indicate that the method is not dependent on the environment (msg.value, msg.sender).
    Methods that are not declared here are assumed to be dependent on env.
*/
methods {
	owner() returns (address) envfree
	// compound
	mintAllowed(address, address, uint) => NONDET
	// factory
	getPair(address tokenA, address tokenB) => NONDET
	getReserves() => NONDET
	swap(uint256 amount0Out, uint256 amount1Out, address to, bytes data) => NONDET 

	// to solve the havoc on to.call{value: value}(data)
	nop(bytes) => NONDET
}

use rule integrityHarvest

use rule integrityWithdraw

use rule integrityExit

/*
At any given time, except during function execution, the CompoundStrategy contract doesn’t hold any tokens, all are invested in the Compound protocol or passed back to BentoBox.
*/
rule allTokensAreInvested(uint256 amount, address to, bytes data) {
	env e;

	method f;
	calldataarg args;

	if (f.selector == skim(uint256).selector) {
		require amount == tokenInstance.balanceOf(currentContract);

		skim(e, amount);
	} else {
		require tokenInstance.balanceOf(currentContract) == 0;

		f(e, args);
	}

	assert(tokenInstance.balanceOf(currentContract) == 0, "all not invested");
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
