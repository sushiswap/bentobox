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

import "./libraries/BoringERC20.sol";
import "./libraries/BoringRebase.sol";
import "./interfaces/IWETH.sol";
import "./MasterContractManager.sol";
import "./BoringFactory.sol";
import "./BoringBatchable.sol";

interface IFlashLoaner {
    function executeOperation(IERC20[] calldata tokens, uint256[] calldata amounts, uint256[] calldata fees, bytes calldata params) external;
}

contract BentoBoxPlus is BoringFactory, MasterContractManager, BoringBatchable {
    using BoringMath for uint256;
    using BoringMath128 for uint128;
    using BoringERC20 for IERC20;
    using RebaseLibrary for Rebase;

    event LogDeposit(IERC20 indexed token, address indexed from, address indexed to, uint256 amount, uint256 share);
    event LogWithdraw(IERC20 indexed token, address indexed from, address indexed to, uint256 amount, uint256 share);
    event LogTransfer(IERC20 indexed token, address indexed from, address indexed to, uint256 share);
    event LogFlashLoan(address indexed receiver, IERC20 indexed token, uint256 amount, uint256 feeAmount, address indexed user);

    IERC20 private immutable wethToken;
    mapping(IERC20 => mapping(address => uint256)) public balanceOf; // Balance per token per address/contract
    mapping(IERC20 => Rebase) public totals;

    constructor(IERC20 wethToken_) public {
        wethToken = wethToken_;
    }

    modifier allowed(address from) {
        if (msg.sender != from) {
            address masterContract = masterContractOf[msg.sender];
            require(masterContract != address(0), "BentoBox: no masterContract");
            require(masterContractApproved[masterContract][from], "BentoBox: Transfer not approved");
        }
        _;
    }

    function deposit(
        IERC20 token_, address from, address to, uint256 amount, uint256 share
    ) public payable allowed(from) returns (uint256 amountOut, uint256 shareOut) {
        require(to != address(0), "BentoBox: to not set"); // To avoid a bad UI from burning funds
        IERC20 token = token_ == IERC20(0) ? wethToken : token_;
        Rebase memory total = totals[token];

        // During the first deposit, we check that this token is 'real'
        require(total.amount != 0 || token.totalSupply() > 0, "BentoBox: No tokens");
        if (share == 0) { share = total.toShare(amount); } else { amount = total.toAmount(share); }

        balanceOf[token][to] = balanceOf[token][to].add(share);
        total.amount = total.amount.add(amount.to128());
        total.share = total.share.add(share.to128());
        totals[token] = total;

        if (token_ == IERC20(0)) {
            IWETH(address(wethToken)).deposit{value: amount}();
        } else {
            token.safeTransferFrom(from, amount);
        }
        emit LogDeposit(token, from, to, amount, share);
        amountOut = amount;
        shareOut = share;
    }

    function withdraw(
        IERC20 token_, address from, address to, uint256 amount, uint256 share
    ) public allowed(from) returns (uint256 amountOut, uint256 shareOut) {
        require(to != address(0), "BentoBox: to not set"); // To avoid a bad UI from burning funds
        IERC20 token = token_ == IERC20(0) ? wethToken : token_;
        Rebase memory total = totals[token];
        if (share == 0) { share = total.toShare(amount); }
        else { amount = total.toAmount(share); }

        balanceOf[token][from] = balanceOf[token][from].sub(share);
        total.amount = total.amount.sub(amount.to128());
        total.share = total.share.sub(share.to128());
        // There have to be at least 10000 shares left at all times to prevent reseting the share/amount ratio
        require(total.share >= 10000, "BentoBox: cannot empty");
        totals[token] = total;

        if (token_ == wethToken) {
            IWETH(address(wethToken)).withdraw(amount);
            (bool success,) = to.call{value: amount}(new bytes(0));
            require(success, "BentoBox: ETH transfer failed");
        } else {
            _safeTransfer(token, to, amount);
        }
        emit LogWithdraw(token, from, to, amount, share);
    }

    function skim(IERC20 token_, address to) public returns (uint256 amount, uint256 share) {
        require(to != address(0), "BentoBox: to not set"); // To avoid a bad UI from burning funds
        IERC20 token = token_ == IERC20(0) ? wethToken : token_;
        if (token_ == wethToken) {
            IWETH(address(wethToken)).deposit{value: address(this).balance}();
        }

        Rebase memory total = totals[token];
        amount = token.balanceOf(address(this)).sub(total.amount);

        // Skim to address(0) to add profit
        if (to != address(0)) {
            share = total.toShare(amount);
            balanceOf[token][to] = balanceOf[token][to].add(share);
            total.share = total.share.add(share.to128());
        }

        total.amount = total.amount.add(amount.to128());
        totals[token] = total;

        emit LogDeposit(token, address(this), to, amount, share);
    }

    // *** Approved contract actions *** //
    // Clones of master contracts can transfer from any account that has approved them
    function transfer(IERC20 token, address from, address to, uint256 share) public allowed(from) {
        require(to != address(0), "BentoBox: to not set"); // To avoid a bad UI from burning funds
        balanceOf[token][from] = balanceOf[token][from].sub(share);
        balanceOf[token][to] = balanceOf[token][to].add(share);

        emit LogTransfer(token, from, to, share);
    }

    function transferMultiple(IERC20 token, address from, address[] calldata tos, uint256[] calldata shares) public allowed(from) {
        require(tos[0] != address(0), "BentoBox: to[0] not set"); // To avoid a bad UI from burning funds
        uint256 totalAmount;
        for (uint256 i=0; i < tos.length; i++) {
            address to = tos[i];
            balanceOf[token][to] = balanceOf[token][to].add(shares[i]);
            totalAmount = totalAmount.add(shares[i]);
            emit LogTransfer(token, from, to, shares[i]);
        }
        balanceOf[token][from] = balanceOf[token][from].sub(totalAmount);
    }

    // Take out a flash loan
    function flashLoan(address receiver, IERC20[] calldata tokens, uint256[] calldata amounts, address user, bytes calldata params) public {
        uint256[] memory feeAmounts = new uint256[](tokens.length);

        uint256 length = tokens.length;
        for (uint256 i = 0; i < length; i++) {
            uint256 amount = amounts[i];
            feeAmounts[i] = amount.mul(5) / 10000;

            _safeTransfer(tokens[i], receiver, amounts[i]);
        }

        IFlashLoaner(user).executeOperation(tokens, amounts, feeAmounts, params);

        for (uint256 i = 0; i < length; i++) {
            Rebase memory total = totals[tokens[i]];
            IERC20 token = tokens[i];
            uint128 feeAmount = feeAmounts[i].to128();
            require(token.balanceOf(address(this)) == total.amount.add(feeAmount), "BentoBoxPlus: Wrong amount");
            total.amount = total.amount.add(feeAmount);
            totals[token] = total;
            emit LogFlashLoan(receiver, token, amounts[i], feeAmounts[i], user);
        }
    }

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}
}
