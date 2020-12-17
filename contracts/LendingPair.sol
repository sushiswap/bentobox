// SPDX-License-Identifier: UNLICENSED

// Medium Risk LendingPair

// ▄▄▌  ▄▄▄ . ▐ ▄ ·▄▄▄▄  ▪   ▐ ▄  ▄▄ •  ▄▄▄· ▄▄▄· ▪  ▄▄▄
// ██•  ▀▄.▀·•█▌▐███▪ ██ ██ •█▌▐█▐█ ▀ ▪▐█ ▄█▐█ ▀█ ██ ▀▄ █·
// ██▪  ▐▀▀▪▄▐█▐▐▌▐█· ▐█▌▐█·▐█▐▐▌▄█ ▀█▄ ██▀·▄█▀▀█ ▐█·▐▀▀▄
// ▐█▌▐▌▐█▄▄▌██▐█▌██. ██ ▐█▌██▐█▌▐█▄▪▐█▐█▪·•▐█ ▪▐▌▐█▌▐█•█▌
// .▀▀▀  ▀▀▀ ▀▀ █▪▀▀▀▀▀• ▀▀▀▀▀ █▪·▀▀▀▀ .▀    ▀  ▀ ▀▀▀.▀  ▀

// Copyright (c) 2020 BoringCrypto - All rights reserved
// Twitter: @Boring_Crypto

// Special thanks to:
// @burger_crypto - for the idea of trying to let the LPs benefit from liquidations

// WARNING!!! DO NOT USE!!! BEING AUDITED!!!

// solium-disable security/no-low-level-calls

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./libraries/BoringMath.sol";
import "./interfaces/IOracle.sol";
import "./libraries/Ownable.sol";
import "./ERC20.sol";
import "./interfaces/IMasterContract.sol";
import "./interfaces/ISwapper.sol";
import "./interfaces/IWETH.sol";

// TODO: check all reentrancy paths
// TODO: what to do when the entire pool is underwater?
// TODO: check that all actions on a users funds can only be initiated by that user as msg.sender

