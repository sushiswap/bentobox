// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;
import "./IERC20.sol";

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