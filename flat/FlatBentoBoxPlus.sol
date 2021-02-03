// SPDX-License-Identifier: UNLICENSED (some MIT)
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;
// solhint-disable avoid-low-level-calls
// solhint-disable no-inline-assembly
// solhint-disable avoid-low-level-calls
// solhint-disable not-rely-on-time

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // EIP 2612
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
}

library BoringERC20 {
    bytes4 private constant SIG_SYMBOL = 0x95d89b41; // symbol()
    bytes4 private constant SIG_NAME = 0x06fdde03; // name()
    bytes4 private constant SIG_DECIMALS = 0x313ce567; // decimals()
    bytes4 private constant SIG_TRANSFER = 0xa9059cbb; // transfer(address,uint256)
    bytes4 private constant SIG_TRANSFER_FROM = 0x23b872dd; // transferFrom(address,address,uint256)

    function safeSymbol(IERC20 token) internal view returns(string memory) {
        (bool success, bytes memory data) = address(token).staticcall(abi.encodeWithSelector(SIG_SYMBOL));
        return success && data.length > 0 ? abi.decode(data, (string)) : "???";
    }

    function safeName(IERC20 token) internal view returns(string memory) {
        (bool success, bytes memory data) = address(token).staticcall(abi.encodeWithSelector(SIG_NAME));
        return success && data.length > 0 ? abi.decode(data, (string)) : "???";
    }

    function safeDecimals(IERC20 token) internal view returns (uint8) {
        (bool success, bytes memory data) = address(token).staticcall(abi.encodeWithSelector(SIG_DECIMALS));
        return success && data.length == 32 ? abi.decode(data, (uint8)) : 18;
    }

    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(SIG_TRANSFER, to, amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "BoringERC20: Transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(SIG_TRANSFER_FROM, from, to, amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "BoringERC20: TransferFrom failed");
    }
}

// a library for performing overflow-safe math, updated with awesomeness from of DappHub (https://github.com/dapphub/ds-math)
library BoringMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {require((c = a + b) >= b, "BoringMath: Add Overflow");}
    function sub(uint256 a, uint256 b) internal pure returns (uint256 c) {require((c = a - b) <= a, "BoringMath: Underflow");}
    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {require(b == 0 || (c = a * b)/b == a, "BoringMath: Mul Overflow");}
    function to128(uint256 a) internal pure returns (uint128 c) {
        require(a <= uint128(-1), "BoringMath: uint128 Overflow");
        c = uint128(a);
    }
    function to64(uint256 a) internal pure returns (uint64 c) {
        require(a <= uint64(-1), "BoringMath: uint64 Overflow");
        c = uint64(a);
    }
    function to32(uint256 a) internal pure returns (uint32 c) {
        require(a <= uint32(-1), "BoringMath: uint32 Overflow");
        c = uint32(a);
    }
}

library BoringMath128 {
    function add(uint128 a, uint128 b) internal pure returns (uint128 c) {require((c = a + b) >= b, "BoringMath: Add Overflow");}
    function sub(uint128 a, uint128 b) internal pure returns (uint128 c) {require((c = a - b) <= a, "BoringMath: Underflow");}
}

library BoringMath64 {
    function add(uint64 a, uint64 b) internal pure returns (uint64 c) {require((c = a + b) >= b, "BoringMath: Add Overflow");}
    function sub(uint64 a, uint64 b) internal pure returns (uint64 c) {require((c = a - b) <= a, "BoringMath: Underflow");}
}

library BoringMath32 {
    function add(uint32 a, uint32 b) internal pure returns (uint32 c) {require((c = a + b) >= b, "BoringMath: Add Overflow");}
    function sub(uint32 a, uint32 b) internal pure returns (uint32 c) {require((c = a - b) <= a, "BoringMath: Underflow");}
}

struct Rebase {
    uint128 elastic;
    uint128 base;
}

