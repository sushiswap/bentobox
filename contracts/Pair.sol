// SPDX-License-Identifier: UNLICENSED
// Copyright 2020 BoringCrypto - All rights reserved

// WARNING!!! DO NOT USE!!! NOT YET TESTED + NOT YET SECURITY CONSIDERED + DEF. NOT YET AUDITED!!!
// FOR CONCEPT TESTING ONLY!

// solium-disable security/no-low-level-calls

pragma solidity ^0.6.12;
import "./libraries/BoringMath.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/IVault.sol";
import "./ERC20.sol";

interface IDelegateSwapper {
    // Withdraws amountFrom 'from tokens' from the vault, turns it into at least amountToMin 'to tokens' and transfers those into the vault.
    // Returns amount of tokens added to the vault.
    function swap(address swapper, IERC20 from, IERC20 to, uint256 amountFrom, uint256 amountToMin) external returns (uint256);
}

interface ISwapper {
    function swap(IERC20 from, IERC20 to, uint256 amountFrom, uint256 amountTo, address profitTo) external;
}

// Special thanks to:
// https://twitter.com/burger_crypto - for the idea of trying to let the LPs benefit from liquidations
// TODO: check all reentrancy paths
// TODO: what to do when the entire pool is underwater?
// TODO: ensure BoringMath is always used
// We do allow supplying assets and borrowing, but the asset does NOT provide collateral as it's just silly and no UI should allow this

