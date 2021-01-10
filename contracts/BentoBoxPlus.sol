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

interface IStrategy {
    function balanceOf() external returns (uint256 amount);

    // Send the assets to the Strategy and call skim to invest them
    function skim() external returns (uint256 amount);

    // Harvest any profits made converted to the asset and pass them to the caller
    function harvest() external returns (uint256 amount);

    // Withdraw assets. Withdraw will call harvest first. The returned amount includes the harvested amount.
    function withdraw(uint256 amount) external returns (uint256 totalAmount);
}

// Note: Rebasing tokens ARE NOT supported and WILL cause loss of funds
contract BentoBoxPlus is BoringFactory, MasterContractManager, BoringBatchable {
    using BoringMath for uint256;
    using BoringMath128 for uint128;
    using BoringERC20 for IERC20;
    using RebaseLibrary for Rebase;

    // E1: OK
    event LogDeposit(IERC20 indexed token, address indexed from, address indexed to, uint256 amount, uint256 share);
    // E1: OK
    event LogWithdraw(IERC20 indexed token, address indexed from, address indexed to, uint256 amount, uint256 share);
    event LogTransfer(IERC20 indexed token, address indexed from, address indexed to, uint256 share);
    event LogFlashLoan(address indexed receiver, IERC20 indexed token, uint256 amount, uint256 feeAmount, address indexed user);

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
            token.safeTransferFrom(from, amount);
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
    // C2: This isn't combined with transferMultiple for gas optimization
    function transfer(IERC20 token, address from, address to, uint256 share) public allowed(from) {
        require(to != address(0), "BentoBox: to not set"); // To avoid a bad UI from burning funds
        balanceOf[token][from] = balanceOf[token][from].sub(share);
        balanceOf[token][to] = balanceOf[token][to].add(share);

        emit LogTransfer(token, from, to, share);
    }

    // C2: This isn't combined with transfer for gas optimization
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

            tokens[i].safeTransfer(receiver, amounts[i]);
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
