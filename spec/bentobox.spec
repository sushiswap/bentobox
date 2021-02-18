/*
    This is a specification file for smart contract verification with the Certora prover.
    This file is run with scripts/_runBentoBox.sh
*/

/*
    Declaration of contracts used in the sepc 
*/
using DummyERC20A as tokenA
using DummyWeth as wethTokenImpl
using SymbolicStrategy as strategyInstance
using Borrower as borrower

/*
    Declaration of methods that are used in the rules.
    envfree indicate that the method is not dependent on the environment (msg.value, msg.sender).
    Methods that are not declared here are assumed to be dependent on env.
*/
methods {
	//IERC20 methods to be called to one of the tokens (DummyERC201, DummyWeth)
	balanceOf(address) => DISPATCHER(true) 
	totalSupply() => DISPATCHER(true)
	transferFrom(address from, address to, uint256 amount) => DISPATCHER(true)
	transfer(address to, uint256 amount) => DISPATCHER(true)
	permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) => NONDET
	//weth specific methods
	wethTokenImpl.deposit() => DISPATCHER(true)
	wethTokenImpl.withdraw(uint256 amount) => DISPATCHER(true)
	

	// strategy code
	harvest(uint256 balance, address sender) => DISPATCHER(true)  
    skim(uint256 balance) => DISPATCHER(true)
	harvest(uint256 balance) => DISPATCHER(true)
	withdraw(uint256 amount, uint256 balance) => DISPATCHER(true)
	exit(uint256 balance) => DISPATCHER(true) 
	strategyInstance.token() returns address envfree
	strategyInstance.owner() returns address envfree

	// borrower - due to issue in Certora Prover for specifying bytes parameter, using hashcode
	// onFlashLoan(address,address,uint256,uint256,bytes) => DISPATCHER(true) 
	23e30c8b() => DISPATCHER(true)
	// onBatchFlashLoan(address,address[],uint256[],uint256[],bytes) => DISPATCHER(true) 
	d9d17623() => DISPATCHER(true)

	// function that do not use the environment (msg.sender, ...)
	totalTokenAmount(address token) returns (uint128) envfree
	totalTokenShare(address token) returns (uint128) envfree
	tokenBalanceOf(address token) returns (uint256) envfree
	tokenBalanceOfUser(address token, address user) returns (uint256) envfree // external balanceOf

	// getters 
	// mapping balanceOf[token][a]
	balanceOf(address token, address account) returns (uint256) envfree // internal balanceOf
	toAmount(address token, uint256 share, bool roundUp) returns (uint256) envfree
	harnessOther() returns (address) envfree
	harnessFrom() returns (address) envfree
	harnessBorrower() returns (address) envfree
	harnessToken() returns (address) envfree
	strategy(address) returns (address) envfree
	getStrategyTokenBalance(address token) returns (uint256) envfree
}

definition MAX_UINT256() returns uint256 =
	0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

/* represent the sum of balanceOf(address token, address account) for all account */
ghost shareSum(uint) returns uint256 {
    init_state axiom forall address token. shareSum(token) == 0;
}

hook Sstore balanceOf[KEY uint token][KEY uint a] uint balance (uint oldBalance) STORAGE {
	havoc shareSum assuming shareSum@new(token) == shareSum@old(token) + balance - oldBalance &&
		(forall uint t. t != token => shareSum@new(t) == shareSum@old(t));
}

// Invariants
invariant zeroStrategy(address token)
	strategy(token) == 0 => getStrategyTokenBalance(token) == 0
	
invariant integrityOfTotalShare(address token) 
 	totalTokenShare(token) == shareSum(token)

// Rules

/**
 * solvency:
 * internal representation of total assets:
 * _tokenBalanceOf(token) >= totals[token].elastics
 * checking if the the total assets within the BentoBox and outside
 * the BentoBox are preserved
 */
rule solvency(address token, address from, address to,
								  uint256 amount, uint256 share, method f,
								  uint256 _strategy,
								  uint256 strategy_,
								  address straToken,
								  uint256 _systemBalance,
								  uint256 systemBalance_,
								  uint256 _strategyBalance,
								  uint256 strategyBalance_  ) {
	//link the strategy to the current token
	require strategyInstance.token() == token;
	// link the strategy owner to the bentobox
	require strategyInstance.owner() == currentContract;
	require harnessBorrower() == borrower;
	require harnessToken() == token;

	mathint _actual = tokenBalanceOf(token); //casting form uint256
	require _systemBalance == tokenBalanceOfUser(token, currentContract);
	mathint _asElastic = totalTokenAmount(token); //casting from uint128

	require _actual == _asElastic;
	require _strategy == getStrategyTokenBalance(token);
	
	require straToken == strategy(token);
	//proven in zeroStrategy
	require straToken == 0 => _strategy == 0;
	require _strategyBalance == tokenBalanceOfUser(token, straToken);

	env e;
	calldataarg args;
	callFunctionWithParams(token, from, to, amount, share, f);

	mathint actual_ = tokenBalanceOf(token); //casting form uint256
	require systemBalance_ == tokenBalanceOfUser(token, currentContract);
	mathint asElastic_ = totalTokenAmount(token); //casting from uint128
	require strategy_ == getStrategyTokenBalance(token);
	assert actual_ >= asElastic_, "system solvency is broken";
}

/*
Verify that the system balance afte flash loan does not decrese
*/
rule totalAssetsAfterFlashLoan(address token) {
	//link the strategy to the current token
	require harnessBorrower() == borrower;
	require harnessToken() == token;
	//assume solvency safe assumption as we know that solvency is kept before and after flash loan
	require tokenBalanceOf(token) == totalTokenAmount(token);
	uint256 _systemBalance = tokenBalanceOfUser(token, currentContract);
	env e;
	calldataarg args;
	flashLoan(e, args);
	uint256 systemBalance_ = tokenBalanceOfUser(token, currentContract);
	assert  systemBalance_ >= _systemBalance, "system lost assets due to flahs loan";
}

