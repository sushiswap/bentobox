pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;
// File: contracts\interfaces\IOracle.sol

// License-Identifier: MIT

interface IOracle {
    // Get the latest exchange rate, if no valid (recent) rate is available, return false
    function get(bytes calldata data) external returns (bool, uint256);
    function peek(bytes calldata data) external view returns (bool, uint256);
    function symbol(bytes calldata data) external view returns (string memory);
    function name(bytes calldata data) external view returns (string memory);
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
    event LogDeposit(address indexed token, address indexed from, address indexed to, uint256 amount);
    event LogFlashLoan(address indexed user, address indexed token, uint256 amount, uint256 feeAmount);
    event LogSetMasterContractApproval(address indexed masterContract, address indexed user, bool indexed approved);
    event LogTransfer(address indexed token, address indexed from, address indexed to, uint256 amount);
    event LogWithdraw(address indexed token, address indexed from, address indexed to, uint256 amount);
    function WETH() external view returns (IERC20);
    function balanceOf(IERC20, address) external view returns (uint256);
    function masterContractApproved(address, address) external view returns (bool);
    function masterContractOf(address) external view returns (address);
    function totalSupply(IERC20) external view returns (uint256);
    function deploy(address masterContract, bytes calldata data) external;
    function setMasterContractApproval(address masterContract, bool approved) external;
    function deposit(IERC20 token, address from, uint256 amount) external payable;
    function depositTo(IERC20 token, address from, address to, uint256 amount) external payable;
    function depositWithPermit(IERC20 token, address from, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external payable;
    function depositWithPermitTo(
        IERC20 token, address from, address to, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external payable;
    function withdraw(IERC20 token, address to, uint256 amount) external;
    function withdrawFrom(IERC20 token, address from, address to, uint256 amount) external;
    function transfer(IERC20 token, address to, uint256 amount) external;
    function transferFrom(IERC20 token, address from, address to, uint256 amount) external;
    function transferMultiple(IERC20 token, address[] calldata tos, uint256[] calldata amounts) external;
    function transferMultipleFrom(IERC20 token, address from, address[] calldata tos, uint256[] calldata amounts) external;
    function skim(IERC20 token) external returns (uint256 amount);
    function skimTo(IERC20 token, address to) external returns (uint256 amount);
    function skimETH() external returns (uint256 amount);
    function skimETHTo(address to) external returns (uint256 amount);
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

// File: contracts\interfaces\ILendingPair.sol

// License-Identifier: MIT

interface ILendingPair {
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
    event LogAccrue(uint256 accruedAmount, uint256 feeAmount, uint256 rate, uint256 utilization);
    event LogAddAsset(address indexed user, uint256 amount, uint256 fraction);
    event LogAddBorrow(address indexed user, uint256 amount, uint256 fraction);
    event LogAddCollateral(address indexed user, uint256 amount);
    event LogDev(address indexed newFeeTo);
    event LogExchangeRate(uint256 rate);
    event LogFeeTo(address indexed newFeeTo);
    event LogRemoveAsset(address indexed user, uint256 amount, uint256 fraction);
    event LogRemoveBorrow(address indexed user, uint256 amount, uint256 fraction);
    event LogRemoveCollateral(address indexed user, uint256 amount);
    event LogWithdrawFees();
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function accrueInfo() external view returns (uint64 interestPerBlock, uint64 lastBlockAccrued, uint128 feesPendingAmount);
    function allowance(address, address) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool success);
    function asset() external view returns (IERC20);
    function balanceOf(address) external view returns (uint256);
    function bentoBox() external view returns (IBentoBox);
    function borrowOpeningFee() external view returns (uint256);
    function claimOwnership() external;
    function closedCollaterizationRate() external view returns (uint256);
    function collateral() external view returns (IERC20);
    function dev() external view returns (address);
    function devFee() external view returns (uint256);
    function exchangeRate() external view returns (uint256);
    function feeTo() external view returns (address);
    function interestElasticity() external view returns (uint256);
    function liquidationMultiplier() external view returns (uint256);
    function masterContract() external view returns (ILendingPair);
    function maximumInterestPerBlock() external view returns (uint256);
    function maximumTargetUtilization() external view returns (uint256);
    function minimumInterestPerBlock() external view returns (uint256);
    function minimumTargetUtilization() external view returns (uint256);
    function nonces(address) external view returns (uint256);
    function openCollaterizationRate() external view returns (uint256);
    function oracle() external view returns (IOracle);
    function oracleData() external view returns (bytes memory);
    function owner() external view returns (address);
    function pendingOwner() external view returns (address);
    function permit(address owner_, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
    function protocolFee() external view returns (uint256);
    function renounceOwnership() external;
    function startingInterestPerBlock() external view returns (uint256);
    function swappers(ISwapper) external view returns (bool);
    function totalAsset() external view returns (uint128 amount, uint128 fraction);
    function totalBorrow() external view returns (uint128 amount, uint128 fraction);
    function totalCollateralAmount() external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool success);
    function transferFrom(address from, address to, uint256 amount) external returns (bool success);
    function transferOwnership(address newOwner) external;
    function transferOwnershipDirect(address newOwner) external;
    function userBorrowFraction(address) external view returns (uint256);
    function userCollateralAmount(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function symbol() external pure returns (string memory);
    function name() external pure returns (string memory);
    function decimals() external view returns (uint8);
    function init(bytes calldata data) external;
    function getInitData(IERC20 collateral_, IERC20 asset_, IOracle oracle_, bytes calldata oracleData_) external pure returns (bytes memory data);
    function accrue() external;
    function isSolvent(address user, bool open) external view returns (bool);
    function peekExchangeRate() external view returns (bool, uint256);
    function updateExchangeRate() external returns (uint256);
    function addCollateral(uint256 amount) external payable;
    function addCollateralTo(uint256 amount, address to) external payable;
    function addCollateralFromBento(uint256 amount) external;
    function addCollateralFromBentoTo(uint256 amount, address to) external;
    function addAsset(uint256 amount) external payable;
    function addAssetTo(uint256 amount, address to) external payable;
    function addAssetFromBento(uint256 amount) external payable;
    function addAssetFromBentoTo(uint256 amount, address to) external payable;
    function removeCollateral(uint256 amount, address to) external;
    function removeCollateralToBento(uint256 amount, address to) external;
    function removeAsset(uint256 fraction, address to) external;
    function removeAssetToBento(uint256 fraction, address to) external;
    function borrow(uint256 amount, address to) external;
    function borrowToBento(uint256 amount, address to) external;
    function repay(uint256 fraction) external;
    function repayFor(uint256 fraction, address beneficiary) external;
    function repayFromBento(uint256 fraction) external;
    function repayFromBentoTo(uint256 fraction, address beneficiary) external;
    function short(ISwapper swapper, uint256 assetAmount, uint256 minCollateralAmount) external;
    function unwind(ISwapper swapper, uint256 borrowFraction, uint256 maxAmountCollateral) external;
    function liquidate(address[] calldata users, uint256[] calldata borrowFractions, address to, ISwapper swapper, bool open) external;
    function batch(bytes[] calldata calls, bool revertOnFail) external payable returns (bool[] memory, bytes[] memory);
    function withdrawFees() external;
    function setSwapper(ISwapper swapper, bool enable) external;
    function setFeeTo(address newFeeTo) external;
    function setDev(address newDev) external;
    function swipe(IERC20 token) external;
}

// File: contracts\BentoHelper.sol

// SPDX-License-Identifier: MIT



contract BentoHelper {
    struct PairInfo {
        ILendingPair pair;
        IOracle oracle;
        IBentoBox bentoBox;
        address masterContract;
        bool masterContractApproved;
        IERC20 tokenAsset;
        IERC20 tokenCollateral;

        uint256 latestExchangeRate;
        uint256 lastBlockAccrued;
        uint256 interestRate;
        uint256 totalCollateralAmount;
        uint256 totalAssetAmount;
        uint256 totalBorrowAmount;

        uint256 totalAssetFraction;
        uint256 totalBorrowFraction;

        uint256 interestPerBlock;

        uint256 feesPendingAmount;

        uint256 userCollateralAmount;
        uint256 userAssetFraction;
        uint256 userAssetAmount;
        uint256 userBorrowFraction;
        uint256 userBorrowAmount;

        uint256 userAssetBalance;
        uint256 userCollateralBalance;
        uint256 userAssetAllowance;
        uint256 userCollateralAllowance;
    }

    function getPairs(address user, ILendingPair[] calldata pairs) public view returns (PairInfo[] memory info) {
        info = new PairInfo[](pairs.length);
        for(uint256 i = 0; i < pairs.length; i++) {
            ILendingPair pair = pairs[i];
            info[i].pair = pair;
            info[i].oracle = pair.oracle();
            IBentoBox bentoBox = pair.bentoBox();
            info[i].bentoBox = bentoBox;
            info[i].masterContract = address(pair.masterContract());
            info[i].masterContractApproved = bentoBox.masterContractApproved(info[i].masterContract, user);
            IERC20 asset = pair.asset();
            info[i].tokenAsset = asset;
            IERC20 collateral = pair.collateral();
            info[i].tokenCollateral = collateral;

            (, info[i].latestExchangeRate) = pair.peekExchangeRate();
            (info[i].interestPerBlock, info[i].lastBlockAccrued, info[i].feesPendingAmount) = pair.accrueInfo();
            info[i].totalCollateralAmount = pair.totalCollateralAmount();
            (info[i].totalAssetAmount, info[i].totalAssetFraction ) = pair.totalAsset();
            (info[i].totalBorrowAmount, info[i].totalBorrowFraction) = pair.totalBorrow();

            info[i].userCollateralAmount = pair.userCollateralAmount(user);
            info[i].userAssetFraction = pair.balanceOf(user);
            info[i].userAssetAmount = info[i].totalAssetFraction == 0 ? 0 :
                 info[i].userAssetFraction * info[i].totalAssetAmount / info[i].totalAssetFraction;
            info[i].userBorrowFraction = pair.userBorrowFraction(user);
            info[i].userBorrowAmount = info[i].totalBorrowFraction == 0 ? 0 :
                info[i].userBorrowFraction * info[i].totalBorrowAmount / info[i].totalBorrowFraction;

            info[i].userAssetBalance = info[i].tokenAsset.balanceOf(user);
            info[i].userCollateralBalance = info[i].tokenCollateral.balanceOf(user);
            info[i].userAssetAllowance = info[i].tokenAsset.allowance(user, address(bentoBox));
            info[i].userCollateralAllowance = info[i].tokenCollateral.allowance(user, address(bentoBox));
        }
    }
}
