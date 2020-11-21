// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import "./IOracle.sol";
import "./IERC20.sol";
import "../BentoBox.sol";

interface ILendingPair {
    event AddAsset(address indexed user, uint256 amount, uint256 share);
    event AddBorrow(address indexed user, uint256 amount, uint256 share);
    event AddCollateral(address indexed user, uint256 amount, uint256 share);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
    event Initialized(address indexed masterContract, address clone_address);
    event NewExchangeRate(uint256 rate);
    event RemoveAsset(address indexed user, uint256 amount, uint256 share);
    event RemoveBorrow(address indexed user, uint256 amount, uint256 share);
    event RemoveCollateral(address indexed user, uint256 amount, uint256 share);
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    function approve(address spender, uint256 amount) external returns (bool success);
    function balanceOf(address) external view returns (uint256);
    function exchangeRate() external view returns (uint256);
    function feesPending() external view returns (uint256);
    function interestPerBlock() external view returns (uint256);
    function lastBlockAccrued() external view returns (uint256);
    function lastInterestBlock() external view returns (uint256);
    function name() external view returns (string memory);
    function oracle() external view returns (IOracle);
    function symbol() external view returns (string memory);
    function asset() external view returns (IERC20);
    function collateral() external view returns (IERC20);
    function totalAsset() external view returns (uint256);
    function totalBorrow() external view returns (uint256);
    function totalBorrowShare() external view returns (uint256);
    function totalCollateral() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool success);
    function transferFrom(address from, address to, uint256 amount) external returns (bool success);
    function userBorrowShare(address) external view returns (uint256);
    function userCollateral(address) external view returns (uint256);
    function bentoBox() external view returns (BentoBox);
    function decimals() external view returns (uint8);
    function init(IERC20 collateral_address, IERC20 asset_address, IOracle oracle_address, bytes calldata oracleData) external;
    function setBentoBox(address bentoBox_, address masterContract_) external;
    function getInitData(
        IERC20 collateral_address, IERC20 asset_address,
        IOracle oracle_address, bytes calldata oracleData) external pure returns (bytes memory);
    function accrue() external;
    function withdrawFees() external;
    function isSolvent(address user, bool open) external view returns (bool);
    function updateExchangeRate() external returns (uint256);
    function updateInterestRate() external;
    function addCollateral(uint256 amount) external;
    function addAsset(uint256 amount) external;
    function removeCollateral(uint256 share, address to) external;
    function removeAsset(uint256 share, address to) external;
    function borrow(uint256 amount, address to) external;
    function repay(uint256 share) external;
    function short(address swapper, uint256 amountAsset, uint256 minAmountCollateral) external;
    function unwind(address swapper, uint256 borrowShare, uint256 maxAmountCollateral) external;
    function liquidate(address[] calldata users, uint256[] calldata borrowShares, address to, address swapper, bool open) external;
}
