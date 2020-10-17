// SPDX-License-Identifier: UNLICENSED
// Copyright 2020 BoringCrypto - All rights reserved

// WARNING!!! DO NOT USE!!! NOT YET TESTED + NOT YET SECURITY CONSIDERED + DEF. NOT YET AUDITED!!!
// FOR CONCEPT TESTING ONLY!

// solium-disable security/no-low-level-calls

pragma solidity ^0.6.12;
import "./libraries/BoringMath.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/IVault.sol";

interface IDelegateSwapper {
    // Withdraws amountFrom 'from tokens' from the vault, turns it into at least amountToMin 'to tokens' and transfers those into the vault.
    // Returns amount of tokens added to the vault.
    function swap(address swapper, address from, address to, uint256 amountFrom, uint256 amountToMin) external returns (uint256);
}

interface ISwapper {
    function swap(address from, address to, uint256 amountFrom, uint256 amountTo, address profitTo) external;
}

// Special thanks to:
// https://twitter.com/burger_crypto - for the idea of trying to let the LPs benefit from liquidations
// TODO: check all reentrancy paths
// TODO: what to do when the entire pool is underwater?
// TODO: ensure BoringMath is always used
// We do allow supplying B and borrowing, but the supply does NOT provide collateral as it's just silly and no UI should allow this
contract Pair {
    using BoringMath for uint256;

    // Keep at the top in this order for delegate calls to be able to access them
    IVault public vault;
    address public tokenCollateral;
    address public tokenSupply;

    mapping(address => uint256) public userCollateralShare;
    mapping(address => uint256) public userSupplyShare; // balanceOf
    mapping(address => uint256) public userBorrowShare;

    IOracle public oracle;

    uint256 exchangeRate;

    uint256 public lastBlockAccrued;

    uint256 public totalCollateral;
    uint256 public totalSupply; // Includes totalBorrow
    uint256 public totalBorrow; // Total units of tokenB borrowed

    uint256 public totalCollateralShare; // Total amount of shares in the tokenA pool
    uint256 public totalSupplyShare; // Total amount of shares in the tokenB pool
    uint256 public totalBorrowShare;

    uint256 public interestPerBlock;
    uint256 public lastInterestBlock;
    uint256 public minimumInterest;
    uint256 public maximumInterest;
    uint256 public targetMinUse;
    uint256 public targetMaxUse;

    uint256 public colRate;     // Collateral rate used to calculate if the protocol can liquidate
    uint256 public openColRate; // Collateral rate used to calculate if ANYONE can liquidate
    uint256 public liqMultiplier;
    uint256 public fee;
    uint256 public feesPending;

    function init(IVault vault_, address collateral_address, address supply_address, IOracle oracle_address) public {
        vault = vault_;
        tokenCollateral = collateral_address;
        tokenSupply = supply_address;
        oracle = oracle_address;
        lastInterestBlock = block.number;

        interestPerBlock = 4566210045;  // 1% APR, with 1e18 being 100%
        minimumInterest = 1141552511;    // 0.25% APR
        maximumInterest = 4566210045000; // 1000% APR
        targetMinUse = 700000000000000000; // 70%
        targetMaxUse = 800000000000000000; // 80%

        colRate = 75000; // 75%
        openColRate = 77000; // 77%
        liqMultiplier = 112000; // 12% more tokenA
        fee = 10000; // 10%
    }

    function accrue() public {
        // The first time lastBlockAccrued will be 0, but also borrowed will be 0, so all good
        totalBorrow = totalBorrow.add(totalBorrow.mul(interestPerBlock).mul(block.number - lastBlockAccrued).div(1e18));
        lastBlockAccrued = block.number;
    }

    function isSolvent(address user, bool open) public view returns (bool) {
        // accrue must have already been called!
        if (userBorrowShare[user] == 0) return true;
        if (totalCollateralShare == 0) return false;

        uint256 collateral = userCollateralShare[user].mul(totalCollateral).div(totalCollateralShare);
        uint256 borrow = userBorrowShare[user].mul(totalBorrow).div(totalBorrowShare);

        return collateral.mul(open ? openColRate : colRate).div(1e5) >= borrow.mul(exchangeRate).div(1e18);
    }

    event NewExchangeRate(uint256 rate);
    event NewInterestRate(uint256 rate);
    event AddCollateral(address indexed user, uint256 amount, uint256 share);
    event AddSupply(address indexed user, uint256 amount, uint256 share);
    event AddBorrow(address indexed user, uint256 amount, uint256 share);
    event RemoveCollateral(address indexed user, uint256 amount, uint256 share);
    event RemoveSupply(address indexed user, uint256 amount, uint256 share);
    event RemoveBorrow(address indexed user, uint256 amount, uint256 share);

    // Gets the exchange rate. How much collateral to buy 1e18 supply.
    function updateExchangeRate() public returns (uint256) {
        (bool success, uint256 rate) = oracle.get(address(this));

        // TODO: How to deal with unsuccesful fetch
        if (success) {
            exchangeRate = rate;
            emit NewExchangeRate(rate);
        }
        return exchangeRate;
    }

    // TODO: Needs guard against manipulation?
    function updateInterestRate() public {
        uint256 blocks = block.number - lastInterestBlock;
        if (blocks == 0) {return;}
        uint256 utilization = totalBorrow.mul(1e18).div(totalSupply);
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

    function _addCollateral(address user, uint256 amount) private {
        uint256 newShare = totalCollateralShare == 0 ? amount : amount.mul(totalCollateralShare).div(totalCollateral);
        userCollateralShare[user] = userCollateralShare[user].add(newShare);
        totalCollateralShare = totalCollateralShare.add(newShare);
        totalCollateral = totalCollateral.add(amount);
        emit AddCollateral(msg.sender, amount, newShare);
    }

    function _addSupply(address user, uint256 amount) private {
        uint256 newShare = totalSupplyShare == 0 ? amount : amount.mul(totalSupplyShare).div(totalSupply);
        userSupplyShare[user] = userSupplyShare[user].add(newShare);
        totalSupplyShare = totalSupplyShare.add(newShare);
        totalSupply = totalSupply.add(amount);
        emit AddSupply(msg.sender, amount, newShare);
    }

    function _addBorrow(address user, uint256 amount) private {
        uint256 newShare = totalBorrowShare == 0 ? amount : amount.mul(totalBorrowShare).div(totalBorrow);
        userBorrowShare[user] = userBorrowShare[user].add(newShare);
        totalBorrowShare = totalBorrowShare.add(newShare);
        totalBorrow = totalBorrow.add(amount);
        emit AddBorrow(msg.sender, amount, newShare);
    }

    function _removeCollateralShare(address user, uint256 share) private returns (uint256) {
        userCollateralShare[user] = userCollateralShare[user].sub(share);
        uint256 amount = share.mul(totalCollateral).div(totalCollateralShare);
        totalCollateralShare = totalCollateralShare.sub(share);
        totalCollateral = totalCollateral.sub(amount);
        emit RemoveCollateral(msg.sender, amount, share);
        return amount;
    }

    function _removeSupplyShare(address user, uint256 share) private returns (uint256) {
        userSupplyShare[user] = userSupplyShare[user].sub(share);
        uint256 amount = share.mul(totalSupply).div(totalSupplyShare);
        totalSupplyShare = totalSupplyShare.sub(share);
        totalSupply = totalSupply.sub(amount);
        emit RemoveSupply(msg.sender, amount, share);
        return amount;
    }

    function _removeBorrowShare(address user, uint256 share) private returns (uint256) {
        userBorrowShare[user] = userBorrowShare[user].sub(share);
        uint256 amount = share.mul(totalBorrow).div(totalBorrowShare);
        totalBorrowShare = totalBorrowShare.sub(share);
        totalBorrow = totalBorrow.sub(amount);
        emit RemoveBorrow(msg.sender, amount, share);
        return amount;
    }

    function addCollateral(uint256 amount) public {
        _addCollateral(msg.sender, amount);
        vault.transferFrom(tokenCollateral, msg.sender, amount);
    }

    function addSupply(uint256 amount) public {
        accrue();
        _addSupply(msg.sender, amount);
        vault.transferFrom(tokenSupply, msg.sender, amount);
    }

    function removeCollateral(uint256 share, address to) public {
        accrue();
        uint256 amount = _removeCollateralShare(msg.sender, share);
        require(isSolvent(msg.sender, false), 'BentoBox: user insolvent');
        vault.transfer(tokenCollateral, to, amount);
    }

    function removeSupply(uint256 share, address to) public {
        accrue();
        uint256 amount = _removeSupplyShare(msg.sender, share);
        vault.transfer(tokenSupply, to, amount);
    }

    function borrow(uint256 amount, address to) public {
        require(amount <= totalSupply.sub(totalBorrow), 'BentoBox: not enough liquidity');
        accrue();
        _addBorrow(msg.sender, amount);
        require(isSolvent(msg.sender, false), 'BentoBox: user insolvent');
        vault.transfer(tokenSupply, to, amount);
    }

    function repay(uint256 share) public {
        accrue();
        uint256 amount = _removeBorrowShare(msg.sender, share);
        vault.transferFrom(tokenSupply, msg.sender, amount);
    }

    function short(address swapper, uint256 amountSupply, uint256 minAmountCollateral) public {
        require(amountSupply <= totalSupply.sub(totalBorrow), 'BentoBox: not enough liquidity');

        require(vault.swappers(swapper), 'BentoBox: Invalid swapper');
        accrue();
        _addBorrow(msg.sender, amountSupply);

        (bool success, bytes memory result) = swapper.delegatecall(
            abi.encodeWithSignature("swap(address,address,address,uint256,uint256)", swapper, tokenSupply, tokenCollateral, amountSupply, minAmountCollateral));
        require(success, 'BentoBox: Swap failed');
        uint256 amountCollateral = abi.decode(result, (uint256));
        _addCollateral(msg.sender, amountCollateral);

        require(isSolvent(msg.sender, false), 'BentoBox: user insolvent');
    }

    function unwind(address swapper, uint256 borrowShare, uint256 maxAmountCollateral) public {
        require(vault.swappers(swapper), 'BentoBox: Invalid swapper');
        accrue();

        uint256 borrowAmount = _removeBorrowShare(msg.sender, borrowShare);

        (bool success, bytes memory result) = swapper.delegatecall(
            abi.encodeWithSignature("swapExact(address,address,address,uint256,uint256)", swapper, tokenCollateral, tokenSupply, maxAmountCollateral, borrowAmount));
        require(success, 'BentoBox: Swap failed');
        _removeCollateralShare(msg.sender, abi.decode(result, (uint256)).mul(totalCollateralShare).div(totalCollateral));

        require(isSolvent(msg.sender, false), 'BentoBox: user insolvent');
    }

    function liquidate(address[] calldata users, uint256[] calldata borrowShares, address to, address swapper, bool open) public {
        updateExchangeRate();

        uint256 allCollateralAmount;
        uint256 allCollateralShare;
        uint256 allBorrowAmount;
        uint256 allBorrowShare;
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            if (!isSolvent(user, open)) {
                uint256 borrowShare = borrowShares[i];
                uint256 borrowAmount = borrowShare.mul(totalBorrow).div(totalBorrowShare);
                uint256 collateralAmount = borrowAmount.mul(1e13).mul(liqMultiplier).div(exchangeRate);
                uint256 collateralShare = collateralAmount.mul(totalCollateralShare).div(totalCollateral);

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
                abi.encodeWithSignature("swap(address,address,address,uint256,uint256)", swapper, tokenCollateral, tokenSupply, allCollateralAmount, allBorrowAmount));
            require(success, 'BentoBox: Swap failed');
            uint256 extraSupply = abi.decode(result, (uint256)).sub(allBorrowAmount);

            // The extra supply gets added to the pool
            totalSupply = totalSupply.add(extraSupply);
            emit AddSupply(address(0), extraSupply, 0);
        } else {
            // Open (flash) liquidation: get proceeds first and provide the borrow after
            if (swapper != address(0)) {to = swapper;}
            vault.transfer(tokenCollateral, to, allCollateralAmount);
            if (swapper != address(0)) {ISwapper(swapper).swap(tokenCollateral, tokenSupply, allCollateralAmount, allBorrowAmount, to);}
            vault.transferFrom(tokenSupply, to, allBorrowAmount);
        }
    }
}