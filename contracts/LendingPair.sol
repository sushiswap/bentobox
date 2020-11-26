// SPDX-License-Identifier: UNLICENSED
// Copyright 2020 BoringCrypto - All rights reserved

// WARNING!!! DO NOT USE!!! NOT YET TESTED + NOT YET SECURITY CONSIDERED + DEF. NOT YET AUDITED!!!
// FOR CONCEPT TESTING ONLY!

// solium-disable security/no-low-level-calls

pragma solidity 0.6.12;
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
// TODO: turn magic number back into constants
// TODO: check that all actions on a users funds can only be initiated by that user as msg.sender
// We do allow supplying assets and borrowing, but the asset does NOT provide collateral as it's just silly and no UI should allow this

contract LendingPair is ERC20, Ownable {
    using BoringMath for uint256;

    BentoBox public bentoBox;
    LendingPair public masterContract;
    address public feeTo;
    address public dev;

    IERC20 public collateral;
    IERC20 public asset;

    mapping(address => uint256) public userCollateralShare;
    // userAssetFraction is called balanceOf for ERC20 compatibility
    mapping(address => uint256) public userBorrowFraction;

    IOracle public oracle;
    bytes public oracleData;
    mapping(ISwapper => bool) public swappers;

    uint256 public totalCollateralShare;
    uint256 public totalAssetShare; // Includes totalBorrowShare (actual Share in BentoBox = totalAssetShare - totalBorrowShare)
    uint256 public totalBorrowShare; // Total units of asset borrowed

    // totalAssetFraction is called totalSupply for ERC20 compatibility
    uint256 public totalBorrowFraction;

    // TODO: Consider always updating interest and accrue together to reduce one update, but sometimes add one
    uint256 public exchangeRate;
    uint256 public lastBlockAccrued;

    uint256 public interestPerBlock;
    uint256 public lastInterestBlock; // Last block when the interest rate was updated

    uint256 public feesPendingShare;

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

    uint256 public constant closedCollaterizationRate = 75000; // 75%
    uint256 public constant openCollaterizationRate = 77000; // 77%
    uint256 public constant minimumTargetUtilization = 7e17; // 70%
    uint256 public constant maximumTargetUtilization = 8e17; // 80%

    uint256 public constant minimumInterestPerBlock = 1141552511;
    uint256 public constant maximumInterestPerBlock = 1141552511;

    uint256 public constant liquidationMultiplier = 112000; // add 12%

    uint256 public constant protocolFee = 10; // 10%
    uint256 public constant devFee = 10; // 10% of the protocolFee = 1%
    uint256 public constant borrowOpeningFee = 5; // 0.05%

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
        uint256 extraShare = totalBorrowShare.mul(interestPerBlock).mul(blocks) / 1e18;
        uint256 feeShare = extraShare.mul(protocolFee) / 100; // % of interest paid goes to fee
        totalBorrowShare = totalBorrowShare.add(extraShare);
        totalAssetShare = totalAssetShare.add(extraShare.sub(feeShare));
        feesPendingShare = feesPendingShare.add(feeShare);
        lastBlockAccrued = block.number;
    }

    // Withdraws the fees accumulated
    function withdrawFees() public {
        accrue();
        uint256 feeShare = feesPendingShare.sub(1);
        uint256 devFeeShare = feeShare.mul(devFee) / 100;
        feesPendingShare = 1; // Don't set it to 0 as that would increase the gas cost for the next accrue called by a user.
        bentoBox.withdrawShare(asset, masterContract.feeTo(), feeShare.sub(devFeeShare));
        bentoBox.withdrawShare(asset, masterContract.dev(), devFeeShare);
    }

    // Checks if the user is solvent.
    // Has an option to check if the user is solvent in an open/closed liquidation case.
    function isSolvent(address user, bool open) public view returns (bool) {
        // accrue must have already been called!
        if (userBorrowFraction[user] == 0) return true;
        if (totalCollateralShare == 0) return false;

        uint256 borrow = userBorrowFraction[user].mul(totalBorrowShare) / totalBorrowFraction;

        return bentoBox.toAmount(collateral, userCollateralShare[user])
            .mul(1e18).mul(open ? openCollaterizationRate : closedCollaterizationRate)
            / exchangeRate / 1e5 >= bentoBox.toAmount(asset, borrow);
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
        if (totalAssetShare == 0) {return;}

        uint256 blocks = block.number - lastInterestBlock; // Number of blocks since accrue was called
        if (blocks == 0) {return;}
        lastInterestBlock = block.number;
        uint256 utilization = totalBorrowShare.mul(1e18) / totalAssetShare;
        uint256 newInterestPerBlock;
        if (utilization < minimumTargetUtilization) {
            uint256 underFactor = uint256(7e17).sub(utilization).mul(1e18) / 7e17;
            uint256 scale = uint256(2000e36).add(underFactor.mul(underFactor).mul(blocks));
            newInterestPerBlock = interestPerBlock.mul(2000e36) / scale;
            if (newInterestPerBlock < minimumInterestPerBlock) {newInterestPerBlock = minimumInterestPerBlock;} // 0.25% APR minimum
        } else if (utilization > maximumTargetUtilization) {
            uint256 overFactor = utilization.sub(8e17).mul(1e18) / uint256(1e18).sub(8e17);
            uint256 scale = uint256(2000e36).add(overFactor.mul(overFactor).mul(blocks));
            newInterestPerBlock = interestPerBlock.mul(scale) / 2000e36;
            if (newInterestPerBlock > maximumInterestPerBlock) {newInterestPerBlock = maximumInterestPerBlock;} // 0.25% APR maximum
        } else {return;}

        interestPerBlock = newInterestPerBlock;
    }

    // Handles internal variable updates when collateral is deposited
    function _addCollateralShare(address user, uint256 share) private {
        // Adds this share to user
        userCollateralShare[user] = userCollateralShare[user].add(share);
        // Adds the share deposited to the total of collateral
        totalCollateralShare = totalCollateralShare.add(share);
        emit AddCollateral(msg.sender, share);
    }

    // Handles internal variable updates when supply (the borrowable token) is deposited
    function _addAssetShare(address user, uint256 share) private {
        // Calculates what share of the pool the user gets for the amount deposited
        uint256 newFraction = totalSupply == 0 ? share : share.mul(totalSupply) / totalAssetShare;
        // Adds this share to user
        balanceOf[user] = balanceOf[user].add(newFraction);
        // Adds this share to the total of supply shares
        totalSupply = totalSupply.add(newFraction);
        // Adds the amount deposited to the total of supply
        totalAssetShare = totalAssetShare.add(share);
        emit AddAsset(msg.sender, share, newFraction);
    }

    // Handles internal variable updates when supply (the borrowable token) is borrowed
    function _addBorrow(address user, uint256 share) private {
        // Calculates what share of the borrowed funds the user gets for the amount borrowed
        uint256 newFraction = totalBorrowFraction == 0 ? share : share.mul(totalBorrowFraction) / totalBorrowShare;
        // Adds this share to the user
        userBorrowFraction[user] = userBorrowFraction[user].add(newFraction);
        // Adds amount borrowed to the total amount borrowed
        totalBorrowFraction = totalBorrowFraction.add(newFraction);
        // Adds amount borrowed to the total amount borrowed
        totalBorrowShare = totalBorrowShare.add(share);
        emit AddBorrow(msg.sender, share, newFraction);
    }

    // Handles internal variable updates when collateral is withdrawn and returns the amount of collateral withdrawn
    function _removeCollateralShare(address user, uint256 share) private {
        // Subtracts the share from user
        userCollateralShare[user] = userCollateralShare[user].sub(share);
        // Subtracts the amount from the total of collateral
        totalCollateralShare = totalCollateralShare.sub(share);
        emit RemoveCollateral(msg.sender, share);
    }

    // Handles internal variable updates when supply is withdrawn and returns the amount of supply withdrawn
    function _removeAssetFraction(address user, uint256 share) private returns (uint256) {
        // Subtracts the share from user
        balanceOf[user] = balanceOf[user].sub(share);
        // Calculates the amount of tokens to withdraw
        uint256 amount = share.mul(totalAssetShare) / totalSupply;
        // Subtracts the calculated amount from the total of supply
        totalSupply = totalSupply.sub(share);
        // Subtracts the share from the total of supply shares
        totalAssetShare = totalAssetShare.sub(amount);
        emit RemoveAsset(msg.sender, amount, share);
        return amount;
    }

    // Handles internal variable updates when supply is repaid
    function _removeBorrowFraction(address user, uint256 share) private returns (uint256) {
        // Subtracts the share from user
        userBorrowFraction[user] = userBorrowFraction[user].sub(share);
        // Calculates the amount of tokens to repay
        uint256 amount = share.mul(totalBorrowShare) / totalBorrowFraction;
        // Subtracts the share from the total of shares borrowed
        totalBorrowFraction = totalBorrowFraction.sub(share);
        // Subtracts the calculated amount from the total amount borrowed
        totalBorrowShare = totalBorrowShare.sub(amount);
        emit RemoveBorrow(msg.sender, amount, share);
        return amount;
    }

    // Deposits an amount of collateral from the caller
    function addCollateral(uint256 amount) public {
        _addCollateralShare(msg.sender, bentoBox.deposit(collateral, msg.sender, amount));
    }

    // Deposits an amount of supply (the borrowable token) from the caller
    function addAsset(uint256 amount) public {
        // Accrue interest before calculating pool shares in _addAssetShare
        accrue();
        updateInterestRate();
        _addAssetShare(msg.sender, bentoBox.deposit(asset, msg.sender, amount));
    }

    // Withdraws a share of collateral of the caller to the specified address
    function removeCollateral(uint256 share, address to) public {
        accrue();
        _removeCollateralShare(msg.sender, share);
        // Only allow withdrawing if user is solvent (in case of a closed liquidation)
        require(isSolvent(msg.sender, false), 'BentoBox: user insolvent');
        bentoBox.withdrawShare(collateral, to, share);
    }

    // Withdraws a share of supply (the borrowable token) of the caller to the specified address
    function removeAsset(uint256 fraction, address to) public {
        // Accrue interest before calculating pool shares in _removeAssetFraction
        accrue();
        updateInterestRate();
        uint256 share = _removeAssetFraction(msg.sender, fraction);
        bentoBox.withdrawShare(asset, to, share);
    }

    // Borrows the given amount from the supply to the specified address
    function borrow(uint256 amount, address to) public {
        accrue();
        updateInterestRate();
        uint256 share = bentoBox.withdraw(asset, to, amount); // TODO: reentrancy issue?
        uint256 feeShare = share.mul(borrowOpeningFee) / 10000; // A flat 0.05% fee is charged for any borrow
        _addBorrow(msg.sender, share.add(feeShare));
        totalAssetShare = totalAssetShare.add(feeShare);
        require(isSolvent(msg.sender, false), 'BentoBox: user insolvent');
    }

    // Repays the given share
    function repay(uint256 fraction) public {
        accrue();
        updateInterestRate();
        uint256 share = _removeBorrowFraction(msg.sender, fraction);
        bentoBox.depositShare(asset, msg.sender, share);
    }

    // Handles shorting with an approved swapper
    function short(ISwapper swapper, uint256 assetShare, uint256 minCollateralShare) public {
        require(masterContract.swappers(swapper), 'BentoBox: Invalid swapper');
        accrue();
        updateInterestRate();
        _addBorrow(msg.sender, assetShare);
        uint256 suppliedAssetAmount = bentoBox.transferShareFrom(asset, address(this), address(swapper), assetShare);

        // Swaps the borrowable asset for collateral
        swapper.swap(asset, collateral, suppliedAssetAmount, bentoBox.toAmount(collateral, minCollateralShare));
        uint256 returnedCollateralShare = bentoBox.skim(collateral);
        require(returnedCollateralShare >= minCollateralShare, 'BentoBox: not enough collateral returned');
        _addCollateralShare(msg.sender, returnedCollateralShare);

        require(isSolvent(msg.sender, false), 'BentoBox: user insolvent');
    }

    // Handles unwinding shorts with an approved swapper
    function unwind(ISwapper swapper, uint256 borrowShare, uint256 maxAmountCollateral) public {
        require(masterContract.swappers(swapper), 'BentoBox: Invalid swapper');
        accrue();
        updateInterestRate();
        uint suppliedAmount = bentoBox.transferShareFrom(collateral, address(this), address(swapper), maxAmountCollateral);

        uint256 borrowAmount = _removeBorrowFraction(msg.sender, borrowShare);

        // Swaps the collateral back for the borrowal asset
        uint256 usedAmount = swapper.swapExact(collateral, asset, suppliedAmount, bentoBox.toAmount(asset, borrowAmount), address(this));
        uint256 returnedAssetShare = bentoBox.skim(asset);
        require(returnedAssetShare >= borrowShare, 'BentoBox: Not enough assets returned');

        _removeCollateralShare(msg.sender, suppliedAmount.sub(usedAmount));

        require(isSolvent(msg.sender, false), 'BentoBox: user insolvent');
    }

    // Handles the liquidation of users' balances, once the users' amount of collateral is too low
    function liquidate(address[] calldata users, uint256[] calldata borrowFractions, address to, ISwapper swapper, bool open) public {
        accrue();
        updateExchangeRate();
        updateInterestRate();

        uint256 allCollateralShare;
        uint256 allBorrowShare;
        uint256 allBorrowFraction;
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            if (!isSolvent(user, open)) {
                // Gets the user's share of the total borrowed amount
                uint256 borrowFraction = borrowFractions[i];
                // Calculates the user's amount borrowed
                uint256 borrowShare = borrowFraction.mul(totalBorrowShare) / totalBorrowFraction;
                // Calculates the amount of collateral that's going to be swapped for the asset
                uint256 collateralShare = borrowShare.mul(liquidationMultiplier).mul(exchangeRate) / 1e23;

                // Removes the share of collateral from the user's balance
                userCollateralShare[user] = userCollateralShare[user].sub(collateralShare);
                // Removes the share of user's borrowed tokens from the user
                userBorrowFraction[user] = userBorrowFraction[user].sub(borrowFraction);
                emit RemoveCollateral(user, collateralShare);
                emit RemoveBorrow(user, borrowShare, borrowFraction);

                // Keep totals
                allCollateralShare = allCollateralShare.add(collateralShare);
                allBorrowShare = allBorrowShare.add(borrowShare);
                allBorrowFraction = allBorrowFraction.add(borrowFraction);
            }
        }
        require(allBorrowShare != 0, 'BentoBox: all users are solvent');
        totalBorrowShare = totalBorrowShare.sub(allBorrowShare);
        totalBorrowFraction = totalBorrowFraction.sub(allBorrowFraction);
        totalCollateralShare = totalCollateralShare.sub(allCollateralShare);

        if (!open) {
            // Closed liquidation using a pre-approved swapper for the benefit of the LPs
            require(masterContract.swappers(swapper), 'BentoBox: Invalid swapper');

            // Swaps the users' collateral for the borrowed asset
            uint256 suppliedAmount = bentoBox.transferFrom(collateral, address(this), address(swapper), allCollateralShare);
            swapper.swap(collateral, asset, suppliedAmount, bentoBox.toAmount(asset, allBorrowShare));
            uint256 returnedAssetShare = bentoBox.skim(asset);
            uint256 extraAssetShare = returnedAssetShare.sub(allBorrowShare);

            // The extra asset gets added to the pool
            uint256 feeShare = extraAssetShare.mul(protocolFee) / 100; // % of profit goes to fee
            feesPendingShare = feesPendingShare.add(feeShare);
            totalAssetShare = totalAssetShare.add(extraAssetShare.sub(feeShare));
            emit AddAsset(address(0), extraAssetShare, 0);
        } else if (address(swapper) == address(0)) {
            // Open liquidation directly using the caller's funds, without swapping
            bentoBox.deposit(asset, msg.sender, allBorrowShare);
            bentoBox.withdraw(collateral, to, allCollateralShare);
        } else if (address(swapper) == address(1)) {
            // Open liquidation directly using the caller's funds, without swapping
            bentoBox.transferFrom(asset, msg.sender, to, allBorrowShare);
            bentoBox.transfer(collateral, to, allCollateralShare);
        } else {
            // Swap using a swapper freely chosen by the caller
            // Open (flash) liquidation: get proceeds first and provide the borrow after
            uint256 suppliedAmount = bentoBox.transferFrom(collateral, address(this), address(swapper), allCollateralShare);
            swapper.swap(collateral, asset, suppliedAmount, bentoBox.toAmount(asset, allBorrowShare));
            uint256 returnedAssetShare = bentoBox.skim(asset);
            uint256 extraAsset = returnedAssetShare.sub(allBorrowShare);

            totalAssetShare = totalAssetShare.add(extraAsset);
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