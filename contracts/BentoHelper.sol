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
        uint256 totalCollateral;
        uint256 totalAsset;
        uint256 totalBorrow;

        uint256 totalAssetShare;
        uint256 totalBorrowShare;

        uint256 interestPerBlock;
        uint256 lastInterestBlock;

        uint256 feesPending;

        uint256 userCollateral;
        uint256 userAssetShare;
        uint256 userBorrowShare;

        uint256 userAssetBalance;
        uint256 userCollateralBalance;
        uint256 userAssetAllowance;
        uint256 userCollateralAllowance;
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
            info[i].totalCollateral = pair.totalCollateral();
            info[i].totalAsset = pair.totalAsset();
            info[i].totalBorrow = pair.totalBorrow();

            info[i].totalAssetShare = pair.totalSupply();
            info[i].totalBorrowShare = pair.totalBorrowShare();

            info[i].interestPerBlock = pair.interestPerBlock();
            info[i].lastInterestBlock = pair.lastInterestBlock();

            info[i].feesPending = pair.feesPending();

            info[i].userCollateral = pair.userCollateral(user);
            info[i].userAssetShare = pair.balanceOf(user);
            info[i].userBorrowShare = pair.userBorrowShare(user);

            info[i].userAssetBalance = info[i].tokenAsset.balanceOf(user);
            info[i].userCollateralBalance = info[i].tokenCollateral.balanceOf(user);
            info[i].userAssetAllowance = info[i].tokenAsset.allowance(user, address(info[i].bentoBox));
            info[i].userCollateralAllowance = info[i].tokenCollateral.allowance(user, address(info[i].bentoBox));
        }
    }
}
