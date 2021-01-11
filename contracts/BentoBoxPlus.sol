// SPDX-License-Identifier: UNLICENSED

// The BentoBox Plus

//  ▄▄▄▄· ▄▄▄ . ▐ ▄ ▄▄▄▄▄      ▄▄▄▄·       ▐▄• ▄ 
//  ▐█ ▀█▪▀▄.▀·█▌▐█•██  ▪     ▐█ ▀█▪▪      █▌█▌▪
//  ▐█▀▀█▄▐▀▀▪▄▐█▐▐▌ ▐█.▪ ▄█▀▄ ▐█▀▀█▄ ▄█▀▄  ·██· 
//  ██▄▪▐█▐█▄▄▌██▐█▌ ▐█▌·▐█▌.▐▌██▄▪▐█▐█▌.▐▌▪▐█·█▌ Plus!!
//  ·▀▀▀▀  ▀▀▀ ▀▀ █▪ ▀▀▀  ▀█▄▀▪·▀▀▀▀  ▀█▄▀▪•▀▀ ▀▀

// This contract stores funds, handles their transfers.

// Copyright (c) 2020 BoringCrypto - All rights reserved
// Twitter: @Boring_Crypto

// WARNING!!! DO NOT USE!!! UNDER DEVELOPMENT!!!

// solhint-disable avoid-low-level-calls
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@bartjman/boring-solidity/contracts/libraries/BoringERC20.sol";
import "@bartjman/boring-solidity/contracts/libraries/BoringRebase.sol";
import "@bartjman/boring-solidity/contracts/BoringFactory.sol";
import "@bartjman/boring-solidity/contracts/BoringBatchable.sol";
import "./interfaces/IWETH.sol";
import "./MasterContractManager.sol";
import "./StrategyManager.sol";

interface IFlashBorrowerLike {
    function onFlashLoan(address sender, address[] calldata tokens, uint256[] calldata amounts, uint256[] calldata fees, bytes calldata) external;
}

