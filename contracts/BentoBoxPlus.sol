// SPDX-License-Identifier: UNLICENSED

// The BentoBox Plus

//  ▄▄▄▄· ▄▄▄ . ▐ ▄ ▄▄▄▄▄      ▄▄▄▄·       ▐▄• ▄ 
//  ▐█ ▀█▪▀▄.▀·█▌▐█•██  ▪     ▐█ ▀█▪▪      █▌█▌▪
//  ▐█▀▀█▄▐▀▀▪▄▐█▐▐▌ ▐█.▪ ▄█▀▄ ▐█▀▀█▄ ▄█▀▄  ·██· 
//  ██▄▪▐█▐█▄▄▌██▐█▌ ▐█▌·▐█▌.▐▌██▄▪▐█▐█▌.▐▌▪▐█·█▌ Plus!!
//  ·▀▀▀▀  ▀▀▀ ▀▀ █▪ ▀▀▀  ▀█▄▀▪·▀▀▀▀  ▀█▄▀▪•▀▀ ▀▀

// This contract stores funds, handles their transfers, supports flash loans and strategies.

// Copyright (c) 2021 BoringCrypto - All rights reserved
// Twitter: @Boring_Crypto

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;
// solhint-disable avoid-low-level-calls
// solhint-disable not-rely-on-time

import "@boringcrypto/boring-solidity/contracts/libraries/BoringERC20.sol";
import "@boringcrypto/boring-solidity/contracts/libraries/BoringRebase.sol";
import "@boringcrypto/boring-solidity/contracts/BoringBatchable.sol";
import "./interfaces/IFlashLoan.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IStrategy.sol";
import "./MasterContractManager.sol";

