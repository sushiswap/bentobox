// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import "./IERC20.sol";

interface IVault {
    event ContractSet(address indexed masterContract, bool enabled);
    event Created(address indexed masterContract, bytes data, address clone_address);
    event FlashLoan(address indexed user, address indexed token, uint256 amount, uint256 fee);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event SwapperSet(address swapper, bool enabled);
    function contracts(address) external view returns (bool);
    function dev() external view returns (address);
    function feeTo() external view returns (address);
    function owner() external view returns (address);
    function renounceOwnership() external;
    function shareOf(IERC20, address) external view returns (uint256);
    function swappers(address) external view returns (bool);
    function totalBalance(IERC20) external view returns (uint256);
    function totalShare(IERC20) external view returns (uint256);
    function transferOwnership(address newOwner) external;
    function setContract(address newContract, bool enabled) external;
    function setSwapper(address swapper, bool enabled) external;
    function deploy(address masterContract, bytes calldata data) external;
    function toAmount(IERC20 token, uint256 share) external returns (uint256);
    function toShare(IERC20 token, uint256 amount) external returns (uint256);
    function transferShare(IERC20 token, address to, uint256 share) external returns (uint256);
    function transferShareFrom(IERC20 token, address from, uint256 share) external returns (uint256);
    function transferAmount(IERC20 token, address to, uint256 amount) external returns (uint256);
    function transferAmountFrom(IERC20 token, address from, uint256 amount) external returns (uint256);
    function addShare(IERC20 token, uint256 share) external returns (uint256);
    function addAmount(IERC20 token, uint256 amount) external returns (uint256);
    function skim(IERC20 token, address to) external;
    function sync(IERC20 token) external;
    function flashLoan(address user, IERC20 token, uint256 amount, bytes calldata params) external;
    function setFeeTo(address newFeeTo) external;
    function setDev(address newDev) external;
}