library RebaseLibrary {
    using BoringMath for uint256;
    using BoringMath128 for uint128;

    function toBase(Rebase memory total, uint256 elastic, bool roundUp) internal pure returns (uint256 base) {
        if (total.elastic == 0) {
            base = elastic;
        } else {
            base = elastic.mul(total.base) / total.elastic;
            if (roundUp && base.mul(total.elastic) / total.base < elastic) {
                base = base.add(1);
            }
        }
    }

    function toElastic(Rebase memory total, uint256 base, bool roundUp) internal pure returns (uint256 elastic) {
        if (total.base == 0) {
            elastic = base;
        } else {
            elastic = base.mul(total.elastic) / total.base;
            if (roundUp && elastic.mul(total.base) / total.elastic < base) {
                elastic = elastic.add(1);
            }
        }
    }

    function add(Rebase memory total, uint256 elastic, bool roundUp) internal pure returns (Rebase memory, uint256 base) {
        base = toBase(total, elastic, roundUp);
        total.elastic = total.elastic.add(elastic.to128());
        total.base = total.base.add(base.to128());
        return (total, base);
    }

    function sub(Rebase memory total, uint256 base, bool roundUp) internal pure returns (Rebase memory, uint256 elastic) {
        elastic = toElastic(total, base, roundUp);
        total.elastic = total.elastic.sub(elastic.to128());
        total.base = total.base.sub(base.to128());
        return (total, elastic);
    }

    function add(Rebase memory total, uint256 elastic, uint256 base) internal pure returns (Rebase memory) {
        total.elastic = total.elastic.add(elastic.to128());
        total.base = total.base.add(base.to128());
        return total;
    }    

    function sub(Rebase memory total, uint256 elastic, uint256 base) internal pure returns (Rebase memory) {
        total.elastic = total.elastic.sub(elastic.to128());
        total.base = total.base.sub(base.to128());
        return total;
    }    

    function addElastic(Rebase storage total, uint256 elastic) internal returns(uint256 newElastic) {
        newElastic = total.elastic = total.elastic.add(elastic.to128());
    }

    function subElastic(Rebase storage total, uint256 elastic) internal returns(uint256 newElastic) {
        newElastic = total.elastic = total.elastic.sub(elastic.to128());
    }
}

// P1 - P3: OK
// T1 - T4: OK
contract BaseBoringBatchable {
    function _getRevertMsg(bytes memory _returnData) internal pure returns (string memory) {
        // If the _res length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68) return "Transaction reverted silently";

        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }    
    
    // F3 - F9: OK
    // F1: External is ok here because this is the batch function, adding it to a batch makes no sense
    // F2: Calls in the batch may be payable, delegatecall operates in the same context, so each call in the batch has access to msg.value
    // C1 - C21: OK
    // C3: The length of the loop is fully under user control, so can't be exploited
    // C7: Delegatecall is only used on the same contract, so it's safe
    function batch(bytes[] calldata calls, bool revertOnFail) external payable returns(bool[] memory successes, bytes[] memory results) {
        // Interactions
        successes = new bool[](calls.length);
        results = new bytes[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(calls[i]);
            require(success || !revertOnFail, _getRevertMsg(result));
            successes[i] = success;
            results[i] = result;
        }
    }
}

// T1 - T4: OK
contract BoringBatchable is BaseBoringBatchable {
    // F1 - F9: OK
    // F6: Parameters can be used front-run the permit and the user's permit will fail (due to nonce or other revert)
    //     if part of a batch this could be used to grief once as the second call would not need the permit
    // C1 - C21: OK
    function permitToken(IERC20 token, address from, address to, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
        // Interactions
        // X1 - X5
        token.permit(from, to, amount, deadline, v, r, s);
    }
}

// Not compliant, renamed receiver to borrower and added receiver(s)
interface IERC3156FlashLender {
    function maxFlashAmount(
        IERC20 token
    ) external view returns (uint256);
    
    function flashFee(
        IERC20 token,
        uint256 amount
    ) external view returns (uint256);
    
    function flashLoan(
        IERC3156FlashBorrower borrower,
        address receiver,
        IERC20 token,
        uint256 amount,
        bytes calldata data
    ) external;
}

