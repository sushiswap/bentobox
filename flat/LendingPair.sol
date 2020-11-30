pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

// File: contracts\libraries\BoringMath.sol
// License-Identifier: MIT
// a library for performing overflow-safe math, updated with awesomeness from of DappHub (https://github.com/dapphub/ds-math)
library BoringMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {require((c = a + b) >= b, "BoringMath: Add Overflow");}
    function sub(uint256 a, uint256 b) internal pure returns (uint256 c) {require((c = a - b) <= a, "BoringMath: Underflow");}
    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {require(b == 0 || (c = a * b)/b == a, "BoringMath: Mul Overflow");}
}

// File: contracts\interfaces\IOracle.sol
// License-Identifier: MIT
interface IOracle {
    // Get the latest exchange rate, if no valid (recent) rate is available, return false
    function get(bytes calldata data) external returns (bool, uint256);
    function peek(bytes calldata data) external view returns (bool, uint256);
}

// File: contracts\libraries\Ownable.sol
// License-Identifier: MIT
// Source: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol + Claimable.sol
// Edited by BoringCrypto
contract OwnableData {
    address public owner;
    address public pendingOwner;
}

contract Ownable is OwnableData {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () internal {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        pendingOwner = newOwner;
    }

    function transferOwnershipDirect(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function claimOwnership() public {
        require(msg.sender == pendingOwner, "Ownable: caller is not the pending owner");
        emit OwnershipTransferred(owner, pendingOwner);
        owner = pendingOwner;
        pendingOwner = address(0);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }
}

// File: contracts\ERC20.sol
// License-Identifier: MIT
// solium-disable security/no-inline-assembly
// solium-disable security/no-block-members

// Data part taken out for building of contracts that receive delegate calls
contract ERC20Data {
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping (address => uint256)) allowance;
    mapping(address => uint256) public nonces;
}

contract ERC20 is ERC20Data {
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    function transfer(address to, uint256 amount) public returns (bool success) {
        if (balanceOf[msg.sender] >= amount && amount > 0 && balanceOf[to] + amount > balanceOf[to]) {
            balanceOf[msg.sender] -= amount;
            balanceOf[to] += amount;
            emit Transfer(msg.sender, to, amount);
            return true;
        } else {
            return false;
        }
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool success) {
        if (balanceOf[from] >= amount && allowance[from][msg.sender] >= amount && amount > 0 && balanceOf[to] + amount > balanceOf[to]) {
            balanceOf[from] -= amount;
            allowance[from][msg.sender] -= amount;
            balanceOf[to] += amount;
            emit Transfer(from, to, amount);
            return true;
        } else {
            return false;
        }
    }

    function approve(address spender, uint256 amount) public returns (bool success) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function DOMAIN_SEPARATOR() public view returns (bytes32){
      uint256 chainId;
      assembly {chainId := chainid()}
      return keccak256(abi.encode(keccak256("EIP712Domain(uint256 chainId,address verifyingContract)"), chainId, address(this)));
    }

    function permit(address owner_, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
        require(block.timestamp < deadline, 'ERC20: Expired');
        bytes32 digest = keccak256(abi.encodePacked(
            '\x19\x01', DOMAIN_SEPARATOR(),
            keccak256(abi.encode(0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9, owner_, spender, value, nonces[owner_]++, deadline))
        ));
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress == owner_, 'ERC20: Invalid Signature');
        allowance[owner_][spender] = value;
        emit Approval(owner_, spender, value);
    }
}

// File: contracts\interfaces\IMasterContract.sol
// License-Identifier: MIT
interface IMasterContract {
    function init(bytes calldata data) external;
}

// File: contracts\interfaces\IERC20.sol
// License-Identifier: MIT
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // non-standard
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);

    // EIP 2612
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
}

