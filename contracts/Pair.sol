// SPDX-License-Identifier: UNLICENSED
// Copyright 2020 BoringCrypto - All rights reserved

// WARNING!!! DO NOT USE!!! NOT YET TESTED + NOT YET SECURITY CONSIDERED + DEF. NOT YET AUDITED!!!
// FOR CONCEPT TESTING ONLY!

// solium-disable security/no-low-level-calls

pragma solidity ^0.6.12;
import "./libraries/BoringMath.sol";
import "./interfaces/IOracle.sol";
import "./Vault.sol";

interface IDelegateSwapper {
    // Withdraws amountFrom 'from tokens' from the vault, turns it into at least amountToMin 'to tokens' and transfers those into the vault.
    // Returns amount of tokens added to the vault.
    function swap(address swapper, address from, address to, uint256 amountFrom, uint256 amountToMin) external returns (uint256);
}

interface ISwapper {
    function swap(address from, address to, uint256 amountFrom, uint256 amountTo, address profitTo) external;
}

interface IERC20 {
    function decimals() external returns (uint8);
}

// Special thanks to:
// https://twitter.com/burger_crypto - for the idea of trying to let the LPs benefit from liquidations
// TODO: check all reentrancy paths
// TODO: what to do when the entire pool is underwater?
// TODO: ensure BoringMath is always used
// We do allow supplying assets and borrowing, but the asset does NOT provide collateral as it's just silly and no UI should allow this

contract ERC20 {
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping (address => uint256)) allowance;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    function transfer(address to, uint256 amount) public returns (bool success) {
        if (balanceOf[msg.sender] >= amount && amount > 0 && balanceOf[to] + amount > balanceOf[to]) {
            balanceOf[msg.sender] -= amount;
            balanceOf[to] += amount;
            emit Transfer(msg.sender, to, amount);
            return true;
        } else {
            return false;
        }
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool success) {
        if (balanceOf[from] >= amount && allowance[from][msg.sender] >= amount && amount > 0 && balanceOf[to] + amount > balanceOf[to]) {
            balanceOf[from] -= amount;
            allowance[from][msg.sender] -= amount;
            balanceOf[to] += amount;
            emit Transfer(from, to, amount);
            return true;
        } else {
            return false;
        }
    }

    function approve(address spender, uint256 amount) public returns (bool success) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
}

