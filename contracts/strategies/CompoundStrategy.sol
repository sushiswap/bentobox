// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
import "../interfaces/IStrategy.sol";
import "@boringcrypto/boring-solidity/contracts/BoringOwnable.sol";
import "@boringcrypto/boring-solidity/contracts/libraries/BoringMath.sol";
import "@boringcrypto/boring-solidity/contracts/libraries/BoringERC20.sol";

// solhint-disable avoid-low-level-calls
// solhint-disable not-rely-on-time

interface IFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IPair {
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
}

interface IcToken is IERC20 {
    function mint(uint mintAmount) external returns (uint256);
    function redeem(uint redeemTokens) external returns (uint256);
    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);
    function balanceOfUnderlying(address account) external returns (uint256);
}

contract CompoundStrategy is IStrategy, BoringOwnable {
    using BoringMath for uint256;
    using BoringERC20 for IERC20;
    using BoringERC20 for IcToken;

    address public immutable bentobox;
    IERC20 public immutable token;
    IcToken public immutable cToken;
    IERC20 public immutable compToken;
    IERC20 public immutable weth;
    IFactory public immutable factory;
    uint256 public impactDivisor;  
    bool public exited;

    constructor(address bentobox_, IFactory factory_, IERC20 token_, IcToken cToken_, IERC20 compToken_, IERC20 weth_) public {
        bentobox = bentobox_;
        factory = factory_;
        token = token_;
        cToken = cToken_;
        compToken = compToken_;
        weth = weth_;
        impactDivisor = 10;    
    }

    function setImpactDivisor (uint256 impactDivisor_) public onlyOwner{
        impactDivisor = impactDivisor_;
    }

    modifier onlyBentobox {
        // Only the bentobox can call harvest on this strategy
        require(msg.sender == bentobox, "CompoundStrategy: only bento");
        _;
    }

    function _swap(
        address fromToken,
        address toToken,
        uint256 amountIn,
        address to
    ) internal returns (uint256 amountOut) {
        IPair pair = IPair(factory.getPair(fromToken, toToken));
        require(address(pair) != address(0), "CompoundStrategy: Cannot convert");

        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        uint256 amountInWithFee = amountIn.mul(997);
        if (fromToken == pair.token0()) {
            amountOut =
                amountIn.mul(997).mul(reserve1) /
                reserve0.mul(1000).add(amountInWithFee);
            IERC20(fromToken).safeTransfer(address(pair), amountIn);
            pair.swap(0, amountOut, to, new bytes(0));
            require(amountIn < reserve0 / impactDivisor, "CompoundStrategy: Impact");
        } else {
            amountOut =
                amountIn.mul(997).mul(reserve0) /
                reserve1.mul(1000).add(amountInWithFee);
            IERC20(fromToken).safeTransfer(address(pair), amountIn);
            pair.swap(amountOut, 0, to, new bytes(0));
            require(amountIn < reserve1 / impactDivisor, "CompoundStrategy: Impact");
        }
    }    

    // Send the assets to the Strategy and call skim to invest them
    /// @inheritdoc IStrategy
    function skim(uint256 amount) external override onlyBentobox {
        token.approve(address(cToken), amount);
        require(cToken.mint(amount) == 0, "CompoundStrategy: mint error");
    }

    // Harvest any profits made converted to the asset and pass them to the caller
    /// @inheritdoc IStrategy
    function harvest(uint256 balance, address sender) external override onlyBentobox returns (int256 amountAdded) {
        // Get the amount of tokens that the cTokens currently represent
        uint256 tokenBalance = cToken.balanceOfUnderlying(address(this));
        // Find out how much has been added from compounding interest. 
        // If it's negative due to rounding (near impossible), just revert. Should be positive soon enough.
        uint256 amountAdded_ = tokenBalance.sub(balance);
        // Convert enough cToken to take out the profit
        require(cToken.redeemUnderlying(amountAdded_) == 0, "CompoundStrategy: profit fail");
        // Transfer the profit to the bentobox, the amountAdded at this point matches the amount transferred
        cToken.safeTransfer(bentobox, amountAdded_);

        // To prevent flash loan sandwich attacks to 'steal' the profit, only the owner can harvest the COMP
        if (sender == owner) {
            // Swap all COMP to WETH
            _swap(address(compToken), address(weth), compToken.balanceOf(address(this)), address(this));
            // Swap all WETH to token and deliver it to the bentobox. Add the amountOut to the amountAdded.
            amountAdded_ = amountAdded_.add(_swap(address(weth), address(token), weth.balanceOf(address(this)), bentobox));
        }
        return int256(amountAdded_);
    }

    // Withdraw assets.
    /// @inheritdoc IStrategy
    function withdraw(uint256 amount) external override onlyBentobox returns (uint256 actualAmount) {
        // Convert enough cToken to take out 'amount' tokens
        require(cToken.redeemUnderlying(amount) == 0, "CompoundStrategy: redeem fail");

        // Make sure we send and report the exact same amount of tokens by using balanceOf
        actualAmount = token.balanceOf(address(this));
        token.safeTransfer(bentobox, actualAmount);
    }

    // Withdraw all assets in the safest way possible. This shouldn't fail.
    /// @inheritdoc IStrategy
    function exit(uint256 balance) external override onlyBentobox returns (int256 amountAdded) {
        // Get the amount of tokens that the cTokens currently represent
        uint256 tokenBalance = cToken.balanceOfUnderlying(address(this));
        // Get the actual token balance of the cToken contract
        uint256 available = token.balanceOf(address(cToken));

        // Check that the cToken contract has enough balance to pay out in full
        if (tokenBalance <= available) {
            // If there are more tokens available than our full position, take all based on cToken balance
            require(cToken.redeem(cToken.balanceOf(address(this))) == 0, "CompoundStrategy: redeem fail");
        } else {
            // Otherwise redeem all available and take a loss on the missing amount
            require(cToken.redeemUnderlying(available) == 0, "CompoundStrategy: redeem fail");
        }

        // Check balance of token on the contract
        uint256 amount = token.balanceOf(address(this));
        // Calculate tokens added (or lost)
        amountAdded = int256(amount) - int256(balance);
        // Transfer all tokens to bentobox
        token.safeTransfer(owner, amount);
        // Flag as exited, allowing the owner to manually deal with any amounts available later
        exited = true;
    }

    function afterExit(address to, uint256 value, bytes memory data) public onlyOwner returns(bool success) {
        // After exited, the owner can perform ANY call. This is to rescue any funds that didn't get released during exit or 
        // got earned afterwards due to vesting or airdrops, etc.
        require(exited, "CompoundStrategy: Not exited");
        (success,) = to.call{ value: value }(data);
    }
}
