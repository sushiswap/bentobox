pragma solidity 0.6.12;
import "@boringcrypto/boring-solidity/contracts/libraries/BoringERC20.sol";
import "../../contracts/BentoBox.sol";


contract Borrower {

    fallback() external payable { }
    receive() external payable { }

    BentoBox public bentoBox ;
    uint256 send;

    uint256 public callBack;

    address from;
    address to; 
    uint256 amount; 
    uint256 share;
    bool balance; 
    uint256 maxChangeAmount;

    function onFlashLoan(
        address sender, 
        IERC20 token, 
        uint256 amount, 
        uint256 fee, 
        bytes calldata data) external 
    {
        if (callBack == 1)
            bentoBox.deposit(token, from, to, amount, share);
        else if(callBack == 2)
            bentoBox.withdraw(token, from, to, amount, share);
        else if(callBack == 3)
            bentoBox.transfer(token, from, to, share);
        else if(callBack == 4)
            bentoBox.harvest(token, balance, maxChangeAmount); 
        token.transfer(address(bentoBox), send);
    }

    uint256[] sends;
    function onBatchFlashLoan(
        address sender,
        IERC20[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata fees,
        bytes calldata data
    ) external {
        uint256 len = tokens.length;
        for (uint256 i = 0; i < len; i++) {
            tokens[i].transfer(address(bentoBox), sends[i]);
        }
    }

}
