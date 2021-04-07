pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@boringcrypto/boring-solidity/contracts/libraries/BoringRebase.sol";

contract RebaseWrapper {
    using BoringMath for uint256;
    using BoringMath128 for uint128;
	using RebaseLibrary for Rebase;

	Rebase public rebase;

    function getElastic() public view returns (uint128) {
        return rebase.elastic;
    }

    function getBase() public view returns (uint128) {
        return rebase.base;
    }

    function toBase(uint256 elastic, bool roundUp) public view returns (uint256 base) {
        base = rebase.toBase(elastic, roundUp);
    }

    /** Equivalent to toBase when roundUp parameter is "false", but a bit 
        easier on the smt solver. */
    function toBaseFloor(uint256 elastic) public view returns (uint256 base) {
        if (rebase.elastic == 0) {
            base = elastic;
        } else {
            base = elastic.mul(rebase.base) / rebase.elastic;
        }
    }

    function toElastic(uint256 base, bool roundUp) public view returns (uint256 elastic) {
        return rebase.toElastic(base, roundUp);
    }


    function add(uint256 addAmount, bool roundUp) public returns (uint256 base) {
        uint256 addAmountBase;
        (rebase, addAmountBase) = rebase.add(addAmount, roundUp);
        return addAmountBase;
    }
    /** Equivalent to add when roundUp parameter is "false", but a bit 
        easier on the smt solver. */
    function addFloor(uint256 elastic) public  returns (uint256 base) {
        base = toBaseFloor(elastic);
        rebase.elastic = rebase.elastic.add(elastic.to128());
        rebase.base = rebase.base.add(base.to128());
        return base;
    }

    function add(uint256 addAmount, uint256 addShares) public {
        rebase = rebase.add(addAmount, addShares);
    }

    function sub(uint256 subAmount, bool roundUp) public returns (uint256 elastic) {
        uint256 subAmountElastic;
        (rebase, subAmountElastic) = rebase.sub(subAmount, roundUp);
        return subAmountElastic;
    }

    function sub(uint256 subAmount, uint256 subShares) public {
        rebase = rebase.sub(subAmount, subShares);
    }

    function addElastic(uint256 elastic) public returns(uint256 newElastic) {
       return rebase.addElastic(elastic);
    }

    function subElastic(uint256 elastic) public returns(uint256 newElastic) {
       return rebase.subElastic(elastic);
    }

}