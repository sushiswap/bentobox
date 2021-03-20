/*
    This is a specification file for smart contract verification with the Certora prover.
    This file is run with scripts/_runRebase.sh
*/

/*
    Declaration of methods that are used in the rules.
    envfree indicate that the method is not dependent on the environment (msg.value, msg.sender).
    Methods that are not declared here are assumed to be dependent on env.
*/

methods {
    getElastic() returns (uint128) envfree;
    getBase() returns (uint128) envfree;

    toBase(uint256 elastic, bool roundUp) returns (uint256 base) envfree;
    toBaseFloor(uint256 elastic) returns (uint256 base) envfree;
    // toBaseCeiling(uint256 elastic) returns (uint256 base) envfree;

    toElastic(uint256 base, bool roundUp) returns (uint256 elastic) envfree;

    add(uint256 addAmount, bool roundUp) returns (uint256 base) envfree;
    addFloor(uint256 addAmount) returns (uint256 base) envfree;
    add(uint256 addAmount, uint256 addShare) envfree;

    sub(uint256 subAmount, bool roundUp) returns (uint256 elastic) envfree;
    sub(uint256 subAmount, uint256 subShare) envfree;

    addElastic(uint256 elastic) returns(uint256 newElastic) envfree;
    subElastic(uint256 elastic) returns(uint256 newElastic) envfree;
}

definition max_uint128() returns uint128 = 340282366920938463463374607431768211455;

/** x and y are almost equal; y may be _smaller or larger_ than x up to an amount of epsilon */
definition bounded_error_eq(uint x, uint y, uint epsilon) returns bool = x <= y + epsilon && x + epsilon >= y;

/** x and y are almost equal; y may be _smaller_ than x up to an amount of epsilon */
definition only_slightly_larger_than(uint x, uint y, uint epsilon) returns bool = y <= x && x <= y + epsilon;

/** x and y are almost equal; y may be _larger_ than x up to an amount of epsilon */
definition only_slightly_smaller_than(uint x, uint y, uint epsilon) returns bool = x <= y && y <= x + epsilon;


/**
  Part of the rule "Monotonicity" in GDoc.
 */
rule toBaseIsMonotone {
    bool roundUp;
    uint x;
    uint y;
    require x < y;
    uint xToBase = toBase(x, roundUp);
    uint yToBase = toBase(y, roundUp);
    assert xToBase <= yToBase; 
}

/**
   Part of the rule "Monotonicity" in GDoc.
 */
rule toElasticIsMonotone {
    bool roundUp;
    uint x;
    uint y;
    require x < y;
    uint xToElastic = toElastic(x, roundUp);
    uint yToElastic = toElastic(y, roundUp);
    assert xToElastic <= yToElastic; 
}

/**
   The conversions toElastic(..) and toBase(..) are inverse operations ... up 
    to an error.
    This covers the case where neither rebase.base nor rebase.elastic equal 0.

    The error introduced by toElastic(toBase(a)), where e = rebase.elastic and b = rebase.base is:
    "- ((ab) % e)/b - ((ab - (ab % e)) % b)/b"  (these divisions are over the rationals)
    The second quotient is always lower than 1.
    The first quotient is always lower than the ratio e/b.
    Overall, the error of the computation is always negative (i.e. the result is 
    lower or equal than the input a), and the absolute error is bounded by "e/b + 1".

    Note that this holds only for the case `roundUp = false`, however not much changes for the other 
    case.

    Contributes to proof of rule named "Identity" in GDoc.
 */ 
rule toElasticAndToBaseAreInverse1down {
    bool roundUp = false;
    uint128 base1 = getBase();
    uint128 elastic1 = getElastic();

    require base1 != 0 && elastic1 != 0;

    uint256 amount;

    uint256 amountToElastic = toElastic(amount, roundUp);
    uint256 amountToElasticToBase = toBase(amountToElastic, roundUp);


    uint256 error_margin1 = base1 / elastic1 + 1; 
    assert only_slightly_larger_than(amount, amountToElasticToBase, error_margin1);
}

/**
   In the `roundUp = true` case a slight variation of the specification is necessary:
    - the polarity of the error switches
    - the error can be slightly (exactly 1) larger

    (note: this means we could also merge the up and down rules, use bounded_error_eq and 
     the larger error...)
 */
rule toElasticAndToBaseAreInverse1up {
    bool roundUp = true;
    uint128 base1 = getBase();
    uint128 elastic1 = getElastic();

    require base1 != 0 && elastic1 != 0;

    uint256 amount;

    uint256 amountToElastic = toElastic(amount, roundUp);
    uint256 amountToElasticToBase = toBase(amountToElastic, roundUp);


    uint256 error_margin1 = base1 / elastic1 + 2; // "base1/elastic1 + 1":to
    assert only_slightly_smaller_than(amount, amountToElasticToBase, error_margin1);
}

/**
    The computation of the error for toBase(toElastic(a)) is analogous; the 
    error term can be obtained by switching variables b and e.
    Here, the error is bounded by "b/e + 1".
    
    Contributes to proof of rule named "Identity" in GDoc.
 */
rule toElasticAndToBaseAreInverse2down {
    bool roundUp = false;
    uint128 base1 = getBase();
    uint128 elastic1 = getElastic();

    require base1 != 0 && elastic1 != 0;

    uint256 amount;

    uint256 amountToBase = toBase(amount, roundUp);
    uint256 amountToBaseToElastic = toElastic(amountToBase, roundUp);

    uint256 error_margin2 = elastic1 / base1 + 1; 
    assert only_slightly_larger_than(amount, amountToBaseToElastic, error_margin2);
}

rule toElasticAndToBaseAreInverse2up {
    bool roundUp = true;
    uint128 base1 = getBase();
    uint128 elastic1 = getElastic();

    require base1 != 0 && elastic1 != 0;

    uint256 amount;

    uint256 amountToBase = toBase(amount, roundUp);
    uint256 amountToBaseToElastic = toElastic(amountToBase, roundUp);

    uint256 error_margin2 = elastic1 / base1 + 2; 
    assert only_slightly_smaller_than(amount, amountToBaseToElastic, error_margin2);
}

/*
 * The conversions toElastic(..) and toBase(..) are inverse operations ... up 
    to an error.
    This covers the case where rebase.base or rebase.elastic (or both) equal 0.
 */
rule toElasticAndToBaseAreInverse0ElasticEdgeCase {
    bool roundUp;
    uint128 base1 = getBase();
    uint128 elastic1 = getElastic();

    require elastic1 == 0;

    uint256 amount;

    uint256 amountToElastic = toElastic(amount, roundUp);
    uint256 amountToElasticToBase = toBase(amountToElastic, roundUp);

    uint256 amountToBase = toBase(amount, roundUp);
    uint256 amountToBaseToElastic = toElastic(amountToBase, roundUp);

    assert amountToElasticToBase == amount  || amountToElasticToBase == 0;
    assert amountToBaseToElastic == amount || amountToBaseToElastic == 0;
}

rule toElasticAndToBaseAreInverse0BaseEdgeCase {
    bool roundUp;
    uint128 base1 = getBase();
    uint128 elastic1 = getElastic();

    require base1 == 0;

    uint256 amount;

    uint256 amountToElastic = toElastic(amount, roundUp);
    uint256 amountToElasticToBase = toBase(amountToElastic, roundUp);

    uint256 amountToBase = toBase(amount, roundUp);
    uint256 amountToBaseToElastic = toElastic(amountToBase, roundUp);

    assert amountToElasticToBase == amount  ||  amountToElasticToBase == 0;
    assert amountToBaseToElastic == amount || amountToBaseToElastic == 0;
}