contract Pair is ERC20 {
    using BoringMath for uint256;

    // Keep at the top in this order for delegate calls to be able to access them
    IVault public vault;
    IERC20 public tokenCollateral;
    IERC20 public tokenAsset;

    mapping(address => uint256) public userCollateralShare;
    // userAssetShare = balanceOf - the asset share is the token.
    mapping(address => uint256) public userBorrowShare;

    IOracle public oracle;

    uint256 public exchangeRate;

    uint256 public lastBlockAccrued;

    uint256 public totalCollateral;
    uint256 public totalAsset; // Includes totalBorrow
    uint256 public totalBorrow; // Total units of asset borrowed

    uint256 public totalCollateralShare; // Total amount of shares in the collateral pool
    // totalAssetShare = totalSupply - Total amount of shares in the asset pool
    uint256 public totalBorrowShare;

    uint256 public interestPerBlock;
    uint256 public lastInterestBlock;

    uint256 public colRate;     // Collateral rate used to calculate if the protocol can liquidate
    uint256 public openColRate; // Collateral rate used to calculate if ANYONE can liquidate
    uint256 public liqMultiplier;
    uint256 public feesPending;

    string public constant symbol = "BENTO LP";
    string public constant name = "Bento LP";
    uint8 public decimals;

    event NewExchangeRate(uint256 rate);
    event AddCollateral(address indexed user, uint256 amount, uint256 share);
    event AddAsset(address indexed user, uint256 amount, uint256 share);
    event AddBorrow(address indexed user, uint256 amount, uint256 share);
    event RemoveCollateral(address indexed user, uint256 amount, uint256 share);
    event RemoveAsset(address indexed user, uint256 amount, uint256 share);
    event RemoveBorrow(address indexed user, uint256 amount, uint256 share);

    function init(IVault vault_, IERC20 collateral_address, IERC20 asset_address, IOracle oracle_address, bytes calldata oracleData) public {
        require(address(vault) == address(0), 'BentoBox: already initialized');
        vault = vault_;
        tokenCollateral = collateral_address;
        tokenAsset = asset_address;
        oracle = oracle_address;
        (bool success,) = address(oracle).call(oracleData);
        require(success, 'BentoBox: oracle init failed.');
        lastInterestBlock = block.number;

        interestPerBlock = 4566210045;  // 1% APR, with 1e18 being 100%

        colRate = 75000; // 75%
        openColRate = 77000; // 77%
        liqMultiplier = 112000; // 12% more tokenCollateral

        decimals = asset_address.decimals();
    }

    function accrue() public {
        uint256 blocks = block.number - lastBlockAccrued;
        if (blocks == 0) {return;}
        // The first time lastBlockAccrued will be 0, but also borrowed will be 0, so all good
        uint256 extraAmount = totalBorrow.mul(interestPerBlock).mul(block.number - lastBlockAccrued) / 1e18;
        uint256 feeAmount = extraAmount / 10; // 10% of interest paid goes to fee
        totalAsset = totalAsset.add(extraAmount.sub(feeAmount));
        totalBorrow = totalBorrow.add(extraAmount);
        feesPending = feesPending.add(feeAmount);
        lastBlockAccrued = block.number;
    }

    function withdrawFees() public {
        accrue();
        uint256 fees = feesPending.sub(1);
        uint256 devFee = fees / 10;
        feesPending = 1; // Don't set it to 0 as that would increase the gas cost for the next accrue called by a user.
        vault.transfer(tokenAsset, vault.feeTo(), fees.sub(devFee));
        vault.transfer(tokenAsset, vault.dev(), devFee);
    }

    function isSolvent(address user, bool open) public view returns (bool) {
        // accrue must have already been called!
        if (userBorrowShare[user] == 0) return true;
        if (totalCollateralShare == 0) return false;

        uint256 collateral = userCollateralShare[user].mul(totalCollateral) / totalCollateralShare;
        uint256 borrow = userBorrowShare[user].mul(totalBorrow) / totalBorrowShare;

        return collateral.mul(open ? openColRate : colRate) / 1e5 >= borrow.mul(exchangeRate) / 1e18;
    }

    // Gets the exchange rate. How much collateral to buy 1e18 asset.
    function updateExchangeRate() public returns (uint256) {
        (bool success, uint256 rate) = oracle.get(address(this));

        // TODO: How to deal with unsuccessful fetch
        if (success) {
            exchangeRate = rate;
            emit NewExchangeRate(rate);
        }
        return exchangeRate;
    }

    function updateInterestRate() public {
        if (totalAsset == 0) {return;}
        uint256 minimumInterest = 1141552511;    // 0.25% APR
        uint256 maximumInterest = 4566210045000; // 1000% APR
        uint256 targetMinUse = 700000000000000000; // 70%
        uint256 targetMaxUse = 800000000000000000; // 80%

        uint256 blocks = block.number - lastInterestBlock;
        if (blocks == 0) {return;}
        uint256 utilization = totalBorrow.mul(1e18) / totalAsset;
        uint256 newInterestPerBlock;
        if (utilization < targetMinUse) {
            uint256 underFactor = targetMinUse.sub(utilization).mul(1e18) / targetMinUse;
            uint256 scale = uint256(2000e36).add(underFactor.mul(underFactor).mul(blocks));
            newInterestPerBlock = interestPerBlock.mul(2000e36) / scale;
            if (newInterestPerBlock < minimumInterest) {
                newInterestPerBlock = minimumInterest;
            }
        } else if (utilization > targetMaxUse) {
            uint256 overFactor = utilization.sub(targetMaxUse).mul(1e18) / uint256(1e18).sub(targetMaxUse);
            uint256 scale = uint256(2000e36).add(overFactor.mul(overFactor).mul(blocks));

            newInterestPerBlock = interestPerBlock.mul(scale) / 2000e36;
            if (newInterestPerBlock > maximumInterest) {
                newInterestPerBlock = maximumInterest;
            }
        } else {return;}

        interestPerBlock = newInterestPerBlock;
        lastInterestBlock = block.number;
    }

    function _addCollateral(address user, uint256 amount) private {
        uint256 newShare = totalCollateralShare == 0 ? amount : amount.mul(totalCollateralShare) / totalCollateral;
        userCollateralShare[user] = userCollateralShare[user].add(newShare);
        totalCollateralShare = totalCollateralShare.add(newShare);
        totalCollateral = totalCollateral.add(amount);
        emit AddCollateral(msg.sender, amount, newShare);
    }

    function _addAsset(address user, uint256 amount) private {
        uint256 newShare = totalSupply == 0 ? amount : amount.mul(totalSupply) / totalAsset;
        balanceOf[user] = balanceOf[user].add(newShare);
        totalSupply = totalSupply.add(newShare);
        totalAsset = totalAsset.add(amount);
        emit AddAsset(msg.sender, amount, newShare);
    }

    function _addBorrow(address user, uint256 amount) private {
        uint256 newShare = totalBorrowShare == 0 ? amount : amount.mul(totalBorrowShare) / totalBorrow;
        userBorrowShare[user] = userBorrowShare[user].add(newShare);
        totalBorrowShare = totalBorrowShare.add(newShare);
        totalBorrow = totalBorrow.add(amount);
        emit AddBorrow(msg.sender, amount, newShare);
    }

    function _removeCollateralShare(address user, uint256 share) private returns (uint256) {
        userCollateralShare[user] = userCollateralShare[user].sub(share);
        uint256 amount = share.mul(totalCollateral) / totalCollateralShare;
        totalCollateralShare = totalCollateralShare.sub(share);
        totalCollateral = totalCollateral.sub(amount);
        emit RemoveCollateral(msg.sender, amount, share);
        return amount;
    }

    function _removeAssetShare(address user, uint256 share) private returns (uint256) {
        balanceOf[user] = balanceOf[user].sub(share);
        uint256 amount = share.mul(totalAsset) / totalSupply;
        totalSupply = totalSupply.sub(share);
        totalAsset = totalAsset.sub(amount);
        emit RemoveAsset(msg.sender, amount, share);
        return amount;
    }

    function _removeBorrowShare(address user, uint256 share) private returns (uint256) {
        userBorrowShare[user] = userBorrowShare[user].sub(share);
        uint256 amount = share.mul(totalBorrow) / totalBorrowShare;
        totalBorrowShare = totalBorrowShare.sub(share);
        totalBorrow = totalBorrow.sub(amount);
        emit RemoveBorrow(msg.sender, amount, share);
        return amount;
    }

    function addCollateral(uint256 amount) public {
        _addCollateral(msg.sender, amount);
        vault.transferFrom(tokenCollateral, msg.sender, amount);
    }

    function addAsset(uint256 amount) public {
        accrue();
        updateInterestRate();
        _addAsset(msg.sender, amount);
        vault.transferFrom(tokenAsset, msg.sender, amount);
    }

    function removeCollateral(uint256 share, address to) public {
        accrue();
        uint256 amount = _removeCollateralShare(msg.sender, share);
        require(isSolvent(msg.sender, false), 'BentoBox: user insolvent');
        vault.transfer(tokenCollateral, to, amount);
    }

    function removeAsset(uint256 share, address to) public {
        accrue();
        updateInterestRate();
        uint256 amount = _removeAssetShare(msg.sender, share);
        vault.transfer(tokenAsset, to, amount);
    }

    function borrow(uint256 amount, address to) public {
        require(amount <= totalAsset.sub(totalBorrow), 'BentoBox: not enough liquidity');
        accrue();
        updateInterestRate();
        _addBorrow(msg.sender, amount);
        require(isSolvent(msg.sender, false), 'BentoBox: user insolvent');
        vault.transfer(tokenAsset, to, amount);
    }

    function repay(uint256 share) public {
        accrue();
        updateInterestRate();
        uint256 amount = _removeBorrowShare(msg.sender, share);
        vault.transferFrom(tokenAsset, msg.sender, amount);
    }

    function short(address swapper, uint256 amountAsset, uint256 minAmountCollateral) public {
        require(amountAsset <= totalAsset.sub(totalBorrow), 'BentoBox: not enough liquidity');

        require(vault.swappers(swapper), 'BentoBox: Invalid swapper');
        accrue();
        updateInterestRate();
        _addBorrow(msg.sender, amountAsset);

        (bool success, bytes memory result) = swapper.delegatecall(
            abi.encodeWithSignature("swap(address,address,address,uint256,uint256)", swapper, tokenAsset, tokenCollateral, amountAsset, minAmountCollateral));
        require(success, 'BentoBox: Swap failed');
        uint256 amountCollateral = abi.decode(result, (uint256));
        _addCollateral(msg.sender, amountCollateral);

        require(isSolvent(msg.sender, false), 'BentoBox: user insolvent');
    }

    function unwind(address swapper, uint256 borrowShare, uint256 maxAmountCollateral) public {
        require(vault.swappers(swapper), 'BentoBox: Invalid swapper');
        accrue();
        updateInterestRate();

        uint256 borrowAmount = _removeBorrowShare(msg.sender, borrowShare);

        (bool success, bytes memory result) = swapper.delegatecall(
            abi.encodeWithSignature("swapExact(address,address,address,uint256,uint256)", swapper, tokenCollateral, tokenAsset, maxAmountCollateral, borrowAmount));
        require(success, 'BentoBox: Swap failed');
        _removeCollateralShare(msg.sender, abi.decode(result, (uint256)).mul(totalCollateralShare) / totalCollateral);

        require(isSolvent(msg.sender, false), 'BentoBox: user insolvent');
    }

    function liquidate(address[] calldata users, uint256[] calldata borrowShares, address to, address swapper, bool open) public {
        accrue();
        updateExchangeRate();
        updateInterestRate();

        uint256 allCollateralAmount;
        uint256 allCollateralShare;
        uint256 allBorrowAmount;
        uint256 allBorrowShare;
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            if (!isSolvent(user, open)) {
                uint256 borrowShare = borrowShares[i];
                uint256 borrowAmount = borrowShare.mul(totalBorrow) / totalBorrowShare;
                uint256 collateralAmount = borrowAmount.mul(1e13).mul(liqMultiplier) / exchangeRate;
                uint256 collateralShare = collateralAmount.mul(totalCollateralShare) / totalCollateral;

                userCollateralShare[user] = userCollateralShare[user].sub(collateralShare);
                userBorrowShare[user] = userBorrowShare[user].sub(borrowShare);
                emit RemoveCollateral(user, collateralAmount, collateralShare);
                emit RemoveBorrow(user, borrowAmount, borrowShare);

                // Keep totals
                allCollateralAmount = allCollateralAmount.add(collateralAmount);
                allCollateralShare = allCollateralShare.add(collateralShare);
                allBorrowAmount = allBorrowAmount.add(borrowAmount);
                allBorrowShare = allBorrowShare.add(borrowShare);
            }
        }
        require(allBorrowAmount != 0, 'BentoBox: all users are solvent');
        totalBorrow = totalBorrow.sub(allBorrowAmount);
        totalBorrowShare = totalBorrowShare.sub(allBorrowShare);
        totalCollateral = totalCollateral.sub(allCollateralAmount);
        totalCollateralShare = totalCollateralShare.add(allCollateralShare);

        if (!open) {
            // Closed liquidation using a pre-approved swapper for the benefit of the LPs
            require(vault.swappers(swapper), 'BentoBox: Invalid swapper');

            (bool success, bytes memory result) = swapper.delegatecall(
                abi.encodeWithSignature("swap(address,address,address,uint256,uint256)", swapper, tokenCollateral, tokenAsset, allCollateralAmount, allBorrowAmount));
            require(success, 'BentoBox: Swap failed');
            uint256 extraAsset = abi.decode(result, (uint256)).sub(allBorrowAmount);

            // The extra asset gets added to the pool
            uint256 feeAmount = extraAsset / 10; // 10% of profit goes to fee
            feesPending = feesPending.add(feeAmount);

            totalAsset = totalAsset.add(extraAsset.sub(feeAmount));
            emit AddAsset(address(0), extraAsset, 0);
        } else if (swapper == address(0)) {
            vault.transferFrom(tokenAsset, to, allBorrowAmount);
            vault.transfer(tokenCollateral, to, allCollateralAmount);
        } else {
            // Open (flash) liquidation: get proceeds first and provide the borrow after
            vault.transfer(tokenCollateral, swapper, allCollateralAmount);
            ISwapper(swapper).swap(tokenCollateral, tokenAsset, allCollateralAmount, allBorrowAmount, to);
            vault.transferFrom(tokenAsset, swapper, allBorrowAmount);
        }
    }
}