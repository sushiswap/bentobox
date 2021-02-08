// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
import "../interfaces/IStrategy.sol";
import "../libraries/SignedSafeMath.sol";
import "@boringcrypto/boring-solidity/contracts/BoringOwnable.sol";
import "@boringcrypto/boring-solidity/contracts/libraries/BoringMath.sol";
import "@boringcrypto/boring-solidity/contracts/libraries/BoringERC20.sol";

// solhint-disable not-rely-on-time

interface ISushiBar is IERC20 {
    function enter(uint256 _amount) external;

    function leave(uint256 _share) external;
}

contract MoneySink is IStrategy, BoringOwnable {
    using BoringMath for uint256;
    using BoringERC20 for IERC20;
    using SignedSafeMath for int256;

    uint256 private moneyLost;
    IERC20 public immutable sushi;

    constructor(IERC20 _sushi) public {
        sushi = _sushi;
    }

    // Send the assets to the Strategy and call skim to invest them
    function skim(uint256) external override {
        return;
    }

    // Harvest any profits made converted to the asset and pass them to the caller
    function harvest(uint256 balance, address) external override onlyOwner returns (int256 amountAdded) {
        uint256 _moneyLost = moneyLost.add(balance.mul(10000)) / 100000;
        uint256 amount = balance.mul(90000) / 100000;
        int256 moneyToBeLost = int256(amount).sub(int256(moneyLost));
        moneyLost = _moneyLost;
        amountAdded = moneyToBeLost.sub(int256(balance));
    }

    // Withdraw assets. The returned amount can differ from the requested amount due to rounding or if the request was more than there is.
    function withdraw(uint256 amount) external override onlyOwner returns (uint256 actualAmount) {
        uint256 balance = sushi.balanceOf(address(this));
        int256 moneyToBeTransferred = int256(balance).sub(int256(moneyLost));
        if (amount > moneyToBeTransferred.toUInt256()) {
            actualAmount = moneyToBeTransferred.toUInt256();
        } else {
            actualAmount = amount;
        }

        sushi.safeTransfer(owner, actualAmount);
    }

    // Withdraw all assets in the safest way possible. This shouldn't fail.
    function exit(uint256 balance) external override onlyOwner returns (int256 amountAdded) {
        uint256 amount = sushi.balanceOf(address(this)).mul(90000) / 100000;
        int256 moneyToBeTransferred = int256(amount).sub(int256(moneyLost));
        amountAdded = moneyToBeTransferred.sub(int256(balance));
        sushi.safeTransfer(owner, moneyToBeTransferred.toUInt256());
    }
}
