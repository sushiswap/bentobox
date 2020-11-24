// SPDX-License-Identifier: UNLICENSED
// Copyright 2020 BoringCrypto - All rights reserved

// WARNING!!! DO NOT USE!!! NOT YET TESTED + NOT YET SECURITY CONSIDERED + DEF. NOT YET AUDITED!!!
// FOR CONCEPT TESTING ONLY!

// solium-disable security/no-low-level-calls

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "./libraries/BoringMath.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IOracle.sol";
import "./libraries/Ownable.sol";
import "./BentoBox.sol";
import "./ERC20.sol";
import "./interfaces/ISwapper.sol";

// Special thanks to:
// https://twitter.com/burger_crypto - for the idea of trying to let the LPs benefit from liquidations
// TODO: check all reentrancy paths
// TODO: what to do when the entire pool is underwater?
// TODO: ensure BoringMath is always used
// We do allow supplying assets and borrowing, but the asset does NOT provide collateral as it's just silly and no UI should allow this

contract LendingPair is ERC20, Ownable {
    using BoringMath for uint256;

    // Keep at the top in this order for delegate calls to be able to access them
    BentoBox public bentoBox;
    LendingPair public masterContract;
    address public feeTo;
    address public dev;

    IERC20 public collateral;
    IERC20 public asset;

    mapping(address => uint256) public userCollateral;
    // userAssetShare = balanceOf - the asset share is the token.
    mapping(address => uint256) public userBorrowShare;

    IOracle public oracle;
    bytes public oracleData;
    mapping(ISwapper => bool) public swappers;

    uint256 public totalCollateral;
    uint256 public totalAsset; // Includes totalBorrow
    uint256 public totalBorrow; // Total units of asset borrowed

    // totalAssetShare = totalSupply - Total amount of shares in the asset pool
    uint256 public totalBorrowShare;

    // TODO: Consider always updating interest and accrue together to reduce one update, but sometimes add one
    uint256 public exchangeRate;
    uint256 public lastBlockAccrued;

    uint256 public interestPerBlock;
    uint256 public lastInterestBlock; // Last block when the interest rate was updated

    uint256 public feesPending;

    string public constant symbol = "BENTO M LP";
    string public constant name = "Bento Medium Risk Lending Pool";

    function decimals() public view returns (uint8) {
        return asset.decimals();
    }

    event Initialized(address indexed masterContract, address clone_address);
    event NewExchangeRate(uint256 rate);
    event AddCollateral(address indexed user, uint256 amount);
    event AddAsset(address indexed user, uint256 amount, uint256 share);
    event AddBorrow(address indexed user, uint256 amount, uint256 share);
    event RemoveCollateral(address indexed user, uint256 amount);
    event RemoveAsset(address indexed user, uint256 amount, uint256 share);
    event RemoveBorrow(address indexed user, uint256 amount, uint256 share);

    constructor() public {
        dev = msg.sender;
        feeTo = msg.sender;
    }

    // Serves as the constructor, as clones can't have a regular constructor
    function init(IERC20 collateral_, IERC20 asset_, IOracle oracle_address, bytes calldata oracleData_) public {
        require(address(bentoBox) == address(0), 'BentoBox: already initialized');

        collateral = collateral_;
        asset = asset_;

        oracle = oracle_address;
        oracleData = oracleData_;

        interestPerBlock = 4566210045;  // 1% APR, with 1e18 being 100%
        lastInterestBlock = block.number;
    }

    function setBentoBox(BentoBox bentoBox_, address masterContract_) public {
        require(address(bentoBox) == address(0), 'BentoBox: already initialized');
        bentoBox = bentoBox_;
        masterContract = LendingPair(masterContract_);
    }

    function setSwapper(ISwapper swapper, bool enable) public onlyOwner {
        swappers[swapper] = enable;
    }

    function setFeeTo(address newFeeTo) public onlyOwner { feeTo = newFeeTo; }
    function setDev(address newDev) public { require(msg.sender == dev, 'BentoBox: Not dev'); dev = newDev; }

    // Accrues the interest on the borrowed tokens and handles the accumulation of fees
    function accrue() public {
        // Number of blocks since accrue was called
        uint256 blocks = block.number - lastBlockAccrued;
        if (blocks == 0) {return;}
        // The first time lastBlockAccrued will be 0, but also borrowed will be 0, so all good
        uint256 extraAmount = totalBorrow.mul(interestPerBlock).mul(blocks) / 1e18;
        uint256 feeAmount = extraAmount / 10; // 10% of interest paid goes to fee
        totalBorrow = totalBorrow.add(extraAmount);
        totalAsset = totalAsset.add(extraAmount.sub(feeAmount));
        feesPending = feesPending.add(feeAmount);
        lastBlockAccrued = block.number;
    }

    // Withdraws the fees accumulated
    function withdrawFees() public {
        accrue();
        uint256 fees = feesPending.sub(1);
        uint256 devFee = fees / 10; // 10% dev fee (of 10%)
        feesPending = 1; // Don't set it to 0 as that would increase the gas cost for the next accrue called by a user.
        bentoBox.withdrawShare(asset, masterContract.feeTo(), fees.sub(devFee));
        bentoBox.withdrawShare(asset, masterContract.dev(), devFee);
    }

    // Checks if the user is solvent.
    // Has an option to check if the user is solvent in an open/closed liquidation case.
    function isSolvent(address user, bool open) public view returns (bool) {
        // accrue must have already been called!
        if (userBorrowShare[user] == 0) return true;
        if (totalCollateral == 0) return false;

        uint256 borrow = userBorrowShare[user].mul(totalBorrow) / totalBorrowShare;

        // openColRate : colRate
        return userCollateral[user].mul(open ? 77000 : 75000) / 1e5 >= borrow.mul(exchangeRate) / 1e18;
    }

    function peekExchangeRate() public view returns (bool, uint256) {
        return oracle.peek(oracleData);
    }

    // Gets the exchange rate. How much collateral to buy 1e18 asset.
    function updateExchangeRate() public returns (uint256) {
        (bool success, uint256 rate) = oracle.get(oracleData);

        // TODO: How to deal with unsuccessful fetch
        if (success) {
            exchangeRate = rate;
            emit NewExchangeRate(rate);
        }
        return exchangeRate;
    }

    function updateInterestRate() public {
        if (totalAsset == 0) {return;}

        uint256 blocks = block.number - lastInterestBlock; // Number of blocks since accrue was called
        if (blocks == 0) {return;}
        lastInterestBlock = block.number;
        uint256 utilization = totalBorrow.mul(1e18) / totalAsset;
        uint256 newInterestPerBlock;
        if (utilization < 7e17) { // less than 70% utilization
            uint256 underFactor = uint256(7e17).sub(utilization).mul(1e18) / 7e17;
            uint256 scale = uint256(2000e36).add(underFactor.mul(underFactor).mul(blocks));
            newInterestPerBlock = interestPerBlock.mul(2000e36) / scale;
            if (newInterestPerBlock < 1141552511) {newInterestPerBlock = 1141552511;} // 0.25% APR minimum
        } else if (utilization > 8e17) { // more than 80% utilization
            uint256 overFactor = utilization.sub(8e17).mul(1e18) / uint256(1e18).sub(8e17);
            uint256 scale = uint256(2000e36).add(overFactor.mul(overFactor).mul(blocks));
            newInterestPerBlock = interestPerBlock.mul(scale) / 2000e36;
            if (newInterestPerBlock > 4566210045000) {newInterestPerBlock = 4566210045000;} // 0.25% APR maximum
        } else {return;}

        interestPerBlock = newInterestPerBlock;
    }

    // Handles internal variable updates when collateral is deposited
    function _addCollateral(address user, uint256 amount) private {
        // Adds this share to user
        userCollateral[user] = userCollateral[user].add(amount);
        // Adds the amount deposited to the total of collateral
        totalCollateral = totalCollateral.add(amount);
        emit AddCollateral(msg.sender, amount);
    }

    // Handles internal variable updates when supply (the borrowable token) is deposited
    function _addAsset(address user, uint256 amount) private {
        // Calculates what share of the pool the user gets for the amount deposited
        uint256 newShare = totalSupply == 0 ? amount : amount.mul(totalSupply) / totalAsset;
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
        uint256 newShare = totalBorrowShare == 0 ? amount : amount.mul(totalBorrowShare) / totalBorrow;
        // Adds this share to the user
        userBorrowShare[user] = userBorrowShare[user].add(newShare);
        // Adds amount borrowed to the total amount borrowed
        totalBorrowShare = totalBorrowShare.add(newShare);
        // Adds amount borrowed to the total amount borrowed
        totalBorrow = totalBorrow.add(amount);
        emit AddBorrow(msg.sender, amount, newShare);
    }

    // Handles internal variable updates when collateral is withdrawn and returns the amount of collateral withdrawn
    function _removeCollateral(address user, uint256 amount) private {
        // Subtracts the share from user
        userCollateral[user] = userCollateral[user].sub(amount);
        // Subtracts the amount from the total of collateral
        totalCollateral = totalCollateral.sub(amount);
        emit RemoveCollateral(msg.sender, amount);
    }

    // Handles internal variable updates when supply is withdrawn and returns the amount of supply withdrawn
    function _removeAssetShare(address user, uint256 share) private returns (uint256) {
        // Subtracts the share from user
        balanceOf[user] = balanceOf[user].sub(share);
        // Calculates the amount of tokens to withdraw
        uint256 amount = share.mul(totalAsset) / totalSupply;
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
        uint256 amount = share.mul(totalBorrow) / totalBorrowShare;
        // Subtracts the share from the total of shares borrowed
        totalBorrowShare = totalBorrowShare.sub(share);
        // Subtracts the calculated amount from the total amount borrowed
        totalBorrow = totalBorrow.sub(amount);
        emit RemoveBorrow(msg.sender, amount, share);
        return amount;
    }

    // Deposits an amount of collateral from the caller
    function addCollateral(uint256 amount) public {
        _addCollateral(msg.sender, bentoBox.deposit(collateral, msg.sender, amount));
    }

    // Deposits an amount of supply (the borrowable token) from the caller
    function addAsset(uint256 amount) public {
        // Accrue interest before calculating pool shares in _addAsset
        accrue();
        updateInterestRate();
        _addAsset(msg.sender, bentoBox.deposit(asset, msg.sender, amount));
    }

    // Withdraws a share of collateral of the caller to the specified address
    function removeCollateral(uint256 amount, address to) public {
        accrue();
        _removeCollateral(msg.sender, amount);
        // Only allow withdrawing if user is solvent (in case of a closed liquidation)
        require(isSolvent(msg.sender, false), 'BentoBox: user insolvent');
        bentoBox.withdrawShare(collateral, to, amount);
    }

    // Withdraws a share of supply (the borrowable token) of the caller to the specified address
    function removeAsset(uint256 share, address to) public {
        // Accrue interest before calculating pool shares in _removeAssetShare
        accrue();
        updateInterestRate();
        uint256 amount = _removeAssetShare(msg.sender, share);
        bentoBox.withdrawShare(asset, to, amount);
    }

    // Borrows the given amount from the supply to the specified address
    function borrow(uint256 amount, address to) public {
        require(amount <= totalAsset.sub(totalBorrow), 'BentoBox: not enough liquidity');
        accrue();
        updateInterestRate();
        uint256 fee = amount.mul(5) / 10000; // A flat 0.05% fee is charged for any borrow
        _addBorrow(msg.sender, bentoBox.withdraw(asset, to, amount).add(fee));
        totalAsset = totalAsset.add(fee);
        require(isSolvent(msg.sender, false), 'BentoBox: user insolvent');
    }

    // Repays the given share
    function repay(uint256 share) public {
        accrue();
        updateInterestRate();
        uint256 amount = _removeBorrowShare(msg.sender, share);
        bentoBox.depositShare(asset, msg.sender, amount);
    }

    // Handles shorting with an approved swapper
    function short(ISwapper swapper, uint256 amountAsset, uint256 minReturnedCollateral) public {
        require(masterContract.swappers(swapper), 'BentoBox: Invalid swapper');
        accrue();
        updateInterestRate();
        _addBorrow(msg.sender, amountAsset);
        uint256 suppliedAmount = bentoBox.transferShare(asset, address(this), address(swapper), amountAsset);

        // Swaps the borrowable asset for collateral
        swapper.swap(asset, collateral, suppliedAmount, bentoBox.toAmount(collateral, minReturnedCollateral));
        uint256 returnedCollateral = bentoBox.skim(collateral);
        require(returnedCollateral >= minReturnedCollateral, 'BentoBox: not enough collateral returned');
        _addCollateral(msg.sender, returnedCollateral);

        require(isSolvent(msg.sender, false), 'BentoBox: user insolvent');
    }

    // Handles unwinding shorts with an approved swapper
    function unwind(ISwapper swapper, uint256 borrowShare, uint256 maxAmountCollateral) public {
        require(masterContract.swappers(swapper), 'BentoBox: Invalid swapper');
        accrue();
        updateInterestRate();
        uint suppliedAmount = bentoBox.transferShare(collateral, address(this), address(swapper), maxAmountCollateral);

        uint256 borrowAmount = _removeBorrowShare(msg.sender, borrowShare);

        // Swaps the collateral back for the borrowal asset
        uint256 usedAmount = swapper.swapExact(collateral, asset, suppliedAmount, bentoBox.toAmount(asset, borrowAmount), address(this));
        uint256 returnedAssetShare = bentoBox.skim(asset);
        require(returnedAssetShare >= borrowShare, 'BentoBox: Not enough assets returned');

        _removeCollateral(msg.sender, suppliedAmount.sub(usedAmount));

        require(isSolvent(msg.sender, false), 'BentoBox: user insolvent');
    }

    // Handles the liquidation of users' balances, once the users' amount of collateral is too low
    function liquidate(address[] calldata users, uint256[] calldata borrowShares, address to, ISwapper swapper, bool open) public {
        accrue();
        updateExchangeRate();
        updateInterestRate();

        uint256 allCollateralAmount;
        uint256 allBorrowAmount;
        uint256 allBorrowShare;
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            if (!isSolvent(user, open)) {
                // Gets the user's share of the total borrowed amount
                uint256 borrowShare = borrowShares[i];
                // Calculates the user's amount borrowed
                uint256 borrowAmount = borrowShare.mul(totalBorrow) / totalBorrowShare;
                // Calculates the amount of collateral that's going to be swapped for the asset
                uint256 collateralAmount = borrowAmount.mul(1e13).mul(112000) / exchangeRate; // liqMultiplier

                // Removes the share of collateral from the user's balance
                userCollateral[user] = userCollateral[user].sub(collateralAmount);
                // Removes the share of user's borrowed tokens from the user
                userBorrowShare[user] = userBorrowShare[user].sub(borrowShare);
                emit RemoveCollateral(user, collateralAmount);
                emit RemoveBorrow(user, borrowAmount, borrowShare);

                // Keep totals
                allCollateralAmount = allCollateralAmount.add(collateralAmount);
                allBorrowAmount = allBorrowAmount.add(borrowAmount);
                allBorrowShare = allBorrowShare.add(borrowShare);
            }
        }
        require(allBorrowAmount != 0, 'BentoBox: all users are solvent');
        totalBorrow = totalBorrow.sub(allBorrowAmount);
        totalBorrowShare = totalBorrowShare.sub(allBorrowShare);
        totalCollateral = totalCollateral.sub(allCollateralAmount);

        if (!open) {
            // Closed liquidation using a pre-approved swapper for the benefit of the LPs
            require(masterContract.swappers(swapper), 'BentoBox: Invalid swapper');

            // Swaps the users' collateral for the borrowed asset
            uint256 suppliedAmount = bentoBox.transfer(collateral, address(this), address(swapper), allCollateralAmount);
            swapper.swap(collateral, asset, suppliedAmount, bentoBox.toAmount(asset, allBorrowAmount));
            uint256 returnedAssetShare = bentoBox.skim(asset);
            uint256 extraAsset = returnedAssetShare.sub(allBorrowAmount);

            // The extra asset gets added to the pool
            uint256 feeAmount = extraAsset / 10; // 10% of profit goes to fee
            feesPending = feesPending.add(feeAmount);

            totalAsset = totalAsset.add(extraAsset.sub(feeAmount));
            emit AddAsset(address(0), extraAsset, 0);
        } else if (address(swapper) == address(0)) {
            // Open liquidation directly using the caller's funds, without swapping
            bentoBox.deposit(asset, to, allBorrowAmount);
            bentoBox.withdraw(collateral, to, allCollateralAmount);
        } else {
            // Swap using a swapper freely chosen by the caller
            // Open (flash) liquidation: get proceeds first and provide the borrow after
            uint256 suppliedAmount = bentoBox.transfer(collateral, address(this), address(swapper), allCollateralAmount);
            swapper.swap(collateral, asset, suppliedAmount, bentoBox.toAmount(asset, allBorrowAmount));
            uint256 returnedAssetShare = bentoBox.skim(asset);
            uint256 extraAsset = returnedAssetShare.sub(allBorrowAmount);

            totalAsset = totalAsset.add(extraAsset);
            emit AddAsset(address(0), extraAsset, 0);
        }
    }

    function batch(bytes[] calldata calls, bool revertOnFail) public payable returns(bool[] memory, bytes[] memory) {
        bool[] memory successes = new bool[](calls.length);
        bytes[] memory results = new bytes[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(calls[i]);
            require(success || !revertOnFail, 'BentoBox: Transaction failed');
            successes[i] = success;
            results[i] = result;
        }
        return (successes, results);
    }
}