// Note: Rebasing tokens ARE NOT supported and WILL cause loss of funds
contract BentoBoxPlus is BoringFactory, MasterContractManager, BoringBatchable, StrategyManager {
    using BoringMath for uint256;
    using BoringMath128 for uint128;
    using BoringERC20 for IERC20;
    using RebaseLibrary for Rebase;

    // E1: OK
    event LogDeposit(IERC20 indexed token, address indexed from, address indexed to, uint256 amount, uint256 share);
    // E1: OK
    event LogWithdraw(IERC20 indexed token, address indexed from, address indexed to, uint256 amount, uint256 share);
    // E1: OK
    event LogTransfer(IERC20 indexed token, address indexed from, address indexed to, uint256 share);
    event LogFlashLoan(address indexed loaner, IERC20 indexed token, uint256 amount, uint256 feeAmount, address indexed receiver);

    // V2: Private to save gas, to verify it's correct, check the constructor arguments
    IERC20 private immutable wethToken;
    mapping(IERC20 => mapping(address => uint256)) public balanceOf; // Balance per token per address/contract
    mapping(IERC20 => Rebase) public totals;

    constructor(IERC20 wethToken_) public {
        wethToken = wethToken_;
    }

    function toShare(IERC20 token, uint256 amount) external view returns(uint256 share) {
        return totals[token].toShare(amount);
    }

    function toAmount(IERC20 token, uint256 share) external view returns(uint256 amount) {
        return totals[token].toAmount(share);
    }

    // M1 - M5: OK
    // C1 - C23: OK
    modifier allowed(address from) {
        if (from != msg.sender && from != address(this)) {
            address masterContract = masterContractOf[msg.sender];
            require(masterContract != address(0), "BentoBox: no masterContract");
            require(masterContractApproved[masterContract][from], "BentoBox: Transfer not approved");
        }
        _;
    }

    // F1 - F10: OK
    // F3: Combined deposit(s) and skim functions into one
    // C1 - C21: OK
    // C2: wethToken is used multiple times, but this is an immutable, so after construction it's hardcoded in the contract
    function deposit(
        IERC20 token_, address from, address to, uint256 amount, uint256 share
    ) public payable allowed(from) returns (uint256 amountOut, uint256 shareOut) {
        // Checks
        require(to != address(0) || from == address(this), "BentoBox: to not set"); // To avoid a bad UI from burning funds

        // Effects
        IERC20 token = token_ == IERC20(0) ? wethToken : token_;
        Rebase memory total = totals[token];

        // Skim
        if (from == address(this)) {
            // S1 - S4: OK
            amount = token_ == wethToken ? address(this).balance : token.balanceOf(address(this)).sub(total.amount);
            share = 0;
        }

        // S1 - S4: OK
        require(total.amount != 0 || token.totalSupply() > 0, "BentoBox: No tokens");
        if (share == 0) { share = total.toShare(amount); } else { amount = total.toAmount(share); }

        // If to is not address(0) add the share, otherwise skip this to take profit
        if (to != address(0)) {
            balanceOf[token][to] = balanceOf[token][to].add(share);
            total.share = total.share.add(share.to128());
        }
        total.amount = total.amount.add(amount.to128());
        totals[token] = total;

        // Interactions
        // During the first deposit, we check that this token is 'real'
        if (token_ == IERC20(0)) {
            // X1 - X5: OK
            // X2: If the WETH implementation is faulty or malicious, it will block adding ETH (but we know the WETH implementation)
            IWETH(address(wethToken)).deposit{value: amount}();
        } else if (from != address(this)) {
            // X1 - X5: OK
            // X2: If the token implementation is faulty or malicious, it will block adding tokens. Good.
            token.safeTransferFrom(from, address(this), amount);
        }
        emit LogDeposit(token, from, to, amount, share);
        amountOut = amount;
        shareOut = share;
    }

    // F1 - F10: OK
    // C1 - C22: OK
    // C2: wethToken is used multiple times, but this is an immutable, so after construction it's hardcoded in the contract
    function withdraw(
        IERC20 token_, address from, address to, uint256 amount, uint256 share
    ) public allowed(from) returns (uint256 amountOut, uint256 shareOut) {
        // Checks
        require(to != address(0), "BentoBox: to not set"); // To avoid a bad UI from burning funds

        // Effects
        IERC20 token = token_ == IERC20(0) ? wethToken : token_;
        Rebase memory total = totals[token];
        if (share == 0) { share = total.toShare(amount); } else { amount = total.toAmount(share); }

        balanceOf[token][from] = balanceOf[token][from].sub(share);
        total.amount = total.amount.sub(amount.to128());
        total.share = total.share.sub(share.to128());
        // There have to be at least 100000 shares left at all times to prevent reseting the share/amount ratio
        require(total.share >= 100000, "BentoBox: cannot empty");
        totals[token] = total;

        // Interactions
        if (token_ == IERC20(0)) {
            // X1 - X5: OK
            // X2, X3: A revert or big gas usage in the WETH contract could block withdrawals, but WETH9 is fine.
            IWETH(address(wethToken)).withdraw(amount);
            // X1 - X5: OK
            // X2, X3: A revert or big gas usage could block, however, the to address is under control of the caller.
            (bool success,) = to.call{value: amount}("");
            require(success, "BentoBox: ETH transfer failed");
        } else {
            // X1 - X5: OK
            // X2, X3: A malicious token could block withdrawal of just THAT token.
            //         masterContracts may want to take care not to rely on withdraw always succeeding.
            token.safeTransfer(to, amount);
        }
        emit LogWithdraw(token, from, to, amount, share);
        amountOut = amount;
        shareOut = share;
    }

    // *** Approved contract actions *** //
    // Clones of master contracts can transfer from any account that has approved them
    // F1 - F10: OK
    // F3: This isn't combined with transferMultiple for gas optimization
    // C1 - C23: OK
    function transfer(IERC20 token, address from, address to, uint256 share) public allowed(from) {
        // Checks
        require(to != address(0), "BentoBox: to not set"); // To avoid a bad UI from burning funds

        // Effects
        balanceOf[token][from] = balanceOf[token][from].sub(share);
        balanceOf[token][to] = balanceOf[token][to].add(share);

        emit LogTransfer(token, from, to, share);
    }

    // F1 - F10: OK
    // F3: This isn't combined with transfer for gas optimization
    // C1 - C23: OK
    function transferMultiple(IERC20 token, address from, address[] calldata tos, uint256[] calldata shares) public allowed(from) {
        // Checks
        require(tos[0] != address(0), "BentoBox: to[0] not set"); // To avoid a bad UI from burning funds

        // Effects
        uint256 totalAmount;
        uint256 len = tos.length;
        for (uint256 i=0; i < len; i++) {
            address to = tos[i];
            balanceOf[token][to] = balanceOf[token][to].add(shares[i]);
            totalAmount = totalAmount.add(shares[i]);
            emit LogTransfer(token, from, to, shares[i]);
        }
        balanceOf[token][from] = balanceOf[token][from].sub(totalAmount);
    }

    function flashSupply(address token) public view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function flashFee(address, uint256 amount) public pure returns (uint256) {
        return amount.mul(5) / 10000;
    }

    function flashLoan(address loaner, address[] calldata tokens, uint256[] calldata amounts, address[] calldata receivers, bytes calldata data) public {
        uint256[] memory fees = new uint256[](tokens.length);
        
        uint256 len = tokens.length;
        for (uint256 i = 0; i < len; i++) {
            uint256 amount = amounts[i];
            fees[i] = amount.mul(5) / 10000;

            IERC20(tokens[i]).safeTransfer(receivers[i], amounts[i]);
        }

        IFlashBorrowerLike(loaner).onFlashLoan(msg.sender, tokens, amounts, fees, data);

        for (uint256 i = 0; i < len; i++) {
            IERC20 token = IERC20(tokens[i]);
            Rebase memory total = totals[token];
            uint128 feeAmount = fees[i].to128();
            require(token.balanceOf(address(this)) == total.amount.add(feeAmount), "BentoBoxPlus: Wrong amount");
            total.amount = total.amount.add(feeAmount);
            totals[token] = total;
            emit LogFlashLoan(loaner, token, amounts[i], fees[i], receivers[i]);
        }
    }

    function _assetAdded(IERC20 token, IStrategy from, int256 amount) internal {
        if (amount > 0) {
            uint256 add = uint256(amount);
            totals[token].amount = totals[token].amount.add(add.to128());
            emit LogDeposit(token, address(from), address(this), add, 0);
        } else if (amount < 0) {
            uint256 sub = uint256(-amount);
            totals[token].amount = totals[token].amount.sub(sub.to128());
            emit LogWithdraw(token, address(this), address(from), sub, 0);
        }

    }

    function setStrategy(IERC20 token, IStrategy newStrategy) public onlyOwner {
        _assetAdded(token, strategy[token].strategy, _setStrategy(token, newStrategy));
    }

    function harvest(IERC20 token) public {
        _assetAdded(token, strategy[token].strategy, strategy[token].strategy.harvest());
    }

    function balanceStrategy(IERC20 token) public onlyOwner {
        harvest(token);
        _assetAdded(token, strategy[token].strategy, _balanceStrategy(token));
    }

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}
}