/// @title BentoBoxPlus
/// @author BoringCrypto, Keno
/// @notice The BentoBox is a vault for tokens. The stored tokens can be flash loaned. Fees for this will go to the token depositors.
/// Rebasing tokens ARE NOT supported and WILL cause loss of funds.
/// Any funds transfered directly onto the BentoBox will be lost, use the deposit function instead.
// T1 - T4: OK
contract BentoBoxPlus is MasterContractManager, BoringBatchable {
    using BoringMath for uint256;
    using BoringMath128 for uint128;
    using BoringERC20 for IERC20;
    using RebaseLibrary for Rebase;

    // ************** //
    // *** EVENTS *** //
    // ************** //

    // E1: OK
    event LogDeposit(IERC20 indexed token, address indexed from, address indexed to, uint256 amount, uint256 share);
    // E1: OK
    event LogWithdraw(IERC20 indexed token, address indexed from, address indexed to, uint256 amount, uint256 share);
    // E1: OK
    event LogTransfer(IERC20 indexed token, address indexed from, address indexed to, uint256 share);

    // E1: OK
    event LogFlashLoan(address indexed borrower, IERC20 indexed token, uint256 amount, uint256 feeAmount, address indexed receiver);

    // E1: OK
    event LogStrategyTargetPercentage(IERC20 indexed token, uint256 targetPercentage);
    // E1: OK
    event LogStrategyQueued(IERC20 indexed token, IStrategy indexed strategy);
    // E1: OK
    event LogStrategySet(IERC20 indexed token, IStrategy indexed strategy);
    // E1: OK
    event LogStrategyInvest(IERC20 indexed token, uint256 amount);
    // E1: OK
    event LogStrategyDivest(IERC20 indexed token, uint256 amount);
    // E1: OK
    event LogStrategyProfit(IERC20 indexed token, uint256 amount);
    // E1: OK
    event LogStrategyLoss(IERC20 indexed token, uint256 amount);

    // *************** //
    // *** STRUCTS *** //
    // *************** //

    struct StrategyData {
        uint64 strategyStartDate;
        uint64 targetPercentage;
        uint128 balance;
    }

    // ******************************** //
    // *** CONSTANTS AND IMMUTABLES *** //
    // ******************************** //

    // V1 - V5: OK
    // V2 - Can they be private?
    // V2: Private to save gas, to verify it's correct, check the constructor arguments
    IERC20 private immutable wethToken;

    IERC20 private constant USE_ETHEREUM = IERC20(0);
    uint256 private constant FLASH_LOAN_FEE = 50; // 0.05%
    uint256 private constant FLASH_LOAN_FEE_PRECISION = 1e5;    
    uint256 private constant STRATEGY_DELAY = 2 weeks;
    uint256 private constant MAX_TARGET_PERCENTAGE = 95;

    // ***************** //
    // *** VARIABLES *** //
    // ***************** //

    // V1 - V5: OK
    // Balance per token per address/contract in shares
    mapping(IERC20 => mapping(address => uint256)) public balanceOf;

    // V1 - V5: OK
    // Rebase from amount to share
    mapping(IERC20 => Rebase) public totals;

    // V1 - V5: OK
    mapping(IERC20 => IStrategy) public strategy;
    // V1 - V5: OK
    mapping(IERC20 => IStrategy) public pendingStrategy;
    // V1 - V5: OK
    mapping(IERC20 => StrategyData) public strategyData;

    // ******************* //
    // *** CONSTRUCTOR *** //
    // ******************* //

    constructor(IERC20 wethToken_) public {
        wethToken = wethToken_;
    }

    // ***************** //
    // *** MODIFIERS *** //
    // ***************** //

    // M1 - M5: OK
    // C1 - C23: OK
    // Modifier to check if the msg.sender is allowed to use funds belonging to the 'from' address.
    // If 'from' is msg.sender, it's allowed.
    // If 'from' is the BentoBox itself, it's allowed. Any ETH, token balances (above the known balances) or BentoBox balances 
    // can be taken by anyone.
    // This is to enable skimming, not just for deposits, but also for withdrawals or transfers, enabling better composability.
    // If 'from' is a clone of a masterContract AND the 'from' address has approved that masterContract, it's allowed.
    modifier allowed(address from) {
        if (from != msg.sender && from != address(this)) { // From is sender or you are skimming
            address masterContract = masterContractOf[msg.sender];
            require(masterContract != address(0), "BentoBox: no masterContract");
            require(masterContractApproved[masterContract][from], "BentoBox: Transfer not approved");
        }
        _;
    }

    // ************************** //
    // *** INTERNAL FUNCTIONS *** //
    // ************************** //

    function _tokenBalanceOf(IERC20 token) internal view returns (uint256 amount) {
        amount = token.balanceOf(address(this)).add(strategyData[token].balance);
    }

    // ************************ //
    // *** PUBLIC FUNCTIONS *** //
    // ************************ //

    function toShare(IERC20 token, uint256 amount, bool roundUp) external view returns(uint256 share) {
        share = totals[token].toBase(amount, roundUp);
    }

    function toAmount(IERC20 token, uint256 share, bool roundUp) external view returns(uint256 amount) {
        amount = totals[token].toElastic(share, roundUp);
    }

    // F1 - F10: OK
    // F3 - Can it be combined with another similar function?
    // F3: Combined deposit(s) and skim functions into one
    // C1 - C21: OK
    // C2 - Are any storage slots read multiple times?
    // C2: wethToken is used multiple times, but this is an immutable, so after construction it's hardcoded in the contract
    function deposit(
        IERC20 token_, address from, address to, uint256 amount, uint256 share
    ) public payable allowed(from) returns (uint256 amountOut, uint256 shareOut) {
        // Checks
        require(to != address(0), "BentoBox: to not set"); // To avoid a bad UI from burning funds

        // Effects
        IERC20 token = token_ == USE_ETHEREUM ? wethToken : token_;
        Rebase memory total = totals[token];

        // S1 - S4: OK
        // If a new token gets added, the tokenSupply call checks that this is a deployed contract. Needed for security.
        require(total.elastic != 0 || token.totalSupply() > 0, "BentoBox: No tokens");
        if (share == 0) {
            // value of the share may be lower than the amount due to rounding, that's ok
            share = total.toBase(amount, false);
        } else {
            // amount may be lower than the value of share due to rounding, in that case, add 1 to amount (Always round up)
            amount = total.toElastic(share, true);
        }

        // In case of skimming, check that only the skimmable amount is taken. For ETH, the full balance is available, so no need to check.
        require(from != address(this) || token_ == USE_ETHEREUM || amount <= _tokenBalanceOf(token).sub(total.elastic), 
            "BentoBox: Skim too much");

        balanceOf[token][to] = balanceOf[token][to].add(share);
        total.base = total.base.add(share.to128());
        total.elastic = total.elastic.add(amount.to128());
        totals[token] = total;

        // Interactions
        // During the first deposit, we check that this token is 'real'
        if (token_ == USE_ETHEREUM) {
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
    // C2 - Are any storage slots read multiple times?
    // C2: wethToken is used multiple times, but this is an immutable, so after construction it's hardcoded in the contract
    function withdraw(
        IERC20 token_, address from, address to, uint256 amount, uint256 share
    ) public allowed(from) returns (uint256 amountOut, uint256 shareOut) {
        // Checks
        require(to != address(0), "BentoBox: to not set"); // To avoid a bad UI from burning funds

        // Effects
        IERC20 token = token_ == USE_ETHEREUM ? wethToken : token_;
        Rebase memory total = totals[token];
        if (share == 0) { 
            // value of the share paid could be lower than the amount paid due to rounding, in that case, add a share (Always round up)
            share = total.toBase(amount, true);
        } else {
            // amount may be lower than the value of share due to rounding, that's ok
            amount = total.toElastic(share, false);
        }

        balanceOf[token][from] = balanceOf[token][from].sub(share);
        total.elastic = total.elastic.sub(amount.to128());
        total.base = total.base.sub(share.to128());
        // There have to be at least 1000 shares left to prevent reseting the share/amount ratio (unless it's fully emptied)
        require(total.base >= 1000 || total.base == 0, "BentoBox: cannot empty");
        totals[token] = total;

        // Interactions
        if (token_ == USE_ETHEREUM) {
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

    // Clones of master contracts can transfer from any account that has approved them
    // F1 - F10: OK
    // F3 - Can it be combined with another similar function?
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
    // F3 - Can it be combined with another similar function?
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

    function flashLoan(IFlashBorrower borrower, address receiver, IERC20 token, uint256 amount, bytes calldata data) public {
        uint256 fee = amount.mul(FLASH_LOAN_FEE) / FLASH_LOAN_FEE_PRECISION;
        token.safeTransfer(receiver, amount);

        borrower.onFlashLoan(msg.sender, token, amount, fee, data);
        
        require(_tokenBalanceOf(token) >= totals[token].addElastic(fee.to128()), "BentoBoxPlus: Wrong amount");
        emit LogFlashLoan(address(borrower), token, amount, fee, receiver);
    }

    // F1 - F10: OK
    // F5 - Checks-Effects-Interactions pattern followed? (SWC-107)
    // F5: Not possible to follow this here, reentrancy needs a careful review
    // F6 - Check for front-running possibilities, such as the approve function (SWC-114)
    // F6: Slight grieving possible by withdrawing an amount before someone tries to flashloan close to the full amount.
    // C1 - C23: OK
    function batchFlashLoan(
        IBatchFlashBorrower borrower,
        address[] calldata receivers,
        IERC20[] calldata tokens,
        uint256[] calldata amounts,
        bytes calldata data
    ) public {
        uint256[] memory fees = new uint256[](tokens.length);
        
        uint256 len = tokens.length;
        for (uint256 i = 0; i < len; i++) {
            uint256 amount = amounts[i];
            fees[i] = amount.mul(FLASH_LOAN_FEE) / FLASH_LOAN_FEE_PRECISION;

            tokens[i].safeTransfer(receivers[i], amounts[i]);
        }

        borrower.onBatchFlashLoan(msg.sender, tokens, amounts, fees, data);

        for (uint256 i = 0; i < len; i++) {
            IERC20 token = tokens[i];
            require(_tokenBalanceOf(token) >= totals[token].addElastic(fees[i].to128()), "BentoBoxPlus: Wrong amount");
            emit LogFlashLoan(address(borrower), token, amounts[i], fees[i], receivers[i]);
        }
    }

    // F1 - F10: OK
    // C1 - C23: OK
    function setStrategyTargetPercentage(IERC20 token, uint64 targetPercentage_) public onlyOwner {
        // Checks
        require(targetPercentage_ <= MAX_TARGET_PERCENTAGE, "StrategyManager: Target too high");

        // Effects
        strategyData[token].targetPercentage = targetPercentage_;
        emit LogStrategyTargetPercentage(token, targetPercentage_);
    }

    // F1 - F10: OK
    // F5 - Checks-Effects-Interactions pattern followed? (SWC-107)
    // F5: Total amount is updated AFTER interaction. But strategy is under our control.
    // C1 - C23: OK
    // C4 - Use block.timestamp only for long intervals (SWC-116)
    // C4: block.timestamp is used for a period of 2 weeks, which is long enough
    // F1 - F10: OK
    function setStrategy(IERC20 token, IStrategy newStrategy) public onlyOwner {
        IStrategy pending = pendingStrategy[token];
        if (pending != newStrategy) {
            pendingStrategy[token] = newStrategy;
            strategyData[token].strategyStartDate = (block.timestamp + STRATEGY_DELAY).to64();
            emit LogStrategyQueued(token, newStrategy);
        } else {
            StrategyData memory data = strategyData[token];
            require(data.strategyStartDate != 0 && block.timestamp >= data.strategyStartDate, "StrategyManager: Too early");
            if (address(strategy[token]) != address(0)) {
                int256 balanceChange = strategy[token].exit(data.balance);
                // Effects
                if (balanceChange > 0) {
                    uint256 add = uint256(balanceChange);
                    totals[token].addElastic(add);
                    emit LogStrategyProfit(token, add);
                } else if (balanceChange < 0) {
                    uint256 sub = uint256(-balanceChange);
                    totals[token].subElastic(sub);
                    emit LogStrategyLoss(token, sub);
                }

                emit LogStrategyDivest(token, data.balance);
            }
            strategy[token] = pending;
            data.strategyStartDate = 0;
            data.balance = 0;
            strategyData[token] = data;
            emit LogStrategySet(token, newStrategy);
        }
    }

    // F1 - F10: OK
    // F5 - Checks-Effects-Interactions pattern followed? (SWC-107)
    // F5: Total amount is updated AFTER interaction. But strategy is under our control.
    // F5: Not followed to prevent reentrancy issues with flashloans and BentoBox skims?
    // C1 - C23: OK
    function harvest(IERC20 token, bool balance, uint256 maxChangeAmount) public {
        StrategyData memory data = strategyData[token];
        IStrategy _strategy = strategy[token];
        int256 balanceChange = _strategy.harvest(data.balance);
        if (balanceChange == 0 && !balance) { return; }

        uint256 totalElastic = totals[token].elastic;

        if (balanceChange > 0) {
            uint256 add = uint256(balanceChange);
            totalElastic = totalElastic.add(add);
            totals[token].elastic = totalElastic.to128();
            emit LogStrategyProfit(token, add);
        } else if (balanceChange < 0) {
            uint256 sub = uint256(-balanceChange);
            totalElastic = totalElastic.sub(sub);
            totals[token].elastic = totalElastic.to128();
            data.balance = data.balance.sub(sub.to128());
            emit LogStrategyLoss(token, sub);
        }

        if (balance) {
            uint256 targetBalance = totalElastic.mul(data.targetPercentage) / 100;
            if (data.balance < targetBalance) {
                uint256 amountOut = targetBalance.sub(data.balance);
                if (maxChangeAmount != 0 && amountOut > maxChangeAmount) { amountOut = maxChangeAmount; }
                token.safeTransfer(address(_strategy), amountOut);
                data.balance = data.balance.add(amountOut.to128());
                _strategy.skim(amountOut);
                emit LogStrategyInvest(token, amountOut);
            } else if (data.balance > targetBalance) {
                uint256 amountIn = data.balance.sub(targetBalance.to128());
                if (maxChangeAmount != 0 && amountIn > maxChangeAmount) { amountIn = maxChangeAmount; }
                data.balance = data.balance.sub(amountIn.to128());
                
                _strategy.withdraw(amountIn);
                
                emit LogStrategyDivest(token, amountIn);
            }
        }
        
        strategyData[token] = data;
    }

    // Contract should be able to receive ETH deposits to support deposit & skim
    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}
}
