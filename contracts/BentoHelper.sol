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
        uint256 totalCollateralAmount;
        uint256 totalAssetAmount;
        uint256 totalBorrowAmount;

        uint256 totalAssetFraction;
        uint256 totalBorrowFraction;

        uint256 interestPerBlock;

        uint256 feesPendingAmount;

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
            (info[i].interestPerBlock, info[i].lastBlockAccrued, info[i].feesPendingAmount) = pair.accrueInfo();
            info[i].totalCollateralAmount = pair.totalCollateralAmount();
            (info[i].totalAssetAmount, info[i].totalAssetFraction ) = pair.totalAsset();
            (info[i].totalBorrowAmount, info[i].totalBorrowFraction) = pair.totalBorrow();

            info[i].userCollateralAmount = pair.userCollateralAmount(user);
            info[i].userAssetFraction = pair.balanceOf(user);
            info[i].userAssetAmount = info[i].totalAssetFraction == 0 ? 0 :
                 info[i].userAssetFraction * info[i].totalAssetAmount / info[i].totalAssetFraction;
            info[i].userBorrowFraction = pair.userBorrowFraction(user);
            info[i].userBorrowAmount = info[i].totalBorrowFraction == 0 ? 0 :
                info[i].userBorrowFraction * info[i].totalBorrowAmount / info[i].totalBorrowFraction;

            info[i].userAssetBalance = info[i].tokenAsset.balanceOf(user);
            info[i].userCollateralBalance = info[i].tokenCollateral.balanceOf(user);
            info[i].userAssetAllowance = info[i].tokenAsset.allowance(user, address(bentoBox));
            info[i].userCollateralAllowance = info[i].tokenCollateral.allowance(user, address(bentoBox));
        }
    }
}
