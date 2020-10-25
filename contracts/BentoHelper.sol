// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;
import "./interfaces/IERC20.sol";
import "./interfaces/IPair.sol";
import "./interfaces/IOracle.sol";

contract BentoHelper {
    struct PairInfo {
        IPair pair;
        IOracle oracle;
        IVault vault;
        IERC20 tokenAsset;
        IERC20 tokenCollateral;

        uint256 latestExchangeRate;
        uint256 lastBlockAccrued;
        uint256 interestRate;
        uint256 totalCollateral;
        uint256 totalAsset;
        uint256 totalBorrow;

        uint256 totalCollateralShare;
        uint256 totalAssetShare;
        uint256 totalBorrowShare;

        uint256 interestPerBlock;
        uint256 lastInterestBlock;

        uint256 colRate;
        uint256 openColRate;
        uint256 liqMultiplier;
        uint256 feesPending;

        uint256 userCollateralShare;
        uint256 userAssetShare;
        uint256 userBorrowShare;

        uint256 userAssetBalance;
        uint256 userCollateralBalance;
        uint256 userAssetAllowance;
        uint256 userCollateralAllowance;
    }

    function getPairs(address user, IPair[] calldata pairs) public view returns (PairInfo[] memory info) {
        info = new PairInfo[](pairs.length);
        for(uint256 i = 0; i < pairs.length; i++) {
            IPair pair = pairs[i];
            info[i].pair = pair;
            info[i].oracle = pair.oracle();
            info[i].vault = pair.vault();
            info[i].tokenAsset = pair.tokenAsset();
            info[i].tokenCollateral = pair.tokenCollateral();

            info[i].latestExchangeRate = info[i].oracle.peek(address(pair));
            info[i].lastBlockAccrued = pair.lastBlockAccrued();
            info[i].totalCollateral = pair.totalCollateral();
            info[i].totalAsset = pair.totalAsset();
            info[i].totalBorrow = pair.totalBorrow();

            info[i].totalCollateralShare = pair.totalCollateralShare();
            info[i].totalAssetShare = pair.totalSupply();
            info[i].totalBorrowShare = pair.totalBorrowShare();

            info[i].interestPerBlock = pair.interestPerBlock();
            info[i].lastInterestBlock = pair.lastInterestBlock();

            info[i].colRate = pair.colRate();
            info[i].openColRate = pair.openColRate();
            info[i].liqMultiplier = pair.liqMultiplier();
            info[i].feesPending = pair.feesPending();

            info[i].userCollateralShare = pair.userCollateralShare(user);
            info[i].userAssetShare = pair.balanceOf(user);
            info[i].userBorrowShare = pair.userBorrowShare(user);

            info[i].userAssetBalance = info[i].tokenAsset.balanceOf(user);
            info[i].userCollateralBalance = info[i].tokenCollateral.balanceOf(user);
            info[i].userAssetAllowance = info[i].tokenAsset.allowance(user, address(info[i].vault));
            info[i].userCollateralAllowance = info[i].tokenCollateral.allowance(user, address(info[i].vault));

        }
    }
}