// File: contracts\interfaces\IBentoBox.sol
// License-Identifier: MIT
interface IBentoBox {
    event LogDeploy(address indexed masterContract, bytes data, address indexed clone_address);
    event LogDeposit(address indexed token, address indexed from, address indexed to, uint256 amount, uint256 share);
    event LogFlashLoan(address indexed user, address indexed token, uint256 amount, uint256 feeAmount);
    event LogSetMasterContractApproval(address indexed masterContract, address indexed user, bool indexed approved);
    event LogTransfer(address indexed token, address indexed from, address indexed to, uint256 amount, uint256 share);
    event LogWithdraw(address indexed token, address indexed from, address indexed to, uint256 amount, uint256 share);
    function WETH() external view returns (IERC20);
    function masterContractApproved(address, address) external view returns (bool);
    function masterContractOf(address) external view returns (address);
    function shareOf(IERC20, address) external view returns (uint256);
    function totalAmount(IERC20) external view returns (uint256);
    function totalShare(IERC20) external view returns (uint256);
    function deploy(address masterContract, bytes calldata data) external;
    function toAmount(IERC20 token, uint256 share) external view returns (uint256 amount);
    function toShare(IERC20 token, uint256 amount) external view returns (uint256 share);
    function setMasterContractApproval(address masterContract, bool approved) external;
    function deposit(IERC20 token, address from, uint256 amount) external payable returns (uint256 share);
    function depositTo(IERC20 token, address from, address to, uint256 amount) external payable returns (uint256 share);
    function depositShare(IERC20 token, address from, uint256 share) external payable returns (uint256 amount);
    function depositShareTo(IERC20 token, address from, address to, uint256 share) external payable returns (uint256 amount);
    function depositWithPermit(IERC20 token, address from, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external payable returns (uint256 share);
    function depositWithPermitTo(IERC20 token, address from, address to, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external payable returns (uint256 share);
    function depositShareWithPermit(IERC20 token, address from, uint256 share, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external payable returns (uint256 amount);
    function depositShareWithPermitTo(IERC20 token, address from, address to, uint256 share, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external payable returns (uint256 amount);
    function withdraw(IERC20 token, address to, uint256 amount) external returns (uint256 share);
    function withdrawFrom(IERC20 token, address from, address to, uint256 amount) external returns (uint256 share);
    function withdrawShare(IERC20 token, address to, uint256 share) external returns (uint256 amount);
    function withdrawShareFrom(IERC20 token, address from, address to, uint256 share) external returns (uint256 amount);
    function transfer(IERC20 token, address to, uint256 amount) external returns (uint256 share);
    function transferFrom(IERC20 token, address from, address to, uint256 amount) external returns (uint256 share);
    function transferMultiple(IERC20 token, address[] calldata tos, uint256[] calldata amounts) external returns (uint256 sumShares);
    function transferMultipleFrom(IERC20 token, address from, address[] calldata tos, uint256[] calldata amounts)
        external returns (uint256 sumShares);
    function transferShare(IERC20 token, address to, uint256 share) external returns (uint256 amount);
    function transferShareFrom(IERC20 token, address from, address to, uint256 share) external returns (uint256 amount);
    function transferMultipleShare(IERC20 token, address[] calldata tos, uint256[] calldata shares) external returns (uint256 sumAmounts);
    function transferMultipleShareFrom(IERC20 token, address from, address[] calldata tos, uint256[] calldata shares)
        external returns (uint256 sumAmounts);
    function skim(IERC20 token) external returns (uint256 share);
    function skimTo(IERC20 token, address to) external returns (uint256 share);
    function skimETH() external returns (uint256 share);
    function skimETHTo(address to) external returns (uint256 share);
    function sync(IERC20 token) external;
    function flashLoan(IERC20 token, uint256 amount, address user, bytes calldata params) external;
    function flashLoanMultiple(IERC20[] calldata tokens, uint256[] calldata amounts, address user, bytes calldata params) external;
    function batch(bytes[] calldata calls, bool revertOnFail) external payable returns (bool[] memory successes, bytes[] memory results);
}

// File: contracts\interfaces\ISwapper.sol
// License-Identifier: MIT
interface ISwapper {
    // Withdraws 'amountFrom' of token 'from' from the BentoBox account for this swapper
    // Swaps it for at least 'amountToMin' of token 'to'
    // Transfers the swapped tokens of 'to' into the BentoBox using a plain ERC20 transfer
    // Returns the amount of tokens 'to' transferred to BentoBox
    // (The BentoBox skim function will be used by the caller to get the swapped funds)
    function swap(IERC20 from, IERC20 to, uint256 amountFrom, uint256 amountToMin) external returns (uint256 amountTo);

    // Calculates the amount of token 'from' needed to complete the swap (amountFrom), this should be less than or equal to amountFromMax
    // Withdraws 'amountFrom' of token 'from' from the BentoBox account for this swapper
    // Swaps it for exactly 'exactAmountTo' of token 'to'
    // Transfers the swapped tokens of 'to' into the BentoBox using a plain ERC20 transfer
    // Transfers allocated, but unused 'from' tokens within the BentoBox to 'refundTo' (amountFromMax - amountFrom)
    // Returns the amount of 'from' tokens withdrawn from BentoBox (amountFrom)
    // (The BentoBox skim function will be used by the caller to get the swapped funds)
    function swapExact(
        IERC20 from, IERC20 to, uint256 amountFromMax,
        uint256 exactAmountTo, address refundTo
    ) external returns (uint256 amountFrom);
}

// File: contracts\interfaces\IWETH.sol
// License-Identifier: MIT
interface IWETH {
    function deposit() external payable;
    function withdraw(uint256) external;
}

// File: contracts\LendingPair.sol
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
// THERE IS A KNOWN MAJOR EXPLOIT IN THIS VERSION, LEAVING IT IN FOR THE AUDITORS TO SPOT :P

// solium-disable security/no-low-level-calls

// TODO: check all reentrancy paths
// TODO: what to do when the entire pool is underwater?
// TODO: check that all actions on a users funds can only be initiated by that user as msg.sender

contract LendingPair is ERC20, Ownable, IMasterContract {
    using BoringMath for uint256;

    // MasterContract variables
    IBentoBox public immutable bentoBox;
    LendingPair public immutable masterContract;
    address public feeTo;
    address public dev;
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
    mapping(address => uint256) public userBorrowFraction;

    // Total shares
    uint256 public totalCollateralShare;
    uint256 public totalAssetShare; // Includes totalBorrowShare (actual Share in BentoBox = totalAssetShare - totalBorrowShare)
    uint256 public totalBorrowShare; // Total units of asset borrowed

    // Total fractions
    // totalAssetFraction is called totalSupply for ERC20 compatibility
    uint256 public totalBorrowFraction;

    // Fee share
    uint256 public feesPendingShare;

    // Exchange and interest rate tracking
    uint256 public exchangeRate;
    uint256 public interestPerBlock;
    uint256 public lastBlockAccrued;

    // ERC20 'variables'
    string public constant symbol = "BENTO M LP";
    string public constant name = "Bento Medium Risk Lending Pool";

    function decimals() public view returns (uint8) {
        (bool success, bytes memory data) = address(asset).staticcall(abi.encodeWithSelector(0x313ce567));
        return success && data.length == 32 ? abi.decode(data, (uint8)) : 18;
    }

    event LogExchangeRate(uint256 rate);
    event LogAddCollateral(address indexed user, uint256 share);
    event LogAddAsset(address indexed user, uint256 share, uint256 fraction);
    event LogAddBorrow(address indexed user, uint256 share, uint256 fraction);
    event LogRemoveCollateral(address indexed user, uint256 share);
    event LogRemoveAsset(address indexed user, uint256 share, uint256 fraction);
    event LogRemoveBorrow(address indexed user, uint256 share, uint256 fraction);

    constructor(IBentoBox bentoBox_) public {
        bentoBox = bentoBox_;
        masterContract = LendingPair(this);
        dev = msg.sender;
        feeTo = msg.sender;
    }

    // Settings for the Medium Risk LendingPair
    uint256 public constant closedCollaterizationRate = 75000; // 75%
    uint256 public constant openCollaterizationRate = 77000; // 77%
    uint256 public constant minimumTargetUtilization = 7e17; // 70%
    uint256 public constant maximumTargetUtilization = 8e17; // 80%

    uint256 public constant startingInterestPerBlock = 4566210045; // approx 1% APR
    uint256 public constant minimumInterestPerBlock = 1141552511; // approx 0.25% APR
    uint256 public constant maximumInterestPerBlock = 4566210045000;  // approx 1000% APR
    uint256 public constant interestElasticity = 2000e36; // Half or double in 2000 blocks (approx 8 hours)

    uint256 public constant liquidationMultiplier = 112000; // add 12%

    // Fees
    uint256 public constant protocolFee = 10000; // 10%
    uint256 public constant devFee = 10000; // 10% of the protocolFee = 1%
    uint256 public constant borrowOpeningFee = 50; // 0.05%

    // Serves as the constructor, as clones can't have a regular constructor
    function init(bytes calldata data) public override {
        require(address(collateral) == address(0), 'LendingPair: already initialized');
        (collateral, asset, oracle, oracleData) = abi.decode(data, (IERC20, IERC20, IOracle, bytes));

        interestPerBlock = startingInterestPerBlock;  // 1% APR, with 1e18 being 100%
    }

    function getInitData(IERC20 collateral_, IERC20 asset_, IOracle oracle_, bytes calldata oracleData_) public pure returns(bytes memory data) {
        return abi.encode(collateral_, asset_, oracle_, oracleData_);
    }

    // Accrues the interest on the borrowed tokens and handles the accumulation of fees
    function accrue() public {
        // Number of blocks since accrue was called
        uint256 blocks = block.number - lastBlockAccrued;
        if (blocks == 0) {return;}
        lastBlockAccrued = block.number;

        if (totalBorrowShare > 0) {
            // Accrue interest
            uint256 extraShare = totalBorrowShare.mul(interestPerBlock).mul(blocks) / 1e18;
            uint256 feeShare = extraShare.mul(protocolFee) / 1e5; // % of interest paid goes to fee
            totalBorrowShare = totalBorrowShare.add(extraShare);
            totalAssetShare = totalAssetShare.add(extraShare.sub(feeShare));
            feesPendingShare = feesPendingShare.add(feeShare);
        }

        if (totalAssetShare == 0) {
            if (interestPerBlock != startingInterestPerBlock) {
                interestPerBlock = startingInterestPerBlock;
            }
            return;
        }

        // Update interest rate
        uint256 utilization = totalBorrowShare.mul(1e18) / totalAssetShare;
        uint256 newInterestPerBlock;
        if (utilization < minimumTargetUtilization) {
            uint256 underFactor = uint256(minimumTargetUtilization).sub(utilization).mul(1e18) / minimumTargetUtilization;
            uint256 scale = uint256(interestElasticity).add(underFactor.mul(underFactor).mul(blocks));
            newInterestPerBlock = interestPerBlock.mul(interestElasticity) / scale;
            if (newInterestPerBlock < minimumInterestPerBlock) {newInterestPerBlock = minimumInterestPerBlock;} // 0.25% APR minimum
       } else if (utilization > maximumTargetUtilization) {
            uint256 overFactor = utilization.sub(maximumTargetUtilization).mul(1e18) / uint256(1e18).sub(maximumTargetUtilization);
            uint256 scale = uint256(interestElasticity).add(overFactor.mul(overFactor).mul(blocks));
            newInterestPerBlock = interestPerBlock.mul(scale) / interestElasticity;
            if (newInterestPerBlock > maximumInterestPerBlock) {newInterestPerBlock = maximumInterestPerBlock;} // 1000% APR maximum
        } else {return;}

        interestPerBlock = newInterestPerBlock;
    }

    // Checks if the user is solvent.
    // Has an option to check if the user is solvent in an open/closed liquidation case.
    function isSolvent(address user, bool open) public view returns (bool) {
        // accrue must have already been called!
        if (userBorrowFraction[user] == 0) return true;
        if (totalCollateralShare == 0) return false;

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
            emit LogExchangeRate(rate);
        }
        return exchangeRate;
    }

    // Handles internal variable updates when collateral is deposited
    function _addCollateralShare(address user, uint256 share) private {
        // Adds this share to user
        userCollateralShare[user] = userCollateralShare[user].add(share);
        // Adds the share deposited to the total of collateral
        totalCollateralShare = totalCollateralShare.add(share);
        emit LogAddCollateral(msg.sender, share);
    }

    // Handles internal variable updates when supply (the borrowable token) is deposited
    function _addAssetShare(address user, uint256 share) private {
        // Calculates what share of the pool the user gets for the amount deposited
        uint256 newFraction = totalSupply == 0 ? share : share.mul(totalSupply) / totalAssetShare;
        // Adds this share to user
        balanceOf[user] = balanceOf[user].add(newFraction);
        // Adds this share to the total of supply shares
        totalSupply = totalSupply.add(newFraction);
        // Adds the amount deposited to the total of supply
        totalAssetShare = totalAssetShare.add(share);
        emit LogAddAsset(msg.sender, share, newFraction);
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
        emit LogAddBorrow(msg.sender, share, newFraction);
    }

    // Handles internal variable updates when collateral is withdrawn and returns the amount of collateral withdrawn
    function _removeCollateralShare(address user, uint256 share) private {
        // Subtracts the share from user
        userCollateralShare[user] = userCollateralShare[user].sub(share);
        // Subtracts the amount from the total of collateral
        totalCollateralShare = totalCollateralShare.sub(share);
        emit LogRemoveCollateral(msg.sender, share);
    }

    // Handles internal variable updates when supply is withdrawn and returns the amount of supply withdrawn
    function _removeAssetFraction(address user, uint256 fraction) private returns (uint256 share) {
        // Subtracts the fraction from user
        balanceOf[user] = balanceOf[user].sub(fraction);
        // Calculates the share of tokens to withdraw
        share = fraction.mul(totalAssetShare) / totalSupply;
        // Subtracts the calculated fraction from the total of supply
        totalSupply = totalSupply.sub(fraction);
        // Subtracts the share from the total of supply shares
        totalAssetShare = totalAssetShare.sub(share);
        emit LogRemoveAsset(msg.sender, share, fraction);
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
        emit LogRemoveBorrow(msg.sender, share, fraction);
    }

    // Deposits an amount of collateral from the caller
    function addCollateral(uint256 amount) public payable { addCollateralTo(amount, msg.sender); }
    function addCollateralTo(uint256 amount, address to) public payable {
        _addCollateralShare(to, bentoBox.deposit{value: msg.value}(collateral, msg.sender, amount));
    }

    function addCollateralFromBento(uint256 share) public { addCollateralFromBentoTo(share, msg.sender); }
    function addCollateralFromBentoTo(uint256 share, address to) public {
        bentoBox.transferShareFrom(collateral, msg.sender, address(this), share);
        _addCollateralShare(to, share);
    }

    // Deposits an amount of supply (the borrowable token) from the caller
    function addAsset(uint256 amount) public payable { addAssetTo(amount, msg.sender); }
    function addAssetTo(uint256 amount, address to) public payable {
        // Accrue interest before calculating pool shares in _addAssetShare
        accrue();
        _addAssetShare(to, bentoBox.deposit{value: msg.value}(asset, msg.sender, amount));
    }

    function addAssetFromBento(uint256 share) public payable { addAssetFromBentoTo(share, msg.sender); }
    function addAssetFromBentoTo(uint256 share, address to) public payable {
        // Accrue interest before calculating pool shares in _addAssetShare
        accrue();
        bentoBox.transferShareFrom(asset, msg.sender, address(this), share);
        _addAssetShare(to, share);
    }

    // Withdraws a share of collateral of the caller to the specified address
    function removeCollateral(uint256 share, address to) public {
        accrue();
        _removeCollateralShare(msg.sender, share);
        // Only allow withdrawing if user is solvent (in case of a closed liquidation)
        require(isSolvent(msg.sender, false), 'LendingPair: user insolvent');
        bentoBox.withdrawShare(collateral, to, share);
    }

    function removeCollateralToBento(uint256 share, address to) public {
        accrue();
        _removeCollateralShare(msg.sender, share);
        // Only allow withdrawing if user is solvent (in case of a closed liquidation)
        require(isSolvent(msg.sender, false), 'LendingPair: user insolvent');
        bentoBox.transferShare(collateral, to, share);
    }

    // Withdraws a share of supply (the borrowable token) of the caller to the specified address
    function removeAsset(uint256 fraction, address to) public {
        // Accrue interest before calculating pool shares in _removeAssetFraction
        accrue();
        uint256 share = _removeAssetFraction(msg.sender, fraction);
        bentoBox.withdrawShare(asset, to, share);
    }

    function removeAssetToBento(uint256 fraction, address to) public {
        // Accrue interest before calculating pool shares in _removeAssetFraction
        accrue();
        uint256 share = _removeAssetFraction(msg.sender, fraction);
        bentoBox.transferShare(asset, to, share);
    }

    // Borrows the given amount from the supply to the specified address
    function borrow(uint256 amount, address to) public {
        accrue();
        uint256 share = bentoBox.withdraw(asset, to, amount); // TODO: reentrancy issue?
        uint256 feeShare = share.mul(borrowOpeningFee) / 1e5; // A flat % fee is charged for any borrow
        _addBorrowShare(msg.sender, share.add(feeShare));
        totalAssetShare = totalAssetShare.add(feeShare);
        require(isSolvent(msg.sender, false), 'LendingPair: user insolvent');
    }

    function borrowToBento(uint256 share, address to) public {
        accrue();
        bentoBox.transferShare(asset, to, share);
        uint256 feeShare = share.mul(borrowOpeningFee) / 1e5; // A flat % fee is charged for any borrow
        _addBorrowShare(msg.sender, share.add(feeShare));
        totalAssetShare = totalAssetShare.add(feeShare);
        require(isSolvent(msg.sender, false), 'LendingPair: user insolvent');
    }

    // Repays the given fraction
    function repay(uint256 fraction) public { repayFor(fraction, msg.sender); }
    function repayFor(uint256 fraction, address beneficiary) public {
        accrue();
        uint256 share = _removeBorrowFraction(beneficiary, fraction);
        bentoBox.depositShare(asset, msg.sender, share);
    }

    function repayFromBento(uint256 fraction) public { repayFromBentoTo(fraction, msg.sender); }
    function repayFromBentoTo(uint256 fraction, address beneficiary) public {
        accrue();
        uint256 share = _removeBorrowFraction(beneficiary, fraction);
        bentoBox.transferShareFrom(asset, msg.sender, address(this), share);
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
                emit LogRemoveCollateral(user, collateralShare);
                emit LogRemoveBorrow(user, borrowShare, borrowFraction);

                // Keep totals
                allCollateralShare = allCollateralShare.add(collateralShare);
                allBorrowShare = allBorrowShare.add(borrowShare);
                allBorrowFraction = allBorrowFraction.add(borrowFraction);
            }
        }
        require(allBorrowShare != 0, 'LendingPair: all users are solvent');
        totalBorrowShare = totalBorrowShare.sub(allBorrowShare);
        totalBorrowFraction = totalBorrowFraction.sub(allBorrowFraction);
        totalCollateralShare = totalCollateralShare.sub(allCollateralShare);

        if (!open) {
            // Closed liquidation using a pre-approved swapper for the benefit of the LPs
            require(masterContract.swappers(swapper), 'LendingPair: Invalid swapper');

            // Swaps the users' collateral for the borrowed asset
            uint256 suppliedAmount = bentoBox.transferShareFrom(collateral, address(this), address(swapper), allCollateralShare);
            swapper.swap(collateral, asset, suppliedAmount, bentoBox.toAmount(asset, allBorrowShare));
            uint256 returnedAssetShare = bentoBox.skim(asset);
            uint256 extraAssetShare = returnedAssetShare.sub(allBorrowShare);

            // The extra asset gets added to the pool
            uint256 feeShare = extraAssetShare.mul(protocolFee) / 1e5; // % of profit goes to fee
            feesPendingShare = feesPendingShare.add(feeShare);
            totalAssetShare = totalAssetShare.add(extraAssetShare.sub(feeShare));
            emit LogAddAsset(address(0), extraAssetShare, 0);
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
            emit LogAddAsset(address(0), extraAsset, 0);
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

    // Withdraws the fees accumulated
    function withdrawFees() public {
        accrue();
        address _feeTo = masterContract.feeTo();
        address _dev = masterContract.dev();
        uint256 feeShare = feesPendingShare.sub(1);
        uint256 devFeeShare = _dev == address(0) ? 0 : feeShare.mul(devFee) / 1e5;
        feesPendingShare = 1; // Don't set it to 0 as that would increase the gas cost for the next accrue called by a user.
        bentoBox.withdrawShare(asset, _feeTo, feeShare.sub(devFeeShare));
        if (devFeeShare > 0) {
            bentoBox.withdrawShare(asset, _dev, devFeeShare);
        }
    }

    // Admin functions
    function setSwapper(ISwapper swapper, bool enable) public onlyOwner {
        swappers[swapper] = enable;
    }

    function setFeeTo(address newFeeTo) public onlyOwner { feeTo = newFeeTo; }
    function setDev(address newDev) public { require(msg.sender == dev, 'LendingPair: Not dev'); dev = newDev; }

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
