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

// solhint-disable avoid-low-level-calls

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@boringcrypto/boring-solidity/contracts/libraries/BoringMath.sol";
import "@boringcrypto/boring-solidity/contracts/BoringOwnable.sol";
import "@boringcrypto/boring-solidity/contracts/ERC20.sol";
import "@boringcrypto/boring-solidity/contracts/interfaces/IMasterContract.sol";
import "./interfaces/IOracle.sol";
import "./BentoBoxPlus.sol";
import "./interfaces/ISwapper.sol";
import "./interfaces/IWETH.sol";

// TODO: check all reentrancy paths
// TODO: what to do when the entire pool is underwater?
// TODO: check that all actions on a users funds can only be initiated by that user as msg.sender

contract LendingPair is ERC20, BoringOwnable, BoringBatchable, IMasterContract {
    using BoringMath for uint256;
    using BoringMath128 for uint128;
    using RebaseLibrary for Rebase;

    // MasterContract variables
    BentoBoxPlus public immutable bentoBox;
    LendingPair public immutable masterContract;
    address public feeTo;
    mapping(ISwapper => bool) public swappers;

    // Per clone variables
    // Clone settings
    IERC20 public collateral;
    IERC20 public asset;
    IOracle public oracle;
    bytes public oracleData;

    // User balances
    mapping(address => uint256) public userCollateralShare;
    // userAssetFraction is called balanceOf for ERC20 compatibility
    mapping(address => uint256) public userBorrowPart;

    // Total amounts
    uint256 public totalCollateralShare;
    Rebase public totalAsset; // The total assets belonging to the suppliers (including any borrowed amounts).
    Rebase public totalBorrow; // Total units of asset borrowed

    // totalSupply for ERC20 compatibility
    function totalSupply() public view returns(uint256) {
        return totalAsset.base;
    }

    // Exchange and interest rate tracking
    uint256 public exchangeRate;

    struct AccrueInfo {
        uint64 interestPerBlock;
        uint64 lastBlockAccrued;
        uint128 feesEarnedFraction;
    }
    uint256 public feesPaidAmount;
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
    event LogAccrue(uint256 accruedAmount, uint256 feeFraction, uint256 rate, uint256 utilization);
    event LogAddCollateral(address indexed user, uint256 share);
    event LogAddAsset(address indexed user, uint256 share, uint256 fraction);
    event LogAddBorrow(address indexed user, uint256 amount, uint256 part);
    event LogRemoveCollateral(address indexed user, uint256 share);
    event LogRemoveAsset(address indexed user, uint256 share, uint256 fraction);
    event LogRemoveBorrow(address indexed user, uint256 amount, uint256 part);
    event LogFeeTo(address indexed newFeeTo);
    event LogWithdrawFees();

    constructor(BentoBoxPlus bentoBox_) public {
        bentoBox = bentoBox_;
        masterContract = LendingPair(this);
        feeTo = msg.sender;
        emit LogFeeTo(msg.sender);

        // Not really an issue, but https://blog.trailofbits.com/2020/12/16/breaking-aave-upgradeability/
        collateral = IERC20(address(1));
    }
    
    // Settings for the Medium Risk LendingPair
    uint256 private constant CLOSED_COLLATERIZATION_RATE = 75000; // 75%
    uint256 private constant OPEN_COLLATERIZATION_RATE = 77000; // 77%
    uint256 private constant MINIMUM_TARGET_UTILIZATION = 7e17; // 70%
    uint256 private constant MAXIMUM_TARGET_UTILIZATION = 8e17; // 80%

    uint256 private constant STARTING_INTEREST_PER_BLOCK = 4566210045; // approx 1% APR
    uint256 private constant MINIMUM_INTEREST_PER_BLOCK = 1141552511; // approx 0.25% APR
    uint256 private constant MAXIMUM_INTEREST_PER_BLOCK = 4566210045000;  // approx 1000% APR
    uint256 private constant INTEREST_ELASTICITY = 2000e36; // Half or double in 2000 blocks (approx 8 hours)

    uint256 private constant LIQUIDATION_MULTIPLIER = 112000; // add 12%

    // Fees
    uint256 private constant PROTOCOL_FEE = 10000; // 10%
    uint256 private constant DEV_FEE = 10000; // 10% of the PROTOCOL_FEE = 1%
    uint256 private constant BORROW_OPENING_FEE = 50; // 0.05%

    // Serves as the constructor, as clones can't have a regular constructor
    function init(bytes calldata data) public payable override {
        require(address(collateral) == address(0), "LendingPair: already initialized");
        (collateral, asset, oracle, oracleData) = abi.decode(data, (IERC20, IERC20, IOracle, bytes));

        accrueInfo.interestPerBlock = uint64(STARTING_INTEREST_PER_BLOCK);  // 1% APR, with 1e18 being 100%
        updateExchangeRate();
    }

    function getInitData(IERC20 collateral_, IERC20 asset_, IOracle oracle_, bytes calldata oracleData_) public pure returns(bytes memory data) {
        return abi.encode(collateral_, asset_, oracle_, oracleData_);
    }

    function setApproval(address user, bool approved, uint8 v, bytes32 r, bytes32 s) external {
        bentoBox.setMasterContractApproval(user, address(masterContract), approved, v, r, s);
    }

    function deposit(IERC20 token, address to, uint256 amount, uint256 share) public payable returns (uint256 amountOut, uint256 shareOut) {
        return bentoBox.deposit(token, msg.sender, to, amount, share);
    }

    // TODO: Add more bentobox wrappers

    // Accrues the interest on the borrowed tokens and handles the accumulation of fees
    function accrue() public {
        AccrueInfo memory _accrueInfo = accrueInfo;
        // Number of blocks since accrue was called
        uint256 blocks = block.number - _accrueInfo.lastBlockAccrued;
        if (blocks == 0) {return;}
        _accrueInfo.lastBlockAccrued = uint64(block.number);

        uint256 extraAmount = 0;
        uint256 feeFraction = 0;

        Rebase memory _totalBorrow = totalBorrow;
        Rebase memory _totalAsset = totalAsset;
        if (_totalAsset.base == 0) {
            if (_accrueInfo.interestPerBlock != STARTING_INTEREST_PER_BLOCK) {
                _accrueInfo.interestPerBlock = uint64(STARTING_INTEREST_PER_BLOCK);
                emit LogAccrue(0, 0, STARTING_INTEREST_PER_BLOCK, 0);
            }
            return;
        }

        uint256 totalAssetAmount = bentoBox.toAmount(asset, _totalAsset.base);
        if (_totalBorrow.elastic > 0) {
            // Accrue interest
            extraAmount = uint256(_totalBorrow.elastic).mul(_accrueInfo.interestPerBlock).mul(blocks) / 1e18;
            uint256 feeAmount = extraAmount.mul(PROTOCOL_FEE) / 1e5; // % of interest paid goes to fee
            _totalBorrow.elastic = _totalBorrow.elastic.add(extraAmount.to128());
            feeFraction = feeAmount.mul(_totalAsset.base) / totalAssetAmount.add(_totalBorrow.elastic).sub(feeAmount);
            _accrueInfo.feesEarnedFraction = _accrueInfo.feesEarnedFraction.add(feeFraction.to128());
            _totalAsset.base = _totalAsset.base.add(feeFraction.to128());
            totalBorrow = _totalBorrow;
        }

        // Update interest rate
        uint256 utilization = uint256(_totalBorrow.elastic).mul(1e18) / totalAssetAmount.add(_totalBorrow.elastic);
        uint256 newInterestPerBlock;
        if (utilization < MINIMUM_TARGET_UTILIZATION) {
            uint256 underFactor = MINIMUM_TARGET_UTILIZATION.sub(utilization).mul(1e18) / MINIMUM_TARGET_UTILIZATION;
            uint256 scale = INTEREST_ELASTICITY.add(underFactor.mul(underFactor).mul(blocks));
            newInterestPerBlock = uint256(_accrueInfo.interestPerBlock).mul(INTEREST_ELASTICITY) / scale;
            if (newInterestPerBlock < MINIMUM_INTEREST_PER_BLOCK) {newInterestPerBlock = MINIMUM_INTEREST_PER_BLOCK;} // 0.25% APR minimum
       } else if (utilization > MAXIMUM_TARGET_UTILIZATION) {
            uint256 overFactor = utilization.sub(MAXIMUM_TARGET_UTILIZATION).mul(1e18) / uint256(1e18).sub(MAXIMUM_TARGET_UTILIZATION);
            uint256 scale = INTEREST_ELASTICITY.add(overFactor.mul(overFactor).mul(blocks));
            newInterestPerBlock = uint256(_accrueInfo.interestPerBlock).mul(scale) / INTEREST_ELASTICITY;
            if (newInterestPerBlock > MAXIMUM_INTEREST_PER_BLOCK) {newInterestPerBlock = MAXIMUM_INTEREST_PER_BLOCK;} // 1000% APR maximum
        } else {
            emit LogAccrue(extraAmount, feeFraction, _accrueInfo.interestPerBlock, utilization);
            accrueInfo = _accrueInfo; return;
        }

        _accrueInfo.interestPerBlock = uint64(newInterestPerBlock);
        emit LogAccrue(extraAmount, feeFraction, newInterestPerBlock, utilization);
        accrueInfo = _accrueInfo;
    }

    // Checks if the user is solvent.
    // Has an option to check if the user is solvent in an open/closed liquidation case.
    function isSolvent(address user, bool open) public view returns (bool) {
        // accrue must have already been called!
        if (userBorrowPart[user] == 0) return true;
        if (totalCollateralShare == 0) return false;

        Rebase memory _totalBorrow = totalBorrow;

        return bentoBox.toAmount(
                collateral, 
                userCollateralShare[user].mul(1e13).mul(
                    open 
                    ? OPEN_COLLATERIZATION_RATE 
                    : CLOSED_COLLATERIZATION_RATE
                )
            ) >= 
            userBorrowPart[user]
                .mul(_totalBorrow.elastic)
                .mul(exchangeRate)
                / _totalBorrow.base;
    }

    modifier solvent() {
        _;
        require(isSolvent(msg.sender, false), "LendingPair: user insolvent");
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

    function _addTokens(IERC20 token, uint256 share, uint256 total, bool skim) internal {
        if(skim) {
            require(share <= bentoBox.balanceOf(token, address(this)).sub(total), "LendingPair: Skim too much");
        } else {
            bentoBox.transfer(token, msg.sender, address(this), share);
        }
    }

    function addCollateral(uint256 share, address to, bool skim) public {
        userCollateralShare[to] = userCollateralShare[to].add(share);
        totalCollateralShare = totalCollateralShare.add(share);
        _addTokens(collateral, share, totalCollateralShare, skim);
        emit LogAddCollateral(to, share);
    }

    function removeCollateral(uint256 share, address to) public solvent {
        accrue();
        userCollateralShare[msg.sender] = userCollateralShare[msg.sender].sub(share);
        totalCollateralShare = totalCollateralShare.sub(share);
        emit LogRemoveCollateral(msg.sender, share);
        bentoBox.transfer(collateral, address(this), to, share);
    }

    function addAsset(uint256 share, address to, bool skim) public returns (uint256 fraction) {
        accrue();
        (totalAsset, fraction) = totalAsset.add(share);
        balanceOf[to] = balanceOf[to].add(fraction);
        _addTokens(asset, share, totalAsset.elastic, skim);
        emit LogAddAsset(to, share, fraction);
    }

    function removeAsset(uint256 fraction, address to) public returns (uint256 share) {
        accrue();
        (totalAsset, share) = totalAsset.sub(fraction);
        balanceOf[msg.sender] = balanceOf[msg.sender].sub(fraction);
        emit LogRemoveAsset(msg.sender, share, fraction);

        bentoBox.transfer(asset, address(this), to, share);
    }

    function borrow(uint256 amount, address to) public solvent returns (uint256 part, uint256 actualAmount) {
        accrue();
        
        uint256 feeAmount = amount.mul(BORROW_OPENING_FEE) / 1e5; // A flat % fee is charged for any borrow
        totalAsset.elastic = totalAsset.elastic.add(bentoBox.toShare(asset, feeAmount).to128());
        
        (totalBorrow, part) = totalBorrow.add(amount.add(feeAmount));
        userBorrowPart[to] = userBorrowPart[to].add(part);
        emit LogAddBorrow(msg.sender, amount.add(feeAmount), part);

        actualAmount = bentoBox.toShare(asset, amount);
        bentoBox.transfer(asset, address(this), to, actualAmount);
    }

    function repay(uint256 part, address to, bool skim) public returns (uint256 amount) {
        accrue();
        (totalBorrow, amount) = totalBorrow.sub(part);
        userBorrowPart[to] = userBorrowPart[to].sub(part);
        _addTokens(asset, bentoBox.toShare(asset, amount), totalAsset.elastic, skim);
        emit LogRemoveBorrow(msg.sender, amount, part);
    }
    /*
    function leverage(
        address to,
        uint256 removeCollateralShare,
        uint256 removeAssetFraction,
        uint256 borrowAmount,
        ISwapper swapper,
        bytes calldata swapperData)
    public solvent {
        accrue();
        if (removeCollateralShare > 0) {
            removeCollateral(removeCollateralShare, to);
        }

        if (removeAssetFraction > 0) {
            removeAsset(removeAssetFraction, to);
        }

        if (borrowAmount> 0) {
            //borrow();
        }

        // Swap


    }
*/
    // Handles the liquidation of users' balances, once the users' amount of collateral is too low
    function liquidate(address[] calldata users, uint256[] calldata borrowParts, address to, ISwapper swapper, bool open) public {
        accrue();
        updateExchangeRate();

        uint256 allCollateralShare = 0;
        uint256 allBorrowAmount = 0;
        uint256 allBorrowPart = 0;
        Rebase memory _totalBorrow = totalBorrow;
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            if (!isSolvent(user, open)) {
                uint256 borrowPart = borrowParts[i];
                uint256 borrowAmount = _totalBorrow.toElastic(borrowPart);
                uint256 collateralShare = bentoBox.toShare(collateral, borrowAmount
                    .mul(LIQUIDATION_MULTIPLIER).mul(exchangeRate) / 1e23);

                userCollateralShare[user] = userCollateralShare[user].sub(collateralShare);
                userBorrowPart[user] = userBorrowPart[user].sub(borrowPart);
                emit LogRemoveCollateral(user, collateralShare);
                emit LogRemoveBorrow(user, borrowAmount, borrowPart);

                // Keep totals
                allCollateralShare = allCollateralShare.add(collateralShare);
                allBorrowAmount = allBorrowAmount.add(borrowAmount);
                allBorrowPart = allBorrowPart.add(borrowPart);
            }
        }
        require(allBorrowAmount != 0, "LendingPair: all are solvent");
        _totalBorrow.elastic = _totalBorrow.elastic.sub(allBorrowAmount.to128());
        _totalBorrow.base = _totalBorrow.base.sub(allBorrowPart.to128());
        totalBorrow = _totalBorrow;
        totalCollateralShare = totalCollateralShare.sub(allCollateralShare);

        if (!open) {
            // Closed liquidation using a pre-approved swapper for the benefit of the LPs
            require(masterContract.swappers(swapper), "LendingPair: Invalid swapper");

            // Swaps the users' collateral for the borrowed asset
            bentoBox.transfer(collateral, address(this), address(swapper), allCollateralShare);
            swapper.swap(collateral, asset, allCollateralShare, allBorrowAmount, address(this));
            
            uint256 extraShare = bentoBox.balanceOf(asset, address(this))
                .sub(totalAsset.elastic)
                .sub(bentoBox.toShare(asset, allBorrowAmount));
            
            uint256 feeShare = extraShare.mul(PROTOCOL_FEE) / 1e5; // % of profit goes to fee
            totalAsset.elastic = totalAsset.elastic.add(extraShare.sub(feeShare).to128());
            bentoBox.transfer(asset, address(this), masterContract.feeTo(), feeShare);
            emit LogAddAsset(address(0), extraShare.sub(feeShare), 0);
        } else {
            // Swap using a swapper freely chosen by the caller
            // Open (flash) liquidation: get proceeds first and provide the borrow after
            bentoBox.transfer(collateral, address(this), to, allCollateralShare);
            if (swapper != ISwapper(0)) {
                swapper.swap(collateral, asset, allCollateralShare, allBorrowAmount, msg.sender);
            }

            bentoBox.transfer(asset, msg.sender, address(this), allBorrowAmount);
        }
    }

    // Withdraws the fees accumulated
    /*function withdrawFees() public {
        accrue();
        address _feeTo = masterContract.feeTo();
        AccrueInfo memory _accrueInfo = accrueInfo;
        Rebase memory _totalAsset = totalAsset;
        
        uint256 _feeShare = _totalAsset.toShare(_accrueInfo.feesEarnedFraction);
        _totalAsset.fraction = _totalAsset.fraction.sub(_accrueInfo.feesEarnedFraction);
        _totalAsset.share = _totalAsset.share.sub(_feeShare);
        _accrueInfo.feesEarnedFraction = 0;
        accrueInfo = _accrueInfo;
        totalAsset = _totalAsset;

        bentoBox.transfer(asset, address(this), _feeTo, _feeShare);

        emit LogWithdrawFees();
    }*/

    // MasterContract Only Admin functions
    function setSwapper(ISwapper swapper, bool enable) public onlyOwner {
        swappers[swapper] = enable;
    }

    function setFeeTo(address newFeeTo) public onlyOwner
    {
        feeTo = newFeeTo;
        emit LogFeeTo(newFeeTo);
    }

    // Clone contract Admin functions - no error handling because it's admin
    function swipe(IERC20 token) public {
        require(msg.sender == masterContract.owner(), "LendingPair: caller is not owner");

        if (address(token) == address(0)) {
            msg.sender.call{value: address(this).balance}(new bytes(0));
        } else if (address(token) != address(asset) && address(token) != address(collateral)) {
            address(token).call(abi.encodeWithSelector(0xa9059cbb, msg.sender, token.balanceOf(address(this))));
        } else {
            // TODO: Fix for strategy
            uint256 excessAmount = bentoBox.balanceOf(token, address(this)).sub(token == asset ? totalAsset.elastic : totalCollateralShare);
            bentoBox.transfer(token, address(this), msg.sender, excessAmount);
        }
    }
}
