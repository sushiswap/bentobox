// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;
import "./interfaces/ILendingPair.sol";
import "./interfaces/IOracle.sol";

contract BentoHelper {
    struct PairInfo {
        ILendingPair pair;
        IOracle oracle;
        IBentoBox bentoBox;
        address masterContract;
        bool masterContractApproved;
        IERC20 tokenAsset;
        IERC20 tokenCollateral;

        uint256 latestExchangeRate;
        uint256 lastBlockAccrued;
        uint256 interestRate;
        uint256 totalCollateralShare;
        uint256 totalCollateralAmount;
        uint256 totalAssetShare;
        uint256 totalAssetAmount;
        uint256 totalBorrowShare;
        uint256 totalBorrowAmount;

        uint256 totalAssetFraction;
        uint256 totalBorrowFraction;

        uint256 interestPerBlock;

        uint256 feesPendingShare;

        uint256 userCollateralShare;
        uint256 userCollateralAmount;
        uint256 userAssetFraction;
        uint256 userAssetAmount;
        uint256 userBorrowFraction;
        uint256 userBorrowAmount;

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
            IBentoBox bentoBox = pair.bentoBox();
            info[i].bentoBox = bentoBox;
            info[i].masterContract = address(pair.masterContract());
            info[i].masterContractApproved = bentoBox.masterContractApproved(info[i].masterContract, user);
            IERC20 asset = pair.asset();
            info[i].tokenAsset = asset;
            IERC20 collateral = pair.collateral();
            info[i].tokenCollateral = collateral;

            (, info[i].latestExchangeRate) = pair.peekExchangeRate();
            info[i].lastBlockAccrued = pair.lastBlockAccrued();
            info[i].totalCollateralShare = pair.totalCollateralShare();
            info[i].totalCollateralAmount = bentoBox.toAmount(collateral, info[i].totalCollateralShare);
            info[i].totalAssetShare = pair.totalAssetShare();
            info[i].totalAssetAmount = bentoBox.toAmount(asset, info[i].totalAssetShare);
            info[i].totalBorrowShare = pair.totalBorrowShare();
            info[i].totalBorrowAmount = bentoBox.toAmount(asset, info[i].totalBorrowShare);

            info[i].totalAssetFraction = pair.totalSupply();
            info[i].totalBorrowFraction = pair.totalBorrowFraction();

            info[i].interestPerBlock = pair.interestPerBlock();

            info[i].feesPendingShare = pair.feesPendingShare();

            info[i].userCollateralShare = pair.userCollateralShare(user);
            info[i].userCollateralAmount = bentoBox.toAmount(collateral, info[i].userCollateralShare);
            info[i].userAssetFraction = pair.balanceOf(user);
            info[i].userAssetAmount = info[i].totalAssetFraction == 0 ? 0 :
                bentoBox.toAmount(asset, info[i].userAssetFraction * info[i].totalAssetShare / info[i].totalAssetFraction);
            info[i].userBorrowFraction = pair.userBorrowFraction(user);
            info[i].userBorrowAmount = info[i].totalBorrowFraction == 0 ? 0 :
                bentoBox.toAmount(asset, info[i].userBorrowFraction * info[i].totalBorrowShare / info[i].totalBorrowFraction);

            info[i].userAssetBalance = info[i].tokenAsset.balanceOf(user);
            info[i].userCollateralBalance = info[i].tokenCollateral.balanceOf(user);
            info[i].userAssetAllowance = info[i].tokenAsset.allowance(user, address(bentoBox));
            info[i].userCollateralAllowance = info[i].tokenCollateral.allowance(user, address(bentoBox));
        }
    }
}
