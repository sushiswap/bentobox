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

// WARNING!!! DO NOT USE!!! NOT YET AUDITED!!!
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
import "./interfaces/IMasterContract.sol";
import "./interfaces/ISwapper.sol";

// TODO: check all reentrancy paths
// TODO: what to do when the entire pool is underwater?
// TODO: ensure BoringMath is always used
// TODO: turn magic number back into constants
// TODO: check that all actions on a users funds can only be initiated by that user as msg.sender
// We do allow supplying assets and borrowing, but the asset does NOT provide collateral as it's just silly and no UI should allow this

contract LendingPair is ERC20, Ownable, IMasterContract {
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
        // TODO: protect against revert in asset.decimals. Default to 18.
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

    uint256 public constant minimumInterestPerBlock = 1141552511; // 0.25% APR
    uint256 public constant maximumInterestPerBlock = 4566210045000;  // 1000% APR

    uint256 public constant liquidationMultiplier = 112000; // add 12%

    uint256 public constant protocolFee = 10; // 10%
    uint256 public constant devFee = 10; // 10% of the protocolFee = 1%
    uint256 public constant borrowOpeningFee = 5; // 0.05%

    // Serves as the constructor, as clones can't have a regular constructor
    function init(address bentoBox_, address masterContract_, bytes calldata data) public override {
        require(address(bentoBox) == address(0), 'LendingPair: already initialized');
        bentoBox = BentoBox(bentoBox_);
        masterContract = LendingPair(masterContract_);
        (collateral, asset, oracle, oracleData) = abi.decode(data, (IERC20, IERC20, IOracle, bytes));

        interestPerBlock = 4566210045;  // 1% APR, with 1e18 being 100%
        lastInterestBlock = block.number;
    }

    function getInitData(IERC20 collateral_, IERC20 asset_, IOracle oracle_, bytes calldata oracleData_) public pure returns(bytes memory data) {
        return abi.encode(collateral_, asset_, oracle_, oracleData_);
    }

    function setSwapper(ISwapper swapper, bool enable) public onlyOwner {
        swappers[swapper] = enable;
    }

    function swipe(IERC20 token) public onlyOwner {
        // swipe ETH
            // no payable functions in contract
            // only way this contract could contain ETH is when it was on the address before deployment
            // or a contract destructs itself and send the remains to this address

        // swipe token
        IERC20 token = IERC20(token);
        token.transfer(owner, token.balanceOf(address(this)));
        
        // swipe excess box balance
            // we use share as totalSupply, so there can never be excessive supply
            // if some-one deposits into BentoBox giving the Pair as "to", then funds are shared among all LPs
    }

    function setFeeTo(address newFeeTo) public onlyOwner { feeTo = newFeeTo; }
    function setDev(address newDev) public { require(msg.sender == dev, 'LendingPair: Not dev'); dev = newDev; }

    // Accrues the interest on the borrowed tokens and handles the accumulation of fees
    function accrue() public {
        // Number of blocks since accrue was called
        uint256 blocks = block.number - lastBlockAccrued;
        if (blocks == 0) {return;}
        lastBlockAccrued = block.number;

        if (totalBorrowShare > 0) {
            // Accrue interest
            uint256 extraShare = totalBorrowShare.mul(interestPerBlock).mul(blocks) / 1e18;
            uint256 feeShare = extraShare.mul(protocolFee) / 100; // % of interest paid goes to fee
            totalBorrowShare = totalBorrowShare.add(extraShare);
            totalAssetShare = totalAssetShare.add(extraShare.sub(feeShare));
            feesPendingShare = feesPendingShare.add(feeShare);
        }

        if (totalAssetShare == 0) {return;}

        // Update interest rate
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
            if (newInterestPerBlock > maximumInterestPerBlock) {newInterestPerBlock = maximumInterestPerBlock;} // 1000% APR maximum
        } else {return;}

        interestPerBlock = newInterestPerBlock;
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

    function totalSupply() external view returns (uint256) {
        uint256 totalAssetFraction = bentoBox.shareOf(asset, address(this));
        return totalAssetFraction.add(totalBorrowFraction);
    }

    function totalCollateralShare() external view returns (uint256) {
        return bentoBox.shareOf(collateral, address(this));
    }

    // Checks if the user is solvent.
    // Has an option to check if the user is solvent in an open/closed liquidation case.
    function isSolvent(address user, bool open) public view returns (bool) {
        // accrue must have already been called!
        if (userBorrowFraction[user] == 0) return true;
        if (bentoBox.shareOf(collateral, address(this)) == 0) return false;

        uint256 borrow = userBorrowFraction[user].mul(totalBorrowShare) / totalBorrowFraction;

        return bentoBox.toAmount(collateral, userCollateralShare[user])
            .mul(1e18).mul(open ? openCollaterizationRate : closedCollaterizationRate) /
            exchangeRate / 1e5 >= bentoBox.toAmount(asset, borrow);
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

    // Handles internal variable updates when collateral is deposited
    function _addCollateralShare(address user, uint256 share) private {
        // Adds this share to user
        userCollateralShare[user] = userCollateralShare[user].add(share);
        emit AddCollateral(msg.sender, share);
    }

    // Handles internal variable updates when supply (the borrowable token) is deposited
    function _addAssetShare(address user, uint256 share) private {
        // Calculates what share of the pool the user gets for the amount deposited
        uint256 totalSupplyBeforeDeposit = bentoBox.shareOf(asset, address(this)).sub(share);
        uint256 newFraction = totalSupplyBeforeDeposit == 0 ? share : share.mul(totalSupplyBeforeDeposit) / totalAssetShare;
        // Adds this share to user
        balanceOf[user] = balanceOf[user].add(newFraction);
        // Adds the amount deposited to the total of supply
        totalAssetShare = totalAssetShare.add(share);
        emit AddAsset(msg.sender, share, newFraction);
    }

    // Handles internal variable updates when supply (the borrowable token) is borrowed
    function _addBorrowShare(address user, uint256 share) private {
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
        emit RemoveCollateral(msg.sender, share);
    }

    // Handles internal variable updates when supply is withdrawn and returns the amount of supply withdrawn
    function _removeAssetFraction(address user, uint256 fraction) private returns (uint256 share) {
        // Subtracts the fraction from user
        balanceOf[user] = balanceOf[user].sub(fraction);
        // Calculates the share of tokens to withdraw
        share = fraction.mul(totalAssetShare) / bentoBox.shareOf(asset, address(this));
        // Subtracts the share from the total of supply shares
        totalAssetShare = totalAssetShare.sub(share);
        emit RemoveAsset(msg.sender, share, fraction);
    }

    // Handles internal variable updates when supply is repaid
    function _removeBorrowFraction(address user, uint256 fraction) private returns (uint256 share) {
        // Subtracts the fraction from user
        userBorrowFraction[user] = userBorrowFraction[user].sub(fraction);
        // Calculates the share of tokens to repay
        share = fraction.mul(totalBorrowShare) / totalBorrowFraction;
        // Subtracts the fraction from the total of shares borrowed
        totalBorrowFraction = totalBorrowFraction.sub(fraction);
        // Subtracts the calculated share from the total share borrowed
        totalBorrowShare = totalBorrowShare.sub(share);
        emit RemoveBorrow(msg.sender, share, fraction);
    }

    // Deposits an amount of collateral from the caller
    function addCollateral(uint256 amount) public payable {
        _addCollateralShare(msg.sender, bentoBox.deposit{value: msg.value}(collateral, msg.sender, amount));
    }

    // Deposits an amount of supply (the borrowable token) from the caller
    function addAsset(uint256 amount) public payable {
        // Accrue interest before calculating pool shares in _addAssetShare
        accrue();
        _addAssetShare(msg.sender, bentoBox.deposit{value: msg.value}(asset, msg.sender, amount));
    }

    // Withdraws a share of collateral of the caller to the specified address
    function removeCollateral(uint256 share, address to) public {
        accrue();
        _removeCollateralShare(msg.sender, share);
        // Only allow withdrawing if user is solvent (in case of a closed liquidation)
        require(isSolvent(msg.sender, false), 'LendingPair: user insolvent');
        bentoBox.withdrawShare(collateral, to, share);
    }

    // Withdraws a share of supply (the borrowable token) of the caller to the specified address
    function removeAsset(uint256 fraction, address to) public {
        // Accrue interest before calculating pool shares in _removeAssetFraction
        accrue();
        uint256 share = _removeAssetFraction(msg.sender, fraction);
        bentoBox.withdrawShare(asset, to, share);
    }

    // Borrows the given amount from the supply to the specified address
    function borrow(uint256 amount, address to) public {
        accrue();
        uint256 share = bentoBox.withdraw(asset, to, amount); // TODO: reentrancy issue?
        uint256 feeShare = share.mul(borrowOpeningFee) / 10000; // A flat 0.05% fee is charged for any borrow
        _addBorrowShare(msg.sender, share.add(feeShare));
        totalAssetShare = totalAssetShare.add(feeShare);
        require(isSolvent(msg.sender, false), 'LendingPair: user insolvent');
    }

    // Repays the given fraction
    function repay(uint256 fraction) public {
        accrue();
        uint256 share = _removeBorrowFraction(msg.sender, fraction);
        bentoBox.depositShare(asset, msg.sender, share);
    }

    // Handles shorting with an approved swapper
    function short(ISwapper swapper, uint256 assetShare, uint256 minCollateralShare) public {
        require(masterContract.swappers(swapper), 'LendingPair: Invalid swapper');
        accrue();
        _addBorrowShare(msg.sender, assetShare);
        uint256 suppliedAssetAmount = bentoBox.transferShareFrom(asset, address(this), address(swapper), assetShare);

        // Swaps the borrowable asset for collateral
        swapper.swap(asset, collateral, suppliedAssetAmount, bentoBox.toAmount(collateral, minCollateralShare));
        uint256 returnedCollateralShare = bentoBox.skim(collateral);
        require(returnedCollateralShare >= minCollateralShare, 'LendingPair: not enough collateral returned');
        _addCollateralShare(msg.sender, returnedCollateralShare);

        require(isSolvent(msg.sender, false), 'LendingPair: user insolvent');
    }

    // Handles unwinding shorts with an approved swapper
    function unwind(ISwapper swapper, uint256 borrowShare, uint256 maxAmountCollateral) public {
        require(masterContract.swappers(swapper), 'LendingPair: Invalid swapper');
        accrue();
        uint256 suppliedAmount = bentoBox.transferShareFrom(collateral, address(this), address(swapper), maxAmountCollateral);

        uint256 borrowAmount = _removeBorrowFraction(msg.sender, borrowShare);

        // Swaps the collateral back for the borrowal asset
        uint256 usedAmount = swapper.swapExact(collateral, asset, suppliedAmount, bentoBox.toAmount(asset, borrowAmount), address(this));
        uint256 returnedAssetShare = bentoBox.skim(asset);
        require(returnedAssetShare >= borrowShare, 'LendingPair: Not enough assets returned');

        _removeCollateralShare(msg.sender, suppliedAmount.sub(usedAmount));

        require(isSolvent(msg.sender, false), 'LendingPair: user insolvent');
    }

    // Handles the liquidation of users' balances, once the users' amount of collateral is too low
    function liquidate(address[] calldata users, uint256[] calldata borrowFractions, address to, ISwapper swapper, bool open) public {
        accrue();
        updateExchangeRate();

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
                uint256 collateralShare = bentoBox.toShare(collateral, (bentoBox.toAmount(asset, borrowShare).mul(liquidationMultiplier).mul(exchangeRate) / 1e23));

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
        require(allBorrowShare != 0, 'LendingPair: all users are solvent');
        totalBorrowShare = totalBorrowShare.sub(allBorrowShare);
        totalBorrowFraction = totalBorrowFraction.sub(allBorrowFraction);

        if (!open) {
            // Closed liquidation using a pre-approved swapper for the benefit of the LPs
            require(masterContract.swappers(swapper), 'LendingPair: Invalid swapper');

            // Swaps the users' collateral for the borrowed asset
            uint256 suppliedAmount = bentoBox.transferShareFrom(collateral, address(this), address(swapper), allCollateralShare);
            swapper.swap(collateral, asset, suppliedAmount, bentoBox.toAmount(asset, allBorrowShare));
            uint256 returnedAssetShare = bentoBox.skim(asset);
            uint256 extraAssetShare = returnedAssetShare.sub(allBorrowShare);

            // The extra asset gets added to the pool
            uint256 feeShare = extraAssetShare.mul(protocolFee) / 100; // % of profit goes to fee
            feesPendingShare = feesPendingShare.add(feeShare);
            totalAssetShare = totalAssetShare.add(extraAssetShare.sub(feeShare));
            emit AddAsset(address(0), extraAssetShare, 0);
        } else if (address(swapper) == address(0)) {
            // Open liquidation directly using the caller's funds, without swapping using token transfers
            bentoBox.depositShare(asset, msg.sender, allBorrowShare);
            bentoBox.withdrawShare(collateral, to, allCollateralShare);
        } else if (address(swapper) == address(1)) {
            // Open liquidation directly using the caller's funds, without swapping using funds in BentoBox
            bentoBox.transferShareFrom(asset, msg.sender, to, allBorrowShare);
            bentoBox.transferShare(collateral, to, allCollateralShare);
        } else {
            // Swap using a swapper freely chosen by the caller
            // Open (flash) liquidation: get proceeds first and provide the borrow after
            uint256 suppliedAmount = bentoBox.transferShareFrom(collateral, address(this), address(swapper), allCollateralShare);
            swapper.swap(collateral, asset, suppliedAmount, bentoBox.toAmount(asset, allBorrowShare));
            uint256 returnedAssetShare = bentoBox.skim(asset);
            uint256 extraAsset = returnedAssetShare.sub(allBorrowShare);

            totalAssetShare = totalAssetShare.add(extraAsset);
            emit AddAsset(address(0), extraAsset, 0);
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

    function swipe(IERC20 token) public onlyOwner {
        if (address(token) == address(0)) {
            uint256 balanceETH = address(this).balance;
            if (balanceETH > 0) {
                IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).withdraw(balanceETH);
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
            uint256 excessShare = bentoBox.shareOf(token, address(this)).sub(token == asset ? totalAssetShare : totalCollateralShare);
            bentoBox.transferShare(token, owner, excessShare);
        }
    }    
}