interface IERC3156BatchFlashLender is IERC3156FlashLender {
    function batchFlashLoan(
        IERC3156BatchFlashBorrower borrower,
        address[] calldata receivers,
        IERC20[] calldata tokens,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
}

interface IERC3156FlashBorrower {
    function onFlashLoan(
        address sender,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external;
}

interface IERC3156BatchFlashBorrower {
    function onBatchFlashLoan(
        address sender,
        IERC20[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata fees,
        bytes calldata data
    ) external;
}

interface IWETH {
    function deposit() external payable;
    function withdraw(uint256) external;
}

interface IStrategy {
    // Send the assets to the Strategy and call skim to invest them
    function skim(uint256 balance) external returns (uint256 amount);

    // Harvest any profits made converted to the asset and pass them to the caller
    function harvest(uint256 balance) external returns (int256 amountAdded);

    // Withdraw assets. The returned amount can differ from the requested amount due to rounding or if the request was more than there is.
    function withdraw(uint256 amount, uint256 balance) external returns (int256 amountAdded);

    // Withdraw all assets in the safest way possible. This shouldn't fail.
    function exit(uint256 balance) external returns (int256 amountAdded);
}

// P1 - P3: OK
pragma solidity 0.6.12;

// Source: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol + Claimable.sol
// Edited by BoringCrypto

// T1 - T4: OK
contract BoringOwnableData {
    // V1 - V5: OK
    address public owner;
    // V1 - V5: OK
    address public pendingOwner;
}

// T1 - T4: OK
contract BoringOwnable is BoringOwnableData {
    // E1: OK
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    address private constant ZERO_ADDRESS = address(0);

    constructor () public {
        owner = msg.sender;
        emit OwnershipTransferred(ZERO_ADDRESS, msg.sender);
    }

    // F1 - F9: OK
    // C1 - C21: OK
    function transferOwnership(address newOwner, bool direct, bool renounce) public onlyOwner {
        if (direct) {
            // Checks
            require(newOwner != ZERO_ADDRESS || renounce, "Ownable: zero address");

            // Effects
            emit OwnershipTransferred(owner, newOwner);
            owner = newOwner;
            pendingOwner = ZERO_ADDRESS;
        } else {
            // Effects
            pendingOwner = newOwner;
        }
    }

    // F1 - F9: OK
    // C1 - C21: OK
    function claimOwnership() public {
        address _pendingOwner = pendingOwner;
        
        // Checks
        require(msg.sender == _pendingOwner, "Ownable: caller != pending owner");

        // Effects
        emit OwnershipTransferred(owner, _pendingOwner);
        owner = _pendingOwner;
        pendingOwner = ZERO_ADDRESS;
    }

    // M1 - M5: OK
    // C1 - C21: OK
    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }
}

interface IMasterContract {
    function init(bytes calldata data) external payable;
}

pragma solidity 0.6.12;
contract BoringFactory {
    event LogDeploy(address indexed masterContract, bytes data, address indexed cloneAddress);

    mapping(address => address) public masterContractOf; // Mapping from clone contracts to their masterContract
    
    address private constant ZERO_ADDRESS = address(0);

    // Deploys a given master Contract as a clone.
    function deploy(address masterContract, bytes calldata data) public payable {
        require(masterContract != ZERO_ADDRESS, "BoringFactory: No masterContract");
        bytes20 targetBytes = bytes20(masterContract); // Takes the first 20 bytes of the masterContract's address
        address cloneAddress; // Address where the clone contract will reside.

        // Creates clone, more info here: https://blog.openzeppelin.com/deep-dive-into-the-minimal-proxy-contract/
        assembly {
            let clone := mload(0x40)
            mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(clone, 0x14), targetBytes)
            mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            cloneAddress := create(0, clone, 0x37)
        }
        masterContractOf[cloneAddress] = masterContract;

        IMasterContract(cloneAddress).init{value: msg.value}(data);

        emit LogDeploy(masterContract, data, cloneAddress);
    }
}

// P1 - P3: OK
// T1 - T4: OK
contract MasterContractManager is BoringOwnable, BoringFactory {
    // E1: OK
    event LogWhiteListMasterContract(address indexed masterContract, bool approved);
    // E1: OK
    event LogSetMasterContractApproval(address indexed masterContract, address indexed user, bool approved);

    // V1 - V5: OK
    mapping(address => mapping(address => bool)) public masterContractApproved; // masterContract to user to approval state
    // V1 - V5: OK
    mapping(address => bool) public whitelistedMasterContracts;
    // V1 - V5: OK
    mapping(address => uint256) public nonces;

    bytes32 private constant DOMAIN_SEPERATOR_SIGNATURE_HASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");
    
    // F1 - F8: OK
    // C1 - C19: OK
    // C20: Recalculating the domainSeparator is cheaper than reading it from storage
    function domainSeparator() private view returns (bytes32) {
        uint256 chainId;
        assembly {chainId := chainid()}
        return keccak256(abi.encode(
            DOMAIN_SEPERATOR_SIGNATURE_HASH, 
            "BentoBox V2",
            chainId, 
            address(this)
        ));
    }

    // F1 - F9: OK
    // F4: Approving masterContract 0 would be very bad, however it cannot be approved by the user and the owner should know better
    // C1 - C21: OK
    function whitelistMasterContract(address masterContract, bool approved) public onlyOwner {
        whitelistedMasterContracts[masterContract] = approved;
        emit LogWhiteListMasterContract(masterContract, approved);
    }

    // F1 - F9: OK
    // F4: Don't allow masterContract 0 to be approved. Unknown contracts will have a masterContract of 0.
    // F4: User can't be 0 for signed approvals because the recoveredAddress will be 0 if ecrecover fails
    // C1 - C21: OK
    function setMasterContractApproval(address user, address masterContract, bool approved, uint8 v, bytes32 r, bytes32 s) public {
        // Checks
        require(masterContract != address(0), "MasterCMgr: masterC not set"); // Important for security

        // If no signature is provided, the fallback is executed
        if (r == 0  && s == 0 && v == 0) {
            require(user == msg.sender, "MasterCMgr: user not sender");
            require(masterContractOf[user] == address(0), "MasterCMgr: user is clone");
            require(whitelistedMasterContracts[masterContract], "MasterCMgr: not whitelisted");
        } else {
            require(user != address(0), "MasterCMgr: User cannot be 0"); // Important for security
            // C10: nonce + chainId are used to prevent replays
            // C11: signature is EIP-712 compliant
            // C12: abi.encodePacked has fixed length parameters
            bytes32 digest = keccak256(abi.encodePacked(
                "\x19\x01", domainSeparator(),
                keccak256(abi.encode(
                    // keccak256("SetMasterContractApproval(string warning,address user,address masterContract,bool approved,uint256 nonce)");
                    0x1962bc9f5484cb7a998701b81090e966ee1fce5771af884cceee7c081b14ade2,
                    approved ? "Give FULL access to funds in (and approved to) BentoBox?" : "Revoke access to BentoBox?",
                    user, masterContract, approved, nonces[user]++
                ))
            ));
            address recoveredAddress = ecrecover(digest, v, r, s);
            require(recoveredAddress == user, "MasterCMgr: Invalid Signature");
        }

        // Effects
        masterContractApproved[masterContract][user] = approved;
        emit LogSetMasterContractApproval(masterContract, user, approved);
    }
}

// The BentoBox Plus

//  ▄▄▄▄· ▄▄▄ . ▐ ▄ ▄▄▄▄▄      ▄▄▄▄·       ▐▄• ▄ 
//  ▐█ ▀█▪▀▄.▀·█▌▐█•██  ▪     ▐█ ▀█▪▪      █▌█▌▪
//  ▐█▀▀█▄▐▀▀▪▄▐█▐▐▌ ▐█.▪ ▄█▀▄ ▐█▀▀█▄ ▄█▀▄  ·██· 
//  ██▄▪▐█▐█▄▄▌██▐█▌ ▐█▌·▐█▌.▐▌██▄▪▐█▐█▌.▐▌▪▐█·█▌ Plus!!
//  ·▀▀▀▀  ▀▀▀ ▀▀ █▪ ▀▀▀  ▀█▄▀▪·▀▀▀▀  ▀█▄▀▪•▀▀ ▀▀

// This contract stores funds, handles their transfers, supports flash loans and strategies.

// Copyright (c) 2021 BoringCrypto - All rights reserved
// Twitter: @Boring_Crypto

/// @title BentoBoxPlus
/// @author BoringCrypto, Keno
/// @notice The BentoBox is a vault for tokens. The stored tokens can be flash loaned. Fees for this will go to the token depositors.
/// Rebasing tokens ARE NOT supported and WILL cause loss of funds.
/// Any funds transfered directly onto the BentoBox will be lost, use the deposit function instead.
// T1 - T4: OK
contract BentoBoxPlus is MasterContractManager, BoringBatchable, IERC3156BatchFlashLender {
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

    // F1 - F10: OK
    // C1 - C23: OK
    // TODO: Reentrancy 
    function _assetAdded(IERC20 token, int256 amount) internal {
        // Effects
        if (amount > 0) {
            uint256 add = uint256(amount);
            totals[token].addElastic(add);
            emit LogStrategyProfit(token, add);
        } else if (amount < 0) {
            uint256 sub = uint256(-amount);
            totals[token].subElastic(sub);
            emit LogStrategyLoss(token, sub);
        }
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
    // REENT: Only for attack on other tokens + if WETH9 used, safe
    function deposit(
        IERC20 token_, address from, address to, uint256 amount, uint256 share
    ) public payable allowed(from) returns (uint256 amountOut, uint256 shareOut) {
        // Checks
        require(to != address(0), "BentoBox: to not set"); // To avoid a bad UI from burning funds

        // Effects
        IERC20 token = token_ == IERC20(0) ? wethToken : token_;
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
        require(from != address(this) || token_ == IERC20(0) || amount <= _tokenBalanceOf(token).sub(total.elastic), "BentoBox: Skim too much");

        balanceOf[token][to] = balanceOf[token][to].add(share);
        total.base = total.base.add(share.to128());
        total.elastic = total.elastic.add(amount.to128());
        totals[token] = total;

        // Interactions
        // During the first deposit, we check that this token is 'real'
        if (token_ == IERC20(0)) {
            // X1 - X5: OK
            // X2: If the WETH implementation is faulty or malicious, it will block adding ETH (but we know the WETH implementation)
            IWETH(address(wethToken)).deposit{value: amount}(); // REENT: Exit (if WETH9 used, safe)
        } else if (from != address(this)) {
            // X1 - X5: OK
            // X2: If the token implementation is faulty or malicious, it will block adding tokens. Good.
            token.safeTransferFrom(from, address(this), amount); // REENT: Exit (only for attack on other tokens)
        }
        emit LogDeposit(token, from, to, amount, share);
        amountOut = amount;
        shareOut = share;
    }

    // F1 - F10: OK
    // C1 - C22: OK
    // C2 - Are any storage slots read multiple times?
    // C2: wethToken is used multiple times, but this is an immutable, so after construction it's hardcoded in the contract
    // REENT: Yes
    function withdraw(
        IERC20 token_, address from, address to, uint256 amount, uint256 share
    ) public allowed(from) returns (uint256 amountOut, uint256 shareOut) {
        // Checks
        require(to != address(0), "BentoBox: to not set"); // To avoid a bad UI from burning funds

        // Effects
        IERC20 token = token_ == IERC20(0) ? wethToken : token_;
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
        if (token_ == IERC20(0)) {
            // X1 - X5: OK
            // X2, X3: A revert or big gas usage in the WETH contract could block withdrawals, but WETH9 is fine.
            IWETH(address(wethToken)).withdraw(amount); // REENT: Exit (if WETH9 used, safe)
            // X1 - X5: OK
            // X2, X3: A revert or big gas usage could block, however, the to address is under control of the caller.
            (bool success,) = to.call{value: amount}(""); // REENT: Exit
            require(success, "BentoBox: ETH transfer failed");
        } else {
            // X1 - X5: OK
            // X2, X3: A malicious token could block withdrawal of just THAT token.
            //         masterContracts may want to take care not to rely on withdraw always succeeding.
            token.safeTransfer(to, amount); // REENT: Exit (only for attack on other tokens)
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

    // F1 - F10: OK
    // C1 - C23: OK
    function maxFlashAmount(IERC20 token) public view override returns (uint256 amount) {
        amount = token.balanceOf(address(this));
    }

    // F1 - F10: OK
    // C1 - C23: OK
    function flashFee(IERC20, uint256 amount) public view override returns (uint256 fee) {
        fee = amount.mul(5) / 10000;
    }

    function flashLoan(IERC3156FlashBorrower borrower, address receiver, IERC20 token, uint256 amount, bytes calldata data) public override {
        uint256 fee = amount.mul(5) / 10000;
        token.safeTransfer(receiver, amount); // REENT: Exit (only for attack on other tokens)

        borrower.onFlashLoan(msg.sender, token, amount, fee, data); // REENT: Exit
        
        require(_tokenBalanceOf(token) >= totals[token].addElastic(fee.to128()), "BentoBoxPlus: Wrong amount");
        emit LogFlashLoan(address(borrower), token, amount, fee, receiver);
    }

    // F1 - F10: OK
    // F5 - Checks-Effects-Interactions pattern followed? (SWC-107)
    // F5: Not possible to follow this here, reentrancy needs a careful review
    // F6 - Check for front-running possibilities, such as the approve function (SWC-114)
    // F6: Slight grieving possible by withdrawing an amount before someone tries to flashloan close to the full amount.
    // C1 - C23: OK
    // REENT: Yes
    function batchFlashLoan(
        IERC3156BatchFlashBorrower borrower,
        address[] calldata receivers,
        IERC20[] calldata tokens,
        uint256[] calldata amounts,
        bytes calldata data
    ) public override {
        uint256[] memory fees = new uint256[](tokens.length);
        
        uint256 len = tokens.length;
        for (uint256 i = 0; i < len; i++) {
            uint256 amount = amounts[i];
            fees[i] = amount.mul(5) / 10000;

            tokens[i].safeTransfer(receivers[i], amounts[i]); // REENT: Exit (only for attack on other tokens)
        }

        borrower.onBatchFlashLoan(msg.sender, tokens, amounts, fees, data); // REENT: Exit

        for (uint256 i = 0; i < len; i++) {
            IERC20 token = tokens[i];
            // REENT: token.balanceOf(this) + strategy[token].balance <= total.amount
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
                _assetAdded(token, strategy[token].exit(data.balance)); // REENT: Exit (under our control, safe)
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
    // REENT: Can be used to increase (and maybe decrease) totals[token].amount
    function harvest(IERC20 token, bool balance, uint256 maxChangeAmount) public {
        _assetAdded(token, strategy[token].harvest(strategyData[token].balance));

        if (balance) {
            StrategyData memory data = strategyData[token];
            uint256 tokenBalance = token.balanceOf(address(this));
            uint256 targetBalance = tokenBalance.add(data.balance).mul(data.targetPercentage) / 100;
            if (data.balance < targetBalance) {
                IStrategy currentStrategy = strategy[token];
                uint256 amountOut = targetBalance.sub(data.balance);
                if (maxChangeAmount != 0 && amountOut > maxChangeAmount) { amountOut = maxChangeAmount; }
                token.safeTransfer(address(currentStrategy), amountOut); // REENT: Exit (only for attack on other tokens)
                strategyData[token].balance = data.balance.add(amountOut.to128());
                currentStrategy.skim(data.balance); // REENT: Exit (under our control, safe)
                emit LogStrategyInvest(token, amountOut);
            } else {
                uint256 amountIn = data.balance.sub(targetBalance.to128());
                if (maxChangeAmount != 0 && amountIn > maxChangeAmount) { amountIn = maxChangeAmount; }
                strategyData[token].balance = data.balance.sub(amountIn.to128());
                strategy[token].withdraw(amountIn, data.balance); // REENT: Exit (only for attack on other tokens)
                emit LogStrategyDivest(token, amountIn);
            }
        }
    }

    // Contract should be able to receive ETH deposits to support deposit & skim
    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}
}