contract Pair is ERC20 {
    using BoringMath for uint256;

    // Keep at the top in this order for delegate calls to be able to access them
    Vault public vault;
    address public tokenCollateral;
    address public tokenAsset;

    mapping(address => uint256) public userCollateralShare;
    // useAssetShare = balanceOf - the asset share is the token.
    mapping(address => uint256) public userBorrowShare;

    IOracle public oracle;

    uint256 exchangeRate;

    uint256 public lastBlockAccrued;

    uint256 public totalCollateral;
    uint256 public totalAsset; // Includes totalBorrow
    uint256 public totalBorrow; // Total units of asset borrowed

    uint256 public totalCollateralShare; // Total amount of shares in the collateral pool
    // totalAssetShare = totalSupply - Total amount of shares in the asset pool
    uint256 public totalBorrowShare;

    uint256 public interestPerBlock;
    uint256 public lastInterestBlock; // Last block when the interest rate was updated

    uint256 public colRate;     // Collateral rate used to calculate if the protocol can liquidate
    uint256 public openColRate; // Collateral rate used to calculate if ANYONE can liquidate
    uint256 public liqMultiplier;
    uint256 public feesPending;

    string public constant symbol = "BENTO LP";
    string public constant name = "Bento LP";
    uint8 public decimals;

    event NewExchangeRate(uint256 rate);
    event NewInterestRate(uint256 rate);
    event AddCollateral(address indexed user, uint256 amount, uint256 share);
    event AddAsset(address indexed user, uint256 amount, uint256 share);
    event AddBorrow(address indexed user, uint256 amount, uint256 share);
    event RemoveCollateral(address indexed user, uint256 amount, uint256 share);
    event RemoveAsset(address indexed user, uint256 amount, uint256 share);
    event RemoveBorrow(address indexed user, uint256 amount, uint256 share);

    // Servers as the constructor, as clones can't have a regular constructor
    function init(Vault vault_, address collateral_address, address asset_address, IOracle oracle_address) public {
        vault = vault_;
        tokenCollateral = collateral_address;
        tokenAsset = asset_address;
        oracle = oracle_address;
        lastInterestBlock = block.number;

        interestPerBlock = 4566210045;  // 1% APR, with 1e18 being 100%

        colRate = 75000; // 75%
        openColRate = 77000; // 77%
        liqMultiplier = 112000; // 12% more tokenA

        decimals = IERC20(asset_address).decimals();
    }

    // Accrues the interest on the borrowed tokens and handles the accumulation of fees
    function accrue() public {
        // Number of blocks since accrue was called
        uint256 blocks = block.number - lastBlockAccrued;
        if (blocks == 0) {return;}
        // The first time lastBlockAccrued will be 0, but also borrowed will be 0, so all good
        uint256 extraAmount = totalBorrow.mul(interestPerBlock).mul(block.number - lastBlockAccrued).div(1e18);
        uint256 feeAmount = extraAmount.div(10); // 10% of interest paid goes to fee
        totalAsset = totalAsset.add(extraAmount.sub(feeAmount));
        totalBorrow = totalBorrow.add(extraAmount);
        feesPending = feesPending.add(feeAmount);
        lastBlockAccrued = block.number;
    }

    // Withdraws the fees accumulated
    function withdrawFees() public {
        accrue();
        uint256 fees = feesPending.sub(1);
        uint256 devFee = fees.div(10); // 10% devfee
        feesPending = 1; // Don't set it to 0 as that would increase the gas cost for the next accrue called by a user.
        vault.transfer(tokenAsset, vault.feeTo(), fees.sub(devFee));
        vault.transfer(tokenAsset, vault.dev(), devFee);
    }

    // Checks if the user is solvent.
    // Has an option to check if the user is solvent in an open/closed liquidation case.
    function isSolvent(address user, bool open) public view returns (bool) {
        // accrue must have already been called!
        if (userBorrowShare[user] == 0) return true;
        if (totalCollateralShare == 0) return false;

        uint256 collateral = userCollateralShare[user].mul(totalCollateral).div(totalCollateralShare);
        uint256 borrow = userBorrowShare[user].mul(totalBorrow).div(totalBorrowShare);

        return collateral.mul(open ? openColRate : colRate).div(1e5) >= borrow.mul(exchangeRate).div(1e18);
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
        uint256 minimumInterest = 1141552511;    // 0.25% APR
        uint256 maximumInterest = 4566210045000; // 1000% APR
        uint256 targetMinUse = 700000000000000000; // 70%
        uint256 targetMaxUse = 800000000000000000; // 80%

        // Number of blocks since accrue was called
        uint256 blocks = block.number - lastInterestBlock;
        if (blocks == 0) {return;}

        uint256 utilization = totalBorrow.mul(1e18).div(totalAsset);
        uint256 newInterestPerBlock;
        if (utilization < targetMinUse) {
            uint256 underFactor = targetMinUse.sub(utilization).mul(1e18).div(targetMinUse);
            uint256 scale = uint256(2000e36).add(underFactor.mul(underFactor).mul(blocks));
            
            newInterestPerBlock = interestPerBlock.mul(2000e36).div(scale);
            if (newInterestPerBlock < minimumInterest) {
                newInterestPerBlock = minimumInterest;
            }
        } else if (utilization > targetMaxUse) {
            uint256 overFactor = utilization.sub(targetMaxUse).mul(1e18).div(uint256(1e18).sub(targetMaxUse));
            uint256 scale = uint256(2000e36).add(overFactor.mul(overFactor).mul(blocks));

            newInterestPerBlock = interestPerBlock.mul(scale).div(2000e36);
            if (newInterestPerBlock > maximumInterest) {
                newInterestPerBlock = maximumInterest;
            }
        } else {return;}

        interestPerBlock = newInterestPerBlock;
        lastInterestBlock = block.number;
        emit NewInterestRate(newInterestPerBlock);
    }

    // Handles internal variable updates when collateral is deposited
    function _addCollateral(address user, uint256 amount) private {
        // Calculates what share of the pool the user gets for the amount deposited
        uint256 newShare = totalCollateralShare == 0 ? amount : amount.mul(totalCollateralShare).div(totalCollateral);
        // Adds this share to user
        userCollateralShare[user] = userCollateralShare[user].add(newShare);
        // Adds this share to the total of collateral shares
        totalCollateralShare = totalCollateralShare.add(newShare);
        // Adds the amount deposited to the total of collateral
        totalCollateral = totalCollateral.add(amount);
        emit AddCollateral(msg.sender, amount, newShare);
    }

    // Handles internal variable updates when supply (the borrowable token) is deposited
    function _addAsset(address user, uint256 amount) private {
        // Calculates what share of the pool the user gets for the amount deposited
        uint256 newShare = totalSupply == 0 ? amount : amount.mul(totalSupply).div(totalAsset);
        // Adds this share to user
        balanceOf[user] = balanceOf[user].add(newShare);
        // Adds this share to the total of supply shares
        totalSupply = totalSupply.add(newShare);
        // Adds the amount deposited to the total of supply
        totalAsset = totalAsset.add(amount);
        emit AddAsset(msg.sender, amount, newShare);
    }

    // Handles internal variable updates when supply (the borrowable token) is borrowed
    function _addBorrow(address user, uint256 amount) private {
        // Calculates what share of the borrowed funds the user gets for the amount borrowed
        uint256 newShare = totalBorrowShare == 0 ? amount : amount.mul(totalBorrowShare).div(totalBorrow);
        // Adds this share to the user
        userBorrowShare[user] = userBorrowShare[user].add(newShare);
        // Adds amount borrowed to the total amount borrowed
        totalBorrowShare = totalBorrowShare.add(newShare);
        // Adds amount borrowed to the total amount borrowed
        totalBorrow = totalBorrow.add(amount);
        emit AddBorrow(msg.sender, amount, newShare);
    }

    // Handles internal variable updates when collateral is withdrawn and returns the amount of collateral withdrawn
    function _removeCollateralShare(address user, uint256 share) private returns (uint256) {
        // Subtracts the share from user
        userCollateralShare[user] = userCollateralShare[user].sub(share);
        // Calculates the amount of tokens to withdraw
        uint256 amount = share.mul(totalCollateral).div(totalCollateralShare);
        // Subtracts the share from the total of collateral shares
        totalCollateralShare = totalCollateralShare.sub(share);
        // Subtracts the calculated amount from the total of collateral
        totalCollateral = totalCollateral.sub(amount);
        emit RemoveCollateral(msg.sender, amount, share);
        return amount;
    }

    // Handles internal variable updates when supply is withdrawn and returns the amount of supply withdrawn
    function _removeAssetShare(address user, uint256 share) private returns (uint256) {
        // Subtracts the share from user
        balanceOf[user] = balanceOf[user].sub(share);
        // Calculates the amount of tokens to withdraw
        uint256 amount = share.mul(totalAsset).div(totalSupply);
        // Subtracts the calculated amount from the total of supply
        totalSupply = totalSupply.sub(share);
        // Subtracts the share from the total of supply shares
        totalAsset = totalAsset.sub(amount);
        emit RemoveAsset(msg.sender, amount, share);
        return amount;
    }

    // Handles internal variable updates when supply is repaid
    function _removeBorrowShare(address user, uint256 share) private returns (uint256) {
        // Subtracts the share from user
        userBorrowShare[user] = userBorrowShare[user].sub(share);
        // Calculates the amount of tokens to repay
        uint256 amount = share.mul(totalBorrow).div(totalBorrowShare);
        // Subtracts the share from the total of shares borrowed
        totalBorrowShare = totalBorrowShare.sub(share);
        // Subtracts the calculated amount from the total amount borrowed
        totalBorrow = totalBorrow.sub(amount);
        emit RemoveBorrow(msg.sender, amount, share);
        return amount;
    }

    // Deposits an amount of collateral from the caller
    function addCollateral(uint256 amount) public {
        _addCollateral(msg.sender, amount);
        vault.transferFrom(tokenCollateral, msg.sender, amount);
    }

    // Deposits an amount of supply (the borrowable token) from the caller
    function addAsset(uint256 amount) public {
        // Accrue interest before calculating pool shares in _addAsset
        accrue();
        updateInterestRate();
        _addAsset(msg.sender, amount);
        vault.transferFrom(tokenAsset, msg.sender, amount);
    }

    // Withdraws a share of collateral of the caller to the specified address
    function removeCollateral(uint256 share, address to) public {
        accrue();
        uint256 amount = _removeCollateralShare(msg.sender, share);
        // Only allow withdrawing if user is solvent (in case of a closed liquidation)
        require(isSolvent(msg.sender, false), 'BentoBox: user insolvent');
        vault.transfer(tokenCollateral, to, amount);
    }

    // Withdraws a share of supply (the borrowable token) of the caller to the specified address
    function removeAsset(uint256 share, address to) public {
        // Accrue interest before calculating pool shares in _removeAssetShare
        accrue();
        updateInterestRate();
        uint256 amount = _removeAssetShare(msg.sender, share);
        vault.transfer(tokenAsset, to, amount);
    }

    // Borrows the given amount from the supply to the specified address
    function borrow(uint256 amount, address to) public {
        require(amount <= totalAsset.sub(totalBorrow), 'BentoBox: not enough liquidity');
        accrue();
        updateInterestRate();
        _addBorrow(msg.sender, amount);
        require(isSolvent(msg.sender, false), 'BentoBox: user insolvent');
        vault.transfer(tokenAsset, to, amount);
    }

    // Repays the given share
    function repay(uint256 share) public {
        accrue();
        updateInterestRate();
        uint256 amount = _removeBorrowShare(msg.sender, share);
        vault.transferFrom(tokenAsset, msg.sender, amount);
    }

    // Handles shorting with an approved swapper
    function short(address swapper, uint256 amountAsset, uint256 minAmountCollateral) public {
        require(amountAsset <= totalAsset.sub(totalBorrow), 'BentoBox: not enough liquidity');

        require(vault.swappers(swapper), 'BentoBox: Invalid swapper');
        accrue();
        updateInterestRate();
        _addBorrow(msg.sender, amountAsset);

        // Swaps the borrowable asset for collateral
        (bool success, bytes memory result) = swapper.delegatecall(
            abi.encodeWithSignature("swap(address,address,address,uint256,uint256)", swapper, tokenAsset, tokenCollateral, amountAsset, minAmountCollateral));
        require(success, 'BentoBox: Swap failed');
        uint256 amountCollateral = abi.decode(result, (uint256));
        _addCollateral(msg.sender, amountCollateral);

        require(isSolvent(msg.sender, false), 'BentoBox: user insolvent');
    }

    // Handles unwinding shorts with an approved swapper
    function unwind(address swapper, uint256 borrowShare, uint256 maxAmountCollateral) public {
        require(vault.swappers(swapper), 'BentoBox: Invalid swapper');
        accrue();
        updateInterestRate();

        uint256 borrowAmount = _removeBorrowShare(msg.sender, borrowShare);

        // Swaps the collateral back for the borrowal asset
        (bool success, bytes memory result) = swapper.delegatecall(
            abi.encodeWithSignature("swapExact(address,address,address,uint256,uint256)", swapper, tokenCollateral, tokenAsset, maxAmountCollateral, borrowAmount));
        require(success, 'BentoBox: Swap failed');
        _removeCollateralShare(msg.sender, abi.decode(result, (uint256)).mul(totalCollateralShare).div(totalCollateral));

        require(isSolvent(msg.sender, false), 'BentoBox: user insolvent');
    }

    // Handles the liquidation of users' balances, once the users' amount of collateral is too low
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
                // Gets the user's share of the total borrowed amount
                uint256 borrowShare = borrowShares[i];
                // Calculates the user's amount borrowed
                uint256 borrowAmount = borrowShare.mul(totalBorrow).div(totalBorrowShare);
                // Calculates the amount of collateral that's going to be swapped for the asset
                uint256 collateralAmount = borrowAmount.mul(1e13).mul(liqMultiplier).div(exchangeRate);
                // Calculates the share of the collateral to remove from the user's balance
                uint256 collateralShare = collateralAmount.mul(totalCollateralShare).div(totalCollateral);

                // Removes the share of collateral from the user's balance
                userCollateralShare[user] = userCollateralShare[user].sub(collateralShare);
                // Removes the share of user's borrowed tokens from the user
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

            // Swaps the users' collateral for the borrowed asset 
            (bool success, bytes memory result) = swapper.delegatecall(
                abi.encodeWithSignature("swap(address,address,address,uint256,uint256)", swapper, tokenCollateral, tokenAsset, allCollateralAmount, allBorrowAmount));
            require(success, 'BentoBox: Swap failed');
            uint256 extraAsset = abi.decode(result, (uint256)).sub(allBorrowAmount);

            // The extra asset gets added to the pool
            uint256 feeAmount = extraAsset.div(10); // 10% of profit goes to fee
            feesPending = feesPending.add(feeAmount);

            totalAsset = totalAsset.add(extraAsset.sub(feeAmount));
            emit AddAsset(address(0), extraAsset, 0);
        } else if (swapper != address(0)) {
            // Open liquidation directly using the caller's funds, without swapping
            vault.transferFrom(tokenAsset, to, allBorrowAmount);
            vault.transfer(tokenCollateral, to, allCollateralAmount);
        } else {
            // Open (flash) liquidation: get proceeds first and provide the borrow after
            vault.transfer(tokenCollateral, swapper, allCollateralAmount);
            // Swap using a swapper freely chosen by the caller
            if (swapper != address(0)) {ISwapper(swapper).swap(tokenCollateral, tokenAsset, allCollateralAmount, allBorrowAmount, to);}
            vault.transferFrom(tokenAsset, swapper, allBorrowAmount);
        }
    }
}