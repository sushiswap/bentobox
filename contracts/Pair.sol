// SPDX-License-Identifier: UNLICENSED

// WARNING!!! DO NOT USE!!! NOT YET TESTED + NOT YET SECURITY CONSIDERED + DEF. NOT YET AUDITED!!!
// FOR CONCEPT TESTING ONLY!

// Special thanks to:
// https://twitter.com/burger_crypto - for the idea of trying to let the LPs benefit from liquidations
pragma solidity ^0.6.12;
import "./libraries/BoringMath.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/IVault.sol";

interface IDelegateSwapper {
    // Withdraws amountFrom 'from tokens' from the vault, turns it into at least amountToMin 'to tokens' and transfers those into the vault.
    // Returns amount of tokens added to the vault.
    function swap(address swapper, address from, address to, uint256 amountFrom, uint256 amountToMin) external returns (uint256);
}

interface ISwapper {
    function swap(address from, address to, uint256 amountFrom, uint256 amountTo, address profitTo) external;
}

// TODO: check all reentrancy paths
// TODO: what to do when the entire pool is underwater?
// TODO: add minimum supply when borrowing, maybe not needed
// TODO: add events
// TODO: remove unnecassary checks to safe gas
// TODO: ensure BoringMath is always used
// We do allow supplying B and borrowing, but the supply does NOT provide collateral as it's just silly and no UI should allow this
contract Pair {
    using BoringMath for uint256;

    // Keep at the top in this order for delegate calls to be able to access them
    IVault public vault;
    address public tokenA;
    address public tokenB;

    //event Debug(uint256 nr, uint256 val);
    event DebugPair(uint256 nr, address val);

    struct User {
        uint256 shareA;    // Shares in the tokenA pool.
        uint256 shareB;    // Shares in the tokenB pool.
        uint256 borrowShare;    // Borrowed tokenB units.
    }

    IOracle public oracle;

    mapping(address => User) public users;

    uint256 exchangeRate;

    uint256 public lastBlockAccrued;

    uint256 public totalShareA; // Total amount of shares in the tokenA pool
    uint256 public totalShareB; // Total amount of shares in the tokenB pool
    uint256 public totalSupplyA;
    uint256 public totalSupplyB; // Includes totalBorrow
    uint256 public totalBorrow; // Total units of tokenB borrowed
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
    uint256 public fee;
    uint256 public feesPending;

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
        fee = 10000; // 10%
    }

    function accrue() public {
        // The first time lastBlockAccrued will be 0, but also borrowed will be 0, so all good
        totalBorrow = totalBorrow.add(totalBorrow.mul(interestPerBlock).mul(block.number - lastBlockAccrued).div(1e18));
        lastBlockAccrued = block.number;
    }

    function isSolvent(address user, bool open) public view returns (bool) {
        // accrue must have already been called!
        User storage u = users[user];
        if (u.borrowShare == 0) return true;
        if (totalShareA == 0) return false;

        uint256 supplyA = u.shareA.mul(totalSupplyA).div(totalShareA);
        uint256 borrowB = u.borrowShare.mul(totalBorrow).div(totalBorrowShare);
        uint256 borrowA = borrowB.mul(exchangeRate).div(1e18);

        return supplyA.mul(open ? openColRate : colRate).div(1e5) >= borrowA;
    }

    // Gets the exchange rate. How much tokenA to buy 1e18 tokenB.
    function updateExchangeRate() public returns (uint256) {
        (bool success, uint256 rate) = oracle.get(address(this));

        // TODO: How to deal with unsuccesful fetch
        if (success) {
            exchangeRate = rate;
        }
        return exchangeRate;
    }

    // TODO: Needs guard against manipulation?
    function updateInterestRate() public {
        uint256 blocks = block.number - lastInterestBlock;
        if (blocks == 0) {return;}
        uint256 utilization = totalBorrow.mul(1e18).div(totalSupplyB);
        if (utilization < targetMinUse) {
            uint256 underFactor = targetMinUse.sub(utilization).mul(1e18).div(targetMinUse);
            uint256 scale = uint256(2000e36).add(underFactor.mul(underFactor).mul(blocks));
            interestPerBlock = interestPerBlock.mul(2000e36).div(scale);
            if (interestPerBlock < minimumInterest) {
                interestPerBlock = minimumInterest;
            }
        } else if (utilization > targetMaxUse) {
            uint256 overFactor = utilization.sub(targetMaxUse).mul(1e18).div(uint256(1e18).sub(targetMaxUse));
            uint256 scale = uint256(2000e36).add(overFactor.mul(overFactor).mul(blocks));

            interestPerBlock = interestPerBlock.mul(scale).div(2000e36);
            if (interestPerBlock > maximumInterest) {
                interestPerBlock = maximumInterest;
            }
        }
    }

    function addA(uint256 amountA) public {
        User storage u = users[msg.sender];
        uint256 newShare = totalShareA == 0 ? amountA : amountA.mul(totalShareA).div(totalSupplyA);

        totalShareA = totalShareA.add(newShare);
        totalSupplyA = totalSupplyA.add(amountA);
        u.shareA = u.shareA.add(newShare);

        vault.transferFrom(tokenA, msg.sender, amountA);
    }

    function addB(uint256 amountB) public {
        User storage u = users[msg.sender];
        accrue();

        uint256 newShare = totalShareB == 0 ? amountB : amountB.mul(totalShareB).div(totalSupplyB);

        totalShareB = totalShareB.add(newShare);
        totalSupplyB = totalSupplyB.add(amountB);
        u.shareB = u.shareB.add(newShare);

        vault.transferFrom(tokenB, msg.sender, amountB);
    }

    function removeA(uint256 shareA, address to) public {
        User storage u = users[msg.sender];
        accrue();

        uint256 amountA = shareA.mul(totalSupplyA).div(totalShareA);
        totalShareA = totalShareA.sub(shareA);
        totalSupplyA = totalSupplyA.sub(amountA);
        u.shareA = u.shareA.sub(shareA);

        require(isSolvent(msg.sender, false), 'BentoBox: user insolvent');
        vault.transfer(tokenA, to, amountA);
    }

    function removeB(uint256 shareB, address to) public {
        User storage u = users[msg.sender];
        accrue();

        uint256 amountB = u.shareB.mul(totalSupplyB).div(totalShareB);
        totalShareB = totalShareB.sub(shareB);
        totalSupplyA = totalSupplyA.sub(amountB);
        u.shareB = u.shareB.sub(shareB);

        vault.transfer(tokenB, to, amountB);
    }

    function borrow(uint256 amountB, address to) public {
        require(amountB <= totalSupplyB.sub(totalBorrow), 'BentoBox: not enough liquidity');
        User storage u = users[msg.sender];
        accrue();

        uint256 newBorrowShare = totalBorrowShare == 0 ? amountB : amountB.mul(totalBorrowShare).div(totalBorrow);
        totalBorrow = totalBorrow.add(amountB);
        u.borrowShare = u.borrowShare.add(newBorrowShare);
        totalBorrowShare = totalBorrowShare.add(newBorrowShare);

        require(isSolvent(msg.sender, false), 'BentoBox: user insolvent');
        vault.transfer(tokenB, to, amountB);
    }

    function repay(uint256 shareB) public {
        User storage u = users[msg.sender];
        accrue();

        uint256 amountB = shareB.mul(totalBorrow).div(totalBorrowShare);
        vault.transferFrom(tokenB, msg.sender, amountB);
        totalBorrowShare = totalBorrowShare.sub(shareB);
        u.borrowShare = u.borrowShare.sub(shareB);
        totalBorrow = totalBorrow.sub(amountB);
        totalSupplyB = totalSupplyB.add(amountB);
    }

    function liquidate(address[] calldata userlist, uint256[] calldata shareBlist, address to, address swapper, bool open) public {
        updateExchangeRate();

        uint256 amountA;
        uint256 amountB;
        uint256 shareA;
        uint256 shareB;
        for (uint256 i = 0; i < userlist.length; i++) {
            address user = userlist[i];
            if (!isSolvent(user, open)) {
                User storage u = users[user];

                uint256 userShareB = shareBlist[i];
                uint256 userAmountB = userShareB.mul(totalBorrow).div(totalBorrowShare);
                uint256 userAmountA = userAmountB.mul(1e13).mul(liqMultiplier).div(exchangeRate);
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
        totalBorrow = totalBorrow.sub(amountB);
        totalBorrowShare = totalBorrowShare.sub(shareB);

        if (!open) {
            totalSupplyA = totalSupplyA.sub(amountA);
            totalShareA = totalShareA.sub(shareA);
            totalShareB = totalShareB.add(shareB);

            // Closed liquidation using a pre-approved swapper for the benefit of the LPs
            require(vault.swappers(swapper), 'BentoBox: Invalid swapper');

            // solium-disable-next-line security/no-low-level-calls
            (bool success, bytes memory result) = swapper.delegatecall(abi.encodeWithSignature("swap(address,address,address,uint256,uint256)", swapper, tokenA, tokenB, amountA, amountB));
            require(success, 'BentoBox: Liquidation failed');
            uint256 swappedAmountB = abi.decode(result, (uint256));
            uint256 extraAmountB = swappedAmountB.sub(amountB);
            totalSupplyB = totalSupplyB.add(extraAmountB);
        } else if (swapper == address(1)) {
            // Open liquidation using vault balances
            User storage u = users[msg.sender];
            u.shareA = u.shareA.add(shareA);
            u.shareB = u.shareB.sub(shareB);
        } else {
            totalSupplyA = totalSupplyA.sub(amountA);
            totalShareA = totalShareA.sub(shareA);
            totalShareB = totalShareB.add(shareB);

            // Open flash liquidation: get proceeds first and provide the borrow after
            if (swapper != address(0)) {
                vault.transfer(tokenA, swapper, amountA);
                ISwapper(swapper).swap(tokenA, tokenB, amountA, amountB, to);
                vault.transferFrom(tokenB, swapper, amountB);
            }
            else
            {
                vault.transferFrom(tokenB, msg.sender, amountB);
                vault.transfer(tokenA, msg.sender, amountA);
            }
        }
    }
}