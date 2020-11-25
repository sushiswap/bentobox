// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;
import "./interfaces/IERC20.sol";
import "./BentoBox.sol";
import "./interfaces/ILendingPair.sol";
import "./interfaces/IOracle.sol";

contract BentoHelper {
    struct PairInfo {
        ILendingPair pair;
        IOracle oracle;
        BentoBox bentoBox;
        IERC20 tokenAsset;
        IERC20 tokenCollateral;

        uint256 latestExchangeRate;
        uint256 lastBlockAccrued;
        uint256 interestRate;
        uint256 totalCollateralShare;
        uint256 totalAssetShare;
        uint256 totalBorrowShare;

        uint256 totalAssetFraction;
        uint256 totalBorrowFraction;

        uint256 interestPerBlock;
        uint256 lastInterestBlock;

        uint256 feesPendingShare;

        uint256 userCollateralShare;
        uint256 userAssetFraction;
        uint256 userBorrowFraction;

        uint256 userAssetBalance;
        uint256 userCollateralShareBalance;
        uint256 userAssetAllowance;
        uint256 userCollateralShareAllowance;
    }

    function getPairs(address user, ILendingPair[] calldata pairs) public view returns (PairInfo[] memory info) {
        info = new PairInfo[](pairs.length);
        for(uint256 i = 0; i < pairs.length; i++) {
            ILendingPair pair = pairs[i];
            info[i].pair = pair;
            info[i].oracle = pair.oracle();
            info[i].bentoBox = pair.bentoBox();
            info[i].tokenAsset = pair.asset();
            info[i].tokenCollateral = pair.collateral();

            (, info[i].latestExchangeRate) = pair.peekExchangeRate();
            info[i].lastBlockAccrued = pair.lastBlockAccrued();
            info[i].totalCollateralShare = pair.totalCollateralShare();
            info[i].totalAssetShare = pair.totalAssetShare();
            info[i].totalBorrowShare = pair.totalBorrowShare();

            info[i].totalAssetFraction = pair.totalSupply();
            info[i].totalBorrowFraction = pair.totalBorrowFraction();

            info[i].interestPerBlock = pair.interestPerBlock();
            info[i].lastInterestBlock = pair.lastInterestBlock();

            info[i].feesPendingShare = pair.feesPendingShare();

            info[i].userCollateralShare = pair.userCollateralShare(user);
            info[i].userAssetFraction = pair.balanceOf(user);
            info[i].userBorrowFraction = pair.userBorrowFraction(user);

            info[i].userAssetBalance = info[i].tokenAsset.balanceOf(user);
            info[i].userCollateralShareBalance = info[i].tokenCollateral.balanceOf(user);
            info[i].userAssetAllowance = info[i].tokenAsset.allowance(user, address(info[i].bentoBox));
            info[i].userCollateralShareAllowance = info[i].tokenCollateral.allowance(user, address(info[i].bentoBox));
        }
    }
}
