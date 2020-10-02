// SPDX-License-Identifier: UNLICENSED

// WARNING!!! DO NOT USE!!! NOT YET TESTED + NOT YET SECURITY CONSIDERED + DEF. NOT YET AUDITED!!!
// FOR CONCEPT TESTING ONLY!

// Special thanks to:
// https://twitter.com/burger_crypto - for the idea of trying to let the LPs benefit from liquidations
pragma solidity ^0.6.12;
import "./libraries/BoringMath.sol";
import "./oracles/IOracle.sol";

interface IVault {
    function closedLiquidationContracts(address liquidator) external returns (bool);
    function transfer(address token, address to, uint256 amount) external returns (bool);
    function transferFrom(address token, address from, uint256 amount) external returns (bool);
}

interface ILiquidator {
    function swap(address from, address to, uint256 amountFrom, uint256 amountTo) external returns (uint256);
}

// TODO: check all reentrancy paths
// TODO: what to do when the entire pool is underwater?
// TODO: add minimum supply when borrowing, maybe not needed
// TODO: add events
// TODO: remove unnecassary checks to safe gas
// TODO: ensure BoringMath is always used
contract Pair {
    using BoringMath for uint256;

    // Keep track of user's balance in the system.
    // User can only borrow tokenA or tokenB. Can't supply and borrow the same token at the same time.
    // borrowedA tracks the direction of borrowing.

    struct User {
        uint256 shareA;    // Shares in the tokenA pool.
        uint256 shareB;    // Shares in the tokenB pool.
        uint256 borrowShare;    // Borrowed tokenB units.
    }

    IVault public vault;
    address public tokenA;
    address public tokenB;
    IOracle public oracle;

    mapping(address => User) public users;

    uint256 exchangeRate;

    uint256 public borrowed; // Total units of tokenB borrowed
    uint256 public lastBlockAccrued;

    uint256 public totalShareA; // Total amount of shares in the tokenA pool
    uint256 public totalShareB; // Total amount of shares in the tokenB pool
    uint256 public totalSupplyA;
    uint256 public totalSupplyB;
    uint256 public totalBorrowShare;

    uint256 public interestPerBlock;
    uint256 public lastInterestBlock;
    uint256 public minimumInterest;
    uint256 public maximumInterest;
    uint256 public targetMinUse;
    uint256 public targetMaxUse;

    uint256 public colRate;     // Collateral rate used to calculate if the protocol can liquidate
    uint256 public openColRate; // Collateral rate used to calculate if ANYONE can liquidate
    uint256 public liqMultiplier;

    function init(IVault vault_, address tokenA_, address tokenB_, IOracle oracle_) public {
        vault = vault_;
        tokenA = tokenA_;
        tokenB = tokenB_;
        oracle = oracle_;
        lastInterestBlock = block.number;

        interestPerBlock = 4566210045;  // 1% APR, with 1e18 being 100%
        minimumInterest = 1141552511;    // 0.25% APR
        maximumInterest = 4566210045000; // 1000% APR
        targetMinUse = 700000000000000000; // 70%
        targetMaxUse = 800000000000000000; // 80%

        colRate = 75000; // 75%
        openColRate = 77000; // 77%
        liqMultiplier = 112000; // 12% more tokenA
    }

    // Gets the exchange rate. How much tokenA to buy 1e18 tokenB.
    function updateRate() public returns (uint256) {
        (bool success, uint256 rate) = oracle.get(address(this));

        // TODO: How to deal with unsuccesful fetch
        if (success) {
            exchangeRate = rate;
        }
        return exchangeRate;
    }

    function updateInterestRate() public {
        uint256 blocks = block.number - lastInterestBlock;
        if (blocks == 0) {
            return;
        }
        uint256 balanceB = totalSupplyB.add(borrowed);
        uint256 utilization = borrowed.mul(1e18).div(balanceB);
        if (utilization < targetMinUse) {
            uint256 underFactor = targetMinUse.sub(utilization).mul(1e18).div(targetMinUse);
            uint256 scale = uint256(2000e36).add(underFactor.mul(underFactor).mul(blocks));
            interestPerBlock = interestPerBlock.mul(2000e36).div(scale);
            if (interestPerBlock < minimumInterest) {
                interestPerBlock = minimumInterest;
            }
        } else if (utilization > targetMaxUse) {
            uint256 overFactor = utilization.sub(targetMaxUse).mul(1e18).div(uint256(1e18).sub(targetMaxUse));
            // scale = 2000e36 + 1e36 * 20 = 2020e36
            uint256 scale = uint256(2000e36).add(overFactor.mul(overFactor).mul(blocks));

            interestPerBlock = interestPerBlock.mul(scale).div(2000e36);
            if (interestPerBlock > maximumInterest) {
                interestPerBlock = maximumInterest;
            }
        }

    }

    function addA(uint256 amountA) public {
        // Receive the tokens
        vault.transferFrom(tokenA, msg.sender, amountA);

        // Adjust user's balances
        User storage u = users[msg.sender];
        uint256 newShare;
        if (totalShareA == 0) {
            newShare = amountA;
        }
        else {
            newShare = amountA.mul(totalShareA).div(totalSupplyA);
        }

        u.shareA = u.shareA.add(newShare);
        totalShareA = totalShareA.add(newShare);
        totalSupplyA = totalSupplyA.add(amountA);
    }

    function addB(uint256 amountB) public {
        User storage u = users[msg.sender];
        require(u.borrowShare == 0, 'BentoBox: repay borrow first');

        // Accrue Interest
        accrue();

        // Receive the tokens
        vault.transferFrom(tokenB, msg.sender, amountB);

        // Adjust user's balances
        uint256 balanceB = totalSupplyB.add(borrowed);
        uint256 newShare;
        if (totalShareB == 0) {
            newShare = amountB;
        } else {
            newShare = amountB.mul(totalShareB).div(balanceB);
        }

        u.shareB = u.shareB.add(newShare);
        totalShareB = totalShareB.add(newShare);
        totalSupplyB = totalSupplyB.add(amountB);
    }

    function removeA(address to) public {
        User storage u = users[msg.sender];
        require(u.shareA > 0, 'BentoBox: nothing to remove');

        // Accrue Interest
        accrue();

        uint256 removeAmount = u.shareA.mul(totalSupplyA).div(totalShareA);
        totalShareA = totalShareA.sub(u.shareA);
        totalSupplyA = totalSupplyA.sub(removeAmount);
        u.shareA = 0;

        require(isSolvent(msg.sender, false), 'BentoBox: user insolvent');
        vault.transfer(tokenA, to, removeAmount);
    }

    function removeA(uint256 amountA, address to) public {
        // Accrue Interest
        accrue();

        User storage u = users[msg.sender];
        uint256 removeShare = amountA.mul(totalShareA).div(totalSupplyA);
        u.shareA = u.shareA.sub(removeShare);
        totalShareA = totalShareA.sub(removeShare);
        totalSupplyA = totalSupplyA.sub(amountA);

        require(isSolvent(msg.sender, false), 'BentoBox: user insolvent');
        vault.transfer(tokenA, to, amountA);
    }

    function removeB(address to) public {
        User storage u = users[msg.sender];
        require(u.shareB > 0, 'BentoBox: nothing to remove');

        // Accrue Interest
        accrue();

        uint256 balanceB = totalSupplyB.add(borrowed);
        uint256 removeAmount = u.shareB.mul(balanceB).div(totalShareB);
        totalShareB = totalShareB.sub(u.shareB);
        totalSupplyA = totalSupplyA.sub(removeAmount);
        u.shareB = 0;

        vault.transfer(tokenB, to, removeAmount);
    }

    function removeB(uint256 amountB, address to) public {
        // Accrue Interest
        accrue();

        User storage u = users[msg.sender];
        uint256 balanceB = totalSupplyB.add(borrowed);
        uint256 removeShare = amountB.mul(totalShareB).div(balanceB);
        u.shareB = u.shareB.sub(removeShare);
        totalShareB = totalShareB.sub(removeShare);
        totalSupplyB = totalSupplyB.sub(amountB);

        vault.transfer(tokenB, to, amountB);
    }

    function borrow(uint256 amountB, address to) public {
        User storage u = users[msg.sender];
        require(u.shareB == 0, 'BentoBox: remove supply first');

        // Accrue Interest
        accrue();

        borrowed = borrowed.add(amountB);
        totalSupplyB = totalSupplyB.sub(amountB);
        uint256 newBorrowShare;
        if (totalBorrowShare == 0) {
            newBorrowShare = amountB;
        }
        else {
            newBorrowShare.add(amountB.mul(totalBorrowShare).div(borrowed));
        }
        u.borrowShare = u.borrowShare.add(newBorrowShare);
        totalBorrowShare = totalBorrowShare.add(newBorrowShare);

        require(isSolvent(msg.sender, false), 'BentoBox: user insolvent');
        vault.transfer(tokenB, to, amountB);
    }

    function repay() public {
        // Accrue Interest
        accrue();

        User storage u = users[msg.sender];

        uint256 repayAmount = u.borrowShare.mul(borrowed).div(totalBorrowShare);
        vault.transferFrom(tokenB, msg.sender, repayAmount);
        totalBorrowShare = totalBorrowShare.sub(u.borrowShare);
        u.borrowShare = 0;
        borrowed = borrowed.sub(repayAmount);
        totalSupplyB = totalSupplyB.add(repayAmount);
    }

    function repay(uint256 amountB) public {
        // Accrue Interest
        accrue();

        User storage u = users[msg.sender];

        uint256 repayShare = amountB.mul(totalBorrowShare).div(borrowed);
        vault.transferFrom(tokenB, msg.sender, amountB);
        totalBorrowShare = totalBorrowShare.sub(repayShare);
        u.borrowShare = u.borrowShare.sub(repayShare);
        borrowed = borrowed.sub(amountB);
        totalSupplyB = totalSupplyB.add(amountB);
    }

    function liquidate(address[] calldata userlist, uint256[] calldata amountBlist, address liquidator, bool open) public {
        updateRate();

        uint256 amountA;
        uint256 amountB;
        uint256 shareA;
        uint256 shareB;
        for (uint256 i = 0; i < userlist.length; i++) {
            address user = userlist[i];
            uint256 userAmountB = amountBlist[i];
            if (!isSolvent(user, open)) {
                uint256 userShareB;
                User storage u = users[user];
                if (userAmountB == 0) {
                    // If amount is 0, liquidate all
                    userShareB = u.borrowShare;
                    userAmountB = userShareB.mul(borrowed).div(totalBorrowShare);
                }
                else
                {
                    userShareB = userAmountB.mul(totalBorrowShare).div(borrowed);
                }

                uint256 userAmountA = userAmountB.mul(1e18).mul(liqMultiplier).div(exchangeRate).div(1e5);
                uint256 userShareA = userAmountA.mul(totalShareA).div(totalSupplyA);

                u.shareA = u.shareA.sub(userShareA);
                u.borrowShare = u.borrowShare.sub(userShareB);

                amountA = amountA.add(userAmountA);
                amountB = amountB.add(userAmountB);
                shareA = shareA.add(userShareA);
                shareB = shareB.add(userShareB);
            }
        }
        require(amountA != 0, 'BentoBox: all users are solvent');
        borrowed = borrowed.sub(amountB);
        totalBorrowShare = totalBorrowShare.sub(shareB);

        if (open && address(liquidator) == address(0)) {
            totalSupplyA = totalSupplyA.sub(amountA);
            totalSupplyB = totalSupplyB.add(amountB);
            totalShareA = totalShareA.sub(shareA);
            totalShareB = totalShareB.add(shareB);

            vault.transferFrom(tokenB, msg.sender, amountB);
            vault.transfer(tokenA, msg.sender, amountA);
        } else if (open && address(liquidator) == address(1)) {
            User storage u = users[msg.sender];
            u.shareA = u.shareA.add(shareA);
            u.shareB = u.shareB.sub(shareB);
        } else {
            totalSupplyA = totalSupplyA.sub(amountA);
            totalSupplyB = totalSupplyB.add(amountB);
            totalShareA = totalShareA.sub(shareA);
            totalShareB = totalShareB.add(shareB);

            if (!open) {
                require(vault.closedLiquidationContracts(liquidator), 'BentoBox: Invalid liquidator');
                // solium-disable-next-line security/no-low-level-calls
                (bool success, bytes memory result) = liquidator.delegatecall(abi.encodeWithSignature("swap(address,address,uint256,uint256)", tokenA, tokenB, amountA, amountB));
                require(success, 'BentoBox: Liquidation failed');
                uint256 swappedAmountB = abi.decode(result, (uint256));
                uint256 extraAmountB = swappedAmountB.sub(amountB);
                totalSupplyB = totalSupplyB.add(extraAmountB);
            } else {
                vault.transfer(tokenA, liquidator, amountA);
                uint256 swappedAmountB = ILiquidator(liquidator).swap(tokenA, tokenB, amountA, amountB);
                uint256 extraAmountB = swappedAmountB.sub(amountB);
                vault.transferFrom(tokenB, liquidator, swappedAmountB);
                totalSupplyB = totalSupplyB.add(extraAmountB);

                User storage u = users[msg.sender];
                uint256 balanceB = totalSupplyB.add(borrowed);
                uint256 newShare;
                newShare = extraAmountB.mul(totalShareB).div(balanceB);
                u.shareB = u.shareB.add(newShare);
                totalShareB = totalShareB.add(newShare);
                totalSupplyB = totalSupplyB.add(amountB);
            }
        }
    }

    // Internal functions

    function accrue() public {
        // The first time lastBlockAccrued will be 0, but also borrowed will be 0, so all good
        borrowed = borrowed.add(borrowed.mul(interestPerBlock).mul(block.number - lastBlockAccrued).div(1e18));
        lastBlockAccrued = block.number;
    }

    function isSolvent(address user, bool open) public view returns (bool) {
        // accrue must have already been called!
        User storage u = users[user];
        if (u.borrowShare == 0) return true;
        if (totalShareA == 0) return false;

        uint256 supplyA = u.shareA.mul(totalSupplyA).div(totalShareA);
        uint256 borrowB = u.borrowShare.mul(borrowed).div(totalBorrowShare);
        uint256 borrowA = borrowB.mul(1e18).div(exchangeRate);

        return supplyA.mul(open ? openColRate : colRate).div(1e5) >= borrowA;
    }
}