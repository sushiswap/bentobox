// SPDX-License-Identifier: UNLICENSED
// solium-disable security/no-inline-assembly
// solium-disable security/no-low-level-calls
pragma solidity ^0.6.12;
import "./libraries/BoringMath.sol";
import "./libraries/Ownable.sol";

interface IPair {
    function init(address vault_, address tokenA_, address tokenB_, address oracle_) external;
}

interface IFlashLoaner {
    function executeOperation(address token, uint256 amount, uint256 fee, bytes calldata params) external;
}

contract Vault is Ownable {
    using BoringMath for uint256;

    event PairContractSet(address indexed pairContract, bool enabled);
    event SwapperSet(address swapper, bool enabled);
    event PairCreated(address indexed pairContract, address indexed tokenA, address indexed tokenB, address oracle, address clone_address);
    event FlashLoan(address indexed user, address indexed token, uint256 amount, uint256 fee);

    mapping(address => bool) public pairContracts;
    mapping(address => bool) public swappers;
    mapping(address => bool) public isPair;
    mapping(address => uint256) public fees;

    function setPairContract(address pairContract, bool enabled) public onlyOwner() {
        pairContracts[pairContract] = enabled;
        emit PairContractSet(pairContract, enabled);
    }

    function setSwapper(address swapper, bool enabled) public onlyOwner() {
        swappers[swapper] = enabled;
        emit SwapperSet(swapper, enabled);
    }

    function deploy(address pairContract, address tokenA, address tokenB, address oracle, bytes calldata oracleData) public {
        require(pairContracts[pairContract], 'BentoBox: Pair Contract not whitelisted');
        bytes20 targetBytes = bytes20(pairContract);
        address clone_address;

        assembly {
            let clone := mload(0x40)
            mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(clone, 0x14), targetBytes)
            mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            clone_address := create(0, clone, 0x37)
        }

        (bool success,) = oracle.call(abi.encodePacked(oracleData, abi.encode(clone_address)));
        require(success, 'BentoBox Vault: oracle init failed.');

        IPair(clone_address).init(address(this), tokenA, tokenB, oracle);
        isPair[clone_address] = true;

        emit PairCreated(pairContract, tokenA, tokenB, oracle, clone_address);
    }

    function transfer(address token, address to, uint256 amount) public {
        require(isPair[msg.sender], "BentoBox: Only pair contracts can transfer");

        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "BentoBox: Transfer failed at ERC20");
    }

    function transferFrom(address token, address from, uint256 amount) public {
        require(isPair[msg.sender], "BentoBox: Only pair contracts can transferFrom");

        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, address(this), amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "BentoBox: TransferFrom failed at ERC20");
    }

    function flashLoan(address user, address token, uint256 amount, bytes calldata params) public {
        transfer(token, user, amount);

        uint256 fee = amount.mul(8).div(10000);

        IFlashLoaner(user).executeOperation(token, amount, fee, params);

        transferFrom(token, user, amount);
        emit FlashLoan(user, token, amount, fee);
    }

    function harvestFees(address token) public {

    }
}
