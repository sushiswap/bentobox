// SPDX-License-Identifier: UNLICENSED

// The BentoBox Plus

//  ▄▄▄▄· ▄▄▄ . ▐ ▄ ▄▄▄▄▄      ▄▄▄▄·       ▐▄• ▄ 
//  ▐█ ▀█▪▀▄.▀·•█▌▐█•██  ▪     ▐█ ▀█▪▪      █▌█▌▪
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

import "./libraries/BoringRebase.sol";
import "./interfaces/IWETH.sol";
import "./MasterContractManager.sol";
import "./BoringFactory.sol";
import "./BoringBatchable.sol";

contract BentoBoxPlus is BoringFactory, MasterContractManager, BoringBatchable {
    using BoringMath for uint256;
    using BoringMath128 for uint128;
    using RebaseLibrary for Rebase;

    // solhint-disable-next-line var-name-mixedcase
    IERC20 public immutable WethToken;

    // solhint-disable-next-line var-name-mixedcase
    constructor(IERC20 WethToken_) public {
        WethToken = WethToken_;
    }

    event LogDeposit(IERC20 indexed token, address indexed from, address indexed to, uint256 amount, uint256 share);
    event LogWithdraw(IERC20 indexed token, address indexed from, address indexed to, uint256 amount, uint256 share);
    event LogTransfer(IERC20 indexed token, address indexed from, address indexed to, uint256 share);

    mapping(IERC20 => mapping(address => uint256)) public balanceOf; // Balance per token per address/contract
    mapping(IERC20 => Rebase) public totals;

    modifier allowed(address from) {
        require(
            msg.sender == from || masterContractApproved[masterContractOf[msg.sender]][from], 
            "BentoBox: Transfer not approved"
        );
        _;
    }

    function toShare(IERC20 token, uint256 amount) public view returns (uint256 share) {
        share = totals[token].toShare(amount);
    }

    function toAmount(IERC20 token, uint256 share) public view returns (uint256 amount) {
        amount = totals[token].toAmount(share);
    }

    function deposit(
        IERC20 token_, address from, address to, uint256 amount, uint256 share
    ) public payable allowed(from) returns (uint256 shareOut) {
        require(to != address(0), "BentoBox: to not set"); // To avoid a bad UI from burning funds
        IERC20 token = token_ == IERC20(0) ? WethToken : token_; 
        Rebase memory total = totals[token];

        // During the first deposit, we check that this token is 'real'
        require(total.amount != 0 || token.totalSupply() > 0, "BentoBox: No tokens");
        if (share == 0) { share = total.toShare(amount); } else { amount = total.toAmount(share); }

        balanceOf[token][to] = balanceOf[token][to].add(share);
        total.amount = total.amount.add(amount.to128());
        total.share = total.share.add(share.to128());
        totals[token] = total;

        if (token_ == IERC20(0)) {
            IWETH(address(WethToken)).deposit{value: amount}();
        } else {
            (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(0x23b872dd, from, address(this), amount));
            require(success && (data.length == 0 || abi.decode(data, (bool))), "BentoBox: TransferFrom failed");
        }
        emit LogDeposit(token, from, to, amount, share);
        shareOut = share;
    }

    function withdraw(
        IERC20 token_, address from, address to, uint256 amount, uint256 share
    ) public allowed(from) {
        require(to != address(0), "BentoBox: to not set"); // To avoid a bad UI from burning funds
        IERC20 token = token_ == IERC20(0) ? WethToken : token_;
        Rebase memory total = totals[token];
        if (share == 0) { share = total.toShare(amount); }
        else { amount = total.toAmount(share); }

        balanceOf[token][from] = balanceOf[token][from].sub(share);
        total.amount = total.amount.sub(amount.to128());
        total.share = total.share.sub(share.to128());
        // There have to be at least 10000 shares left at all times to prevent reseting the share/amount ratio
        require(total.share >= 10000, "BentoBox: cannot empty");
        totals[token] = total;

        if (token_ == WethToken) {
            IWETH(address(WethToken)).withdraw(amount);
            (bool success,) = to.call{value: amount}(new bytes(0));
            require(success, "BentoBox: ETH transfer failed");
        } else {
            (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(0xa9059cbb, to, amount));
            require(success && (data.length == 0 || abi.decode(data, (bool))), "BentoBox: Transfer failed");
        }
        emit LogWithdraw(token, from, to, amount, share);
    }

    function skim(IERC20 token_, address to) public returns (uint256 amount, uint256 share) {
        require(to != address(0), "BentoBox: to not set"); // To avoid a bad UI from burning funds
        IERC20 token = token_ == IERC20(0) ? WethToken : token_;
        if (token_ == WethToken) {
            IWETH(address(WethToken)).deposit{value: address(this).balance}();
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

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}
}