contract LendingPair is ERC20, Ownable, IMasterContract {
    using BoringMath for uint256;
    using BoringMath128 for uint128;

    // MasterContract variables
    IBentoBox public immutable bentoBox;
    LendingPair public immutable masterContract;
    address public feeTo;
    address public dev;
    mapping(ISwapper => bool) public swappers;

    // Per clone variables
    // Clone settings
    IERC20 public collateral;
    IERC20 public asset;
    IOracle public oracle;
    bytes public oracleData;

    // User balances
    mapping(address => uint256) public userCollateralAmount;
    // userAssetFraction is called balanceOf for ERC20 compatibility
    mapping(address => uint256) public userBorrowFraction;

    struct TokenTotals {
        uint128 amount;
        uint128 fraction;
    }

    // Total amounts
    uint256 public totalCollateralAmount;
    TokenTotals public totalAsset; // The total assets belonging to the suppliers (including any borrowed amounts).
    TokenTotals public totalBorrow; // Total units of asset borrowed

    // totalSupply for ERC20 compatibility
    function totalSupply() public view returns(uint256) {
        return totalAsset.fraction;
    }

    // Exchange and interest rate tracking
    uint256 public exchangeRate;

    struct AccrueInfo {
        uint64 interestPerBlock;
        uint64 lastBlockAccrued;
        uint128 feesPendingAmount;
    }
    AccrueInfo public accrueInfo;

    // ERC20 'variables'
    function symbol() public view returns(string memory) {
        (bool success, bytes memory data) = address(asset).staticcall(abi.encodeWithSelector(0x95d89b41));
        string memory assetSymbol = success && data.length > 0 ? abi.decode(data, (string)) : "???";

        (success, data) = address(collateral).staticcall(abi.encodeWithSelector(0x95d89b41));
        string memory collateralSymbol = success && data.length > 0 ? abi.decode(data, (string)) : "???";

        return string(abi.encodePacked("bm", collateralSymbol, ">", assetSymbol, "-", oracle.symbol(oracleData)));
    }

    function name() public view returns(string memory) {
        (bool success, bytes memory data) = address(asset).staticcall(abi.encodeWithSelector(0x06fdde03));
        string memory assetName = success && data.length > 0 ? abi.decode(data, (string)) : "???";

        (success, data) = address(collateral).staticcall(abi.encodeWithSelector(0x06fdde03));
        string memory collateralName = success && data.length > 0 ? abi.decode(data, (string)) : "???";

        return string(abi.encodePacked("Bento Med Risk ", collateralName, ">", assetName, "-", oracle.symbol(oracleData)));
    }

    function decimals() public view returns (uint8) {
        (bool success, bytes memory data) = address(asset).staticcall(abi.encodeWithSelector(0x313ce567));
        return success && data.length == 32 ? abi.decode(data, (uint8)) : 18;
    }

    event LogExchangeRate(uint256 rate);
    event LogAccrue(uint256 accruedAmount, uint256 feeAmount, uint256 rate, uint256 utilization);
    event LogAddCollateral(address indexed user, uint256 amount);
    event LogAddAsset(address indexed user, uint256 amount, uint256 fraction);
    event LogAddBorrow(address indexed user, uint256 amount, uint256 fraction);
    event LogRemoveCollateral(address indexed user, uint256 amount);
    event LogRemoveAsset(address indexed user, uint256 amount, uint256 fraction);
    event LogRemoveBorrow(address indexed user, uint256 amount, uint256 fraction);
    event LogFeeTo(address indexed newFeeTo);
    event LogDev(address indexed newDev);
    event LogWithdrawFees();

    constructor(IBentoBox bentoBox_) public {
        bentoBox = bentoBox_;
        masterContract = LendingPair(this);
        dev = msg.sender;
        feeTo = msg.sender;
        emit LogDev(msg.sender);
        emit LogFeeTo(msg.sender);
    }

    // Settings for the Medium Risk LendingPair
    uint256 public constant closedCollaterizationRate = 75000; // 75%
    uint256 public constant openCollaterizationRate = 77000; // 77%
    uint256 public constant minimumTargetUtilization = 7e17; // 70%
    uint256 public constant maximumTargetUtilization = 8e17; // 80%

    uint256 public constant startingInterestPerBlock = 4566210045; // approx 1% APR
    uint256 public constant minimumInterestPerBlock = 1141552511; // approx 0.25% APR
    uint256 public constant maximumInterestPerBlock = 4566210045000;  // approx 1000% APR
    uint256 public constant interestElasticity = 2000e36; // Half or double in 2000 blocks (approx 8 hours)

    uint256 public constant liquidationMultiplier = 112000; // add 12%

    // Fees
    uint256 public constant protocolFee = 10000; // 10%
    uint256 public constant devFee = 10000; // 10% of the protocolFee = 1%
    uint256 public constant borrowOpeningFee = 50; // 0.05%

    // Serves as the constructor, as clones can't have a regular constructor
    function init(bytes calldata data) public override {
        require(address(collateral) == address(0), 'LendingPair: already initialized');
        (collateral, asset, oracle, oracleData) = abi.decode(data, (IERC20, IERC20, IOracle, bytes));

        accrueInfo.interestPerBlock = uint64(startingInterestPerBlock);  // 1% APR, with 1e18 being 100%
        updateExchangeRate();
    }

    function getInitData(IERC20 collateral_, IERC20 asset_, IOracle oracle_, bytes calldata oracleData_) public pure returns(bytes memory data) {
        return abi.encode(collateral_, asset_, oracle_, oracleData_);
    }

    // Accrues the interest on the borrowed tokens and handles the accumulation of fees
    function accrue() public {
        AccrueInfo memory info = accrueInfo;
        // Number of blocks since accrue was called
        uint256 blocks = block.number - info.lastBlockAccrued;
        if (blocks == 0) {return;}
        info.lastBlockAccrued = uint64(block.number);

        uint256 extraAmount;
        uint256 feeAmount;

        TokenTotals memory _totalBorrow = totalBorrow;
        TokenTotals memory _totalAsset = totalAsset;
        if (_totalBorrow.amount > 0) {
            // Accrue interest
            extraAmount = uint256(_totalBorrow.amount).mul(info.interestPerBlock).mul(blocks) / 1e18;
            feeAmount = extraAmount.mul(protocolFee) / 1e5; // % of interest paid goes to fee
            _totalBorrow.amount = _totalBorrow.amount.add(extraAmount.to128());
            totalBorrow = _totalBorrow;
            _totalAsset.amount = _totalAsset.amount.add(extraAmount.sub(feeAmount).to128());
            totalAsset = _totalAsset;
            info.feesPendingAmount = info.feesPendingAmount.add(feeAmount.to128());
        }

        if (_totalAsset.amount == 0) {
            if (info.interestPerBlock != startingInterestPerBlock) {
                info.interestPerBlock = uint64(startingInterestPerBlock);
                emit LogAccrue(extraAmount, feeAmount, startingInterestPerBlock, 0);
            }
            accrueInfo = info; return;
        }

        // Update interest rate
        uint256 utilization = uint256(_totalBorrow.amount).mul(1e18) / _totalAsset.amount;
        uint256 newInterestPerBlock;
        if (utilization < minimumTargetUtilization) {
            uint256 underFactor = minimumTargetUtilization.sub(utilization).mul(1e18) / minimumTargetUtilization;
            uint256 scale = interestElasticity.add(underFactor.mul(underFactor).mul(blocks));
            newInterestPerBlock = uint256(info.interestPerBlock).mul(interestElasticity) / scale;
            if (newInterestPerBlock < minimumInterestPerBlock) {newInterestPerBlock = minimumInterestPerBlock;} // 0.25% APR minimum
       } else if (utilization > maximumTargetUtilization) {
            uint256 overFactor = utilization.sub(maximumTargetUtilization).mul(1e18) / uint256(1e18).sub(maximumTargetUtilization);
            uint256 scale = interestElasticity.add(overFactor.mul(overFactor).mul(blocks));
            newInterestPerBlock = uint256(info.interestPerBlock).mul(scale) / interestElasticity;
            if (newInterestPerBlock > maximumInterestPerBlock) {newInterestPerBlock = maximumInterestPerBlock;} // 1000% APR maximum
        } else {
            emit LogAccrue(extraAmount, feeAmount, info.interestPerBlock, utilization);
            accrueInfo = info; return;
        }

        info.interestPerBlock = uint64(newInterestPerBlock);
        emit LogAccrue(extraAmount, feeAmount, newInterestPerBlock, utilization);
        accrueInfo = info;
    }

    // Checks if the user is solvent.
    // Has an option to check if the user is solvent in an open/closed liquidation case.
    function isSolvent(address user, bool open) public view returns (bool) {
        // accrue must have already been called!
        if (userBorrowFraction[user] == 0) return true;
        if (totalCollateralAmount == 0) return false;

        TokenTotals memory _totalBorrow = totalBorrow;

        return userCollateralAmount[user].mul(1e13).mul(open ? openCollaterizationRate : closedCollaterizationRate)
            >= (userBorrowFraction[user].mul(_totalBorrow.amount) / _totalBorrow.fraction).mul(exchangeRate);
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
            emit LogExchangeRate(rate);
        }
        return exchangeRate;
    }

    // Handles internal variable updates when collateral is deposited
    function _addCollateralAmount(address user, uint256 amount) private {
        // Adds this amount to user
        userCollateralAmount[user] = userCollateralAmount[user].add(amount);
        // Adds the amount deposited to the total of collateral
        totalCollateralAmount = totalCollateralAmount.add(amount);
        emit LogAddCollateral(msg.sender, amount);
    }

    // Handles internal variable updates when supply (the borrowable token) is deposited
    function _addAssetAmount(address user, uint256 amount) private {
        TokenTotals memory _totalAsset = totalAsset;
        // Calculates what amount of the pool the user gets for the amount deposited
        uint256 newFraction = _totalAsset.fraction == 0 ? amount : amount.mul(_totalAsset.fraction) / _totalAsset.amount;
        // Adds this amount to user
        balanceOf[user] = balanceOf[user].add(newFraction);
        // Adds this amount to the total of supply amounts
        _totalAsset.fraction = _totalAsset.fraction.add(newFraction.to128());
        // Adds the amount deposited to the total of supply
        _totalAsset.amount = _totalAsset.amount.add(amount.to128());
        totalAsset = _totalAsset;
        emit LogAddAsset(msg.sender, amount, newFraction);
    }

    // Handles internal variable updates when supply (the borrowable token) is borrowed
    function _addBorrowAmount(address user, uint256 amount) private {
        TokenTotals memory _totalBorrow = totalBorrow;
        // Calculates what amount of the borrowed funds the user gets for the amount borrowed
        uint256 newFraction = _totalBorrow.fraction == 0 ? amount : amount.mul(_totalBorrow.fraction) / _totalBorrow.amount;
        // Adds this amount to the user
        userBorrowFraction[user] = userBorrowFraction[user].add(newFraction);
        // Adds amount borrowed to the total amount borrowed
        _totalBorrow.fraction = _totalBorrow.fraction.add(newFraction.to128());
        // Adds amount borrowed to the total amount borrowed
        _totalBorrow.amount = _totalBorrow.amount.add(amount.to128());
        totalBorrow = _totalBorrow;
        emit LogAddBorrow(msg.sender, amount, newFraction);
    }

    // Handles internal variable updates when collateral is withdrawn and returns the amount of collateral withdrawn
    function _removeCollateralAmount(address user, uint256 amount) private {
        // Subtracts the amount from user
        userCollateralAmount[user] = userCollateralAmount[user].sub(amount);
        // Subtracts the amount from the total of collateral
        totalCollateralAmount = totalCollateralAmount.sub(amount);
        emit LogRemoveCollateral(msg.sender, amount);
    }

    // Handles internal variable updates when supply is withdrawn and returns the amount of supply withdrawn
    function _removeAssetFraction(address user, uint256 fraction) private returns (uint256 amount) {
        TokenTotals memory _totalAsset = totalAsset;
        // Subtracts the fraction from user
        balanceOf[user] = balanceOf[user].sub(fraction);
        // Calculates the amount of tokens to withdraw
        amount = fraction.mul(_totalAsset.amount) / _totalAsset.fraction;
        // Subtracts the calculated fraction from the total of supply
        _totalAsset.fraction = _totalAsset.fraction.sub(fraction.to128());
        // Subtracts the amount from the total of supply amounts
        _totalAsset.amount = _totalAsset.amount.sub(amount.to128());
        totalAsset = _totalAsset;
        emit LogRemoveAsset(msg.sender, amount, fraction);
    }

    // Handles internal variable updates when supply is repaid
    function _removeBorrowFraction(address user, uint256 fraction) private returns (uint256 amount) {
        TokenTotals memory _totalBorrow = totalBorrow;
        // Subtracts the fraction from user
        userBorrowFraction[user] = userBorrowFraction[user].sub(fraction);
        // Calculates the amount of tokens to repay
        amount = fraction.mul(_totalBorrow.amount) / _totalBorrow.fraction;
        // Subtracts the fraction from the total of amounts borrowed
        _totalBorrow.fraction = _totalBorrow.fraction.sub(fraction.to128());
        // Subtracts the calculated amount from the total amount borrowed
        _totalBorrow.amount = _totalBorrow.amount.sub(amount.to128());
        totalBorrow = _totalBorrow;
        emit LogRemoveBorrow(msg.sender, amount, fraction);
    }

    // Deposits an amount of collateral from the caller
    function addCollateral(uint256 amount) public payable { addCollateralTo(amount, msg.sender); }
    function addCollateralTo(uint256 amount, address to) public payable {
        _addCollateralAmount(to, amount);
        bentoBox.deposit{value: msg.value}(collateral, msg.sender, amount);
    }

    function addCollateralFromBento(uint256 amount) public { addCollateralFromBentoTo(amount, msg.sender); }
    function addCollateralFromBentoTo(uint256 amount, address to) public {
        _addCollateralAmount(to, amount);
        bentoBox.transferFrom(collateral, msg.sender, address(this), amount);
    }

    // Deposits an amount of supply (the borrowable token) from the caller
    function addAsset(uint256 amount) public payable { addAssetTo(amount, msg.sender); }
    function addAssetTo(uint256 amount, address to) public payable {
        // Accrue interest before calculating pool amounts in _addAssetAmount
        accrue();
        _addAssetAmount(to, amount);
        bentoBox.deposit{value: msg.value}(asset, msg.sender, amount);
    }

    function addAssetFromBento(uint256 amount) public payable { addAssetFromBentoTo(amount, msg.sender); }
    function addAssetFromBentoTo(uint256 amount, address to) public payable {
        // Accrue interest before calculating pool amounts in _addAssetAmount
        accrue();
        _addAssetAmount(to, amount);
        bentoBox.transferFrom(asset, msg.sender, address(this), amount);
    }

    // Withdraws a amount of collateral of the caller to the specified address
    function removeCollateral(uint256 amount, address to) public {
        accrue();
        _removeCollateralAmount(msg.sender, amount);
        // Only allow withdrawing if user is solvent (in case of a closed liquidation)
        require(isSolvent(msg.sender, false), 'LendingPair: user insolvent');
        bentoBox.withdraw(collateral, to, amount);
    }

    function removeCollateralToBento(uint256 amount, address to) public {
        accrue();
        _removeCollateralAmount(msg.sender, amount);
        // Only allow withdrawing if user is solvent (in case of a closed liquidation)
        require(isSolvent(msg.sender, false), 'LendingPair: user insolvent');
        bentoBox.transfer(collateral, to, amount);
    }

    // Withdraws a amount of supply (the borrowable token) of the caller to the specified address
    function removeAsset(uint256 fraction, address to) public {
        // Accrue interest before calculating pool amounts in _removeAssetFraction
        accrue();
        uint256 amount = _removeAssetFraction(msg.sender, fraction);
        bentoBox.withdraw(asset, to, amount);
    }

    function removeAssetToBento(uint256 fraction, address to) public {
        // Accrue interest before calculating pool amounts in _removeAssetFraction
        accrue();
        uint256 amount = _removeAssetFraction(msg.sender, fraction);
        bentoBox.transfer(asset, to, amount);
    }

    // Borrows the given amount from the supply to the specified address
    function borrow(uint256 amount, address to) public {
        accrue();
        bentoBox.withdraw(asset, to, amount); // TODO: reentrancy issue?
        uint256 feeAmount = amount.mul(borrowOpeningFee) / 1e5; // A flat % fee is charged for any borrow
        _addBorrowAmount(msg.sender, amount.add(feeAmount));
        totalAsset.amount = totalAsset.amount.add(feeAmount.to128());
        require(isSolvent(msg.sender, false), 'LendingPair: user insolvent');
    }

    function borrowToBento(uint256 amount, address to) public {
        accrue();
        bentoBox.transfer(asset, to, amount);
        uint256 feeAmount = amount.mul(borrowOpeningFee) / 1e5; // A flat % fee is charged for any borrow
        _addBorrowAmount(msg.sender, amount.add(feeAmount));
        totalAsset.amount = totalAsset.amount.add(feeAmount.to128());
        require(isSolvent(msg.sender, false), 'LendingPair: user insolvent');
    }

    // Repays the given fraction
    function repay(uint256 fraction) public { repayFor(fraction, msg.sender); }
    function repayFor(uint256 fraction, address beneficiary) public {
        accrue();
        uint256 amount = _removeBorrowFraction(beneficiary, fraction);
        bentoBox.deposit(asset, msg.sender, amount);
    }

    function repayFromBento(uint256 fraction) public { repayFromBentoTo(fraction, msg.sender); }
    function repayFromBentoTo(uint256 fraction, address beneficiary) public {
        accrue();
        uint256 amount = _removeBorrowFraction(beneficiary, fraction);
        bentoBox.transferFrom(asset, msg.sender, address(this), amount);
    }

    // Handles shorting with an approved swapper
    function short(ISwapper swapper, uint256 assetAmount, uint256 minCollateralAmount) public {
        require(masterContract.swappers(swapper), 'LendingPair: Invalid swapper');
        accrue();
        _addBorrowAmount(msg.sender, assetAmount);
        bentoBox.transferFrom(asset, address(this), address(swapper), assetAmount);

        // Swaps the borrowable asset for collateral
        swapper.swap(asset, collateral, assetAmount, minCollateralAmount);
        uint256 returnedCollateralAmount = bentoBox.skim(collateral);
        require(returnedCollateralAmount >= minCollateralAmount, 'LendingPair: not enough collateral returned');
        _addCollateralAmount(msg.sender, returnedCollateralAmount);

        require(isSolvent(msg.sender, false), 'LendingPair: user insolvent');
    }

    // Handles unwinding shorts with an approved swapper
    function unwind(ISwapper swapper, uint256 borrowFraction, uint256 maxAmountCollateral) public {
        require(masterContract.swappers(swapper), 'LendingPair: Invalid swapper');
        accrue();
        bentoBox.transferFrom(collateral, address(this), address(swapper), maxAmountCollateral);

        uint256 borrowAmount = _removeBorrowFraction(msg.sender, borrowFraction);

        // Swaps the collateral back for the borrowal asset
        uint256 usedAmount = swapper.swapExact(collateral, asset, maxAmountCollateral, borrowAmount, address(this));
        uint256 returnedAssetAmount = bentoBox.skim(asset);
        require(returnedAssetAmount >= borrowAmount, 'LendingPair: Not enough assets returned');

        _removeCollateralAmount(msg.sender, maxAmountCollateral.sub(usedAmount));

        require(isSolvent(msg.sender, false), 'LendingPair: user insolvent');
    }

    // Handles the liquidation of users' balances, once the users' amount of collateral is too low
    function liquidate(address[] calldata users, uint256[] calldata borrowFractions, address to, ISwapper swapper, bool open) public {
        accrue();
        updateExchangeRate();

        uint256 allCollateralAmount;
        uint256 allBorrowAmount;
        uint256 allBorrowFraction;
        TokenTotals memory _totalBorrow = totalBorrow;
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            if (!isSolvent(user, open)) {
                // Gets the user's amount of the total borrowed amount
                uint256 borrowFraction = borrowFractions[i];
                // Calculates the user's amount borrowed
                uint256 borrowAmount = borrowFraction.mul(_totalBorrow.amount) / _totalBorrow.fraction;
                // Calculates the amount of collateral that's going to be swapped for the asset
                uint256 collateralAmount = borrowAmount.mul(liquidationMultiplier).mul(exchangeRate) / 1e23;

                // Removes the amount of collateral from the user's balance
                userCollateralAmount[user] = userCollateralAmount[user].sub(collateralAmount);
                // Removes the amount of user's borrowed tokens from the user
                userBorrowFraction[user] = userBorrowFraction[user].sub(borrowFraction);
                emit LogRemoveCollateral(user, collateralAmount);
                emit LogRemoveBorrow(user, borrowAmount, borrowFraction);

                // Keep totals
                allCollateralAmount = allCollateralAmount.add(collateralAmount);
                allBorrowAmount = allBorrowAmount.add(borrowAmount);
                allBorrowFraction = allBorrowFraction.add(borrowFraction);
            }
        }
        require(allBorrowAmount != 0, 'LendingPair: all users are solvent');
        _totalBorrow.amount = _totalBorrow.amount.sub(allBorrowAmount.to128());
        _totalBorrow.fraction = _totalBorrow.fraction.sub(allBorrowFraction.to128());
        totalBorrow = _totalBorrow;
        totalCollateralAmount = totalCollateralAmount.sub(allCollateralAmount);

        if (!open) {
            // Closed liquidation using a pre-approved swapper for the benefit of the LPs
            require(masterContract.swappers(swapper), 'LendingPair: Invalid swapper');

            // Swaps the users' collateral for the borrowed asset
            bentoBox.transferFrom(collateral, address(this), address(swapper), allCollateralAmount);
            swapper.swap(collateral, asset, allCollateralAmount, allBorrowAmount);
            uint256 returnedAssetAmount = bentoBox.skim(asset);
            uint256 extraAssetAmount = returnedAssetAmount.sub(allBorrowAmount);

            // The extra asset gets added to the pool
            uint256 feeAmount = extraAssetAmount.mul(protocolFee) / 1e5; // % of profit goes to fee
            accrueInfo.feesPendingAmount = accrueInfo.feesPendingAmount.add(feeAmount.to128());
            totalAsset.amount = totalAsset.amount.add(extraAssetAmount.sub(feeAmount).to128());
            emit LogAddAsset(address(0), extraAssetAmount, 0);
        } else if (address(swapper) == address(0)) {
            // Open liquidation directly using the caller's funds, without swapping using token transfers
            bentoBox.deposit(asset, msg.sender, allBorrowAmount);
            bentoBox.withdraw(collateral, to, allCollateralAmount);
        } else if (address(swapper) == address(1)) {
            // Open liquidation directly using the caller's funds, without swapping using funds in BentoBox
            bentoBox.transferFrom(asset, msg.sender, address(this), allBorrowAmount);
            bentoBox.transfer(collateral, to, allCollateralAmount);
        } else {
            // Swap using a swapper freely chosen by the caller
            // Open (flash) liquidation: get proceeds first and provide the borrow after
            bentoBox.transferFrom(collateral, address(this), address(swapper), allCollateralAmount);
            swapper.swap(collateral, asset, allCollateralAmount, allBorrowAmount);
            uint256 returnedAssetAmount = bentoBox.skim(asset);
            uint256 extraAssetAmount = returnedAssetAmount.sub(allBorrowAmount);

            totalAsset.amount = totalAsset.amount.add(extraAssetAmount.to128());
            emit LogAddAsset(address(0), extraAssetAmount, 0);
        }
    }

    function batch(bytes[] calldata calls, bool revertOnFail) external payable returns(bool[] memory, bytes[] memory) {
        bool[] memory successes = new bool[](calls.length);
        bytes[] memory results = new bytes[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(calls[i]);
            require(success || !revertOnFail, 'LendingPair: Transaction failed');
            successes[i] = success;
            results[i] = result;
        }
        return (successes, results);
    }

    // Withdraws the fees accumulated
    function withdrawFees() public {
        accrue();
        address _feeTo = masterContract.feeTo();
        address _dev = masterContract.dev();
        uint256 feeAmount = accrueInfo.feesPendingAmount.sub(1);
        uint256 devFeeAmount = _dev == address(0) ? 0 : feeAmount.mul(devFee) / 1e5;
        accrueInfo.feesPendingAmount = 1; // Don't set it to 0 as that would increase the gas cost for the next accrue called by a user.
        bentoBox.withdraw(asset, _feeTo, feeAmount.sub(devFeeAmount));
        if (devFeeAmount > 0) {
            bentoBox.withdraw(asset, _dev, devFeeAmount);
        }
        emit LogWithdrawFees();
    }

    // Admin functions
    function setSwapper(ISwapper swapper, bool enable) public onlyOwner {
        swappers[swapper] = enable;
    }

    function setFeeTo(address newFeeTo) public onlyOwner
    {
        feeTo = newFeeTo;
        emit LogFeeTo(newFeeTo);
    }

    function setDev(address newDev) public
    {
        require(msg.sender == dev, 'LendingPair: Not dev');
        dev = newDev;
        emit LogDev(newDev);
    }

    function swipe(IERC20 token) public {
        require(msg.sender == masterContract.owner(), "LendingPair: caller is not the owner");

        if (address(token) == address(0)) {
            uint256 balanceETH = address(this).balance;
            if (balanceETH > 0) {
                (bool success,) = owner.call{value: balanceETH}(new bytes(0));
                require(success, "LendingPair: ETH transfer failed");
            }
        } else if (address(token) != address(asset) && address(token) != address(collateral)) {
            uint256 balanceAmount = token.balanceOf(address(this));
            if (balanceAmount > 0) {
                (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(0xa9059cbb, owner, balanceAmount));
                require(success && (data.length == 0 || abi.decode(data, (bool))), "LendingPair: Transfer failed at ERC20");
            }
        } else {
            uint256 excessAmount = bentoBox.balanceOf(token, address(this)).sub(token == asset ? totalAsset.amount : totalCollateralAmount);
            bentoBox.transfer(token, masterContract.owner(), excessAmount);
        }
    }
}