/* 
Additivity of share deposit. One can deposit in two steps or one step
*/
rule additivity(uint x, uint y, address token, address who) {
	env e;
	storage init = lastStorage;
	address from = e.msg.sender;
	require e.msg.value == 0;
	
	deposit(e, token, from, who, 0, x);
	deposit(e, token, from, who, 0, y);
	
	uint256 splitScenarioBalanceWho = balanceOf(token, who);
	uint256 splitScenarioBalanceSender = balanceOf(token, from);
		
	require x + y <= MAX_UINT256();
	uint256 sum = x + y;
	deposit(e, token, from, who, 0, sum) at init;
	
	uint256 sumScenarioBalanceWho = balanceOf(token, who);
	uint256 sumScenarioBalanceSender = balanceOf(token, from);
	
	assert sumScenarioBalanceWho == splitScenarioBalanceWho, "function is not additive for argument address";
	assert sumScenarioBalanceSender == splitScenarioBalanceSender, "function is not additive for sender";
}

/* valid decrease to balanceOf:
 * which operation may decrease the balance of a user
 * { v = toAmount(token, balanceOf[token][a]) }
 *			op
 *	{ v > toAmount(token, balanceOf[token][a]) ⇒
 * 										(op = withdraw() ⋁ op = transfer()) }
 */
rule validDecreaseToBalanceOf(address token, address a,
							  address from, address to,
 							  address other, method f) {

	uint256 amount;
	uint256 share;
 	require  from == harnessFrom();

	uint256 vBefore = balanceOf(token, a);
	callFunctionWithParams(token, from, to, amount, share, f);
	uint256 vAfter = balanceOf(token, a);
	assert (vBefore > vAfter => ( from == a && (
	 		f.selector == transfer(address, address, address, uint256).selector ||
			f.selector == withdraw(address, address, address, uint256, uint256).selector ||
			f.selector == transferMultiple(address, address, address[], uint256[]).selector)));
}

rule noChangeToOthersBalances(address token, address from, address to,
 							  address other, uint256 amount,
							  uint256 share, method f) {
	require from != other && to != other && other == harnessOther() &&
	from == harnessFrom();

	env e;

	uint256 _otherInternalBalance = balanceOf(token, other); // user's internal shares

	callFunctionWithParams(token, from, to, amount, share, f);

	uint256 otherInternalBalance_ = balanceOf(token, other);

	assert (_otherInternalBalance <= otherInternalBalance_ ),
								"operation changed some other user's balance";
}

/*
 * For every token and every user, the total assets within the bentobox and
 * outside the bentobox should be preserved. If other users transfer to a
 * user, their balance should only go up.
 *
 * { v = token.balanceOf(a) + toAmount(token, balanceOf[token][a]) }
 *			op (need to limit to specific arguments)
 * { v <= token.balanceOf(a) + toAmount(token, balanceOf[token][a]) + ε }
 */
rule preserveTotalAssetsOfUser(address token, address from, address to,
					    	   address user, uint256 amount, uint256 share,
							   method f) {
	env e;

	// verifying a simplified version
	require totalTokenAmount(token) == totalTokenShare(token);

	uint256 _userShares = balanceOf(token, user);

	// roundUp = true or false shouldn't matter as long as they are consistent
	mathint _userAssets = tokenBalanceOfUser(token, user) + toAmount(token, balanceOf(token, user), true); 

	require user != currentContract &&  user == from && user == harnessFrom() && user == to;
	//for transfermultiple we assume that all transfer are to the same user
	callFunctionWithParams(token, from, to, amount, share, f);

	// roundUp = true or false shouldn't matter as long as they are consistent
	mathint userAssets_ = tokenBalanceOfUser(token, user) + toAmount(token, balanceOf(token, user), true);

	uint256 userShares_ = balanceOf(token, user);
	
	// transferMultiple transfer from user to some arbitrary other user so we expect assets to be preserved
	require  f.selector != transferMultiple(address,address,address[],uint256[]).selector; 
	
	// flash loan can reduce asset of user due to fee, and strategy can also reduce user assets due to negative profit
	if (f.selector != 0xf1676d37 && // hascode of flashLoan 
		f.selector != setStrategy(address,address).selector &&
		f.selector != harvest(address,bool,uint256).selector)
	{
		assert (_userAssets <= userAssets_,
			"total user assets not preserved");
	}
	else  {
		// however on those functions, a user's share should not change
		assert (_userShares == userShares_,
			"total user assets not preserved");
	}
	
}

// Helper Functions

// easy to use dispatcher
function callFunctionWithParams(address token, address from, address to,
 								uint256 amount, uint256 share, method f) {
	env e;

	if (f.selector == deposit(address, address, address, uint256, uint256).selector) {
		deposit(e, token, from, to, amount, share);
	} else if (f.selector == withdraw(address, address, address, uint256, uint256).selector) {
		withdraw(e, token, from, to, amount, share); 
	} else if  (f.selector == transfer(address, address, address, uint256).selector) {
		transfer(e, token, from, to, share);
	} else if (f.selector == setStrategy(address, address).selector) {
		address newStra;
		setStrategy(e, token, newStra);
	} else if (f.selector == harvest(address, bool, uint256).selector) {
		bool balance;
		uint256 maxChangeAmount;
		harvest(e, token, balance, maxChangeAmount);
	} else {
		calldataarg args;
		f(e,args);
	}
}
