/*
    This is a specification file for smart contract verification using the Certora prover.
    For simplified rules on CompoundStrategy.
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

// Working on a simplified version of cToken that doesn't revert


//The BentoBox should be able to exit from the strategy and withdraw all possible assets
rule exitRevert(uint256 balance) {
	env e;
	require (e.msg.value == 0 && e.msg.sender == receiver() && !exited());
	require (tokenBalanceOf(tokenInstance,receiverInstance) + tokenBalanceOf(tokenInstance,currentContract) <= MAX_INT());
	exit@withrevert(e, balance);

	bool succ = !lastReverted;
	assert(succ, "exitReverted");
}
