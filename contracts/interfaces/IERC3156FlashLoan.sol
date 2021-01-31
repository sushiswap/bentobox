// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;
import "@boringcrypto/boring-solidity/contracts/interfaces/IERC20.sol";

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