// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import "./IERC20.sol";

interface IVault {
    event FlashLoan(address indexed user, address indexed token, uint256 amount, uint256 fee);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event PairContractSet(address indexed pairContract, bool enabled);
    event PairCreated(address indexed pairContract, IERC20 indexed tokenCollateral, IERC20 indexed tokenAsset, address oracle, address clone_address);
    event SwapperSet(address swapper, bool enabled);
    function dev() external view returns (address);
    function feeTo() external view returns (address);
    function feesPending(address) external view returns (uint256);
    function isPair(address) external view returns (bool);
    function owner() external view returns (address);
    function pairContracts(address) external view returns (bool);
    function renounceOwnership() external;
    function swappers(address) external view returns (bool);
    function transferOwnership(address newOwner) external;
    function setPairContract(address pairContract, bool enabled) external;
    function setSwapper(address swapper, bool enabled) external;
    function setFeeTo(address newFeeTo) external;
    function setDev(address newDev) external;
    function deploy(address pairContract, IERC20 tokenCollateral, IERC20 tokenAsset, address oracle, bytes calldata oracleData) external;
    function transfer(IERC20 token, address to, uint256 amount) external;
    function transferFrom(IERC20 token, address from, uint256 amount) external;
    function flashLoan(address user, address token, uint256 amount, bytes calldata params) external;
    function withdrawFees(address token) external;
}