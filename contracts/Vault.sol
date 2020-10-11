// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.12;
import "./libraries/BoringMath.sol";
import "./libraries/Ownable.sol";

interface IPair {
    function init(address vault_, address tokenA_, address tokenB_, address oracle_) external;
}

contract Vault is Ownable {
    using BoringMath for uint256;

    event PairCreated(address indexed pairContract, address indexed tokenA, address indexed tokenB, address oracle, address clone_address);

    mapping(address => bool) public pairContracts;
    mapping(address => bool) public swappers;
    mapping(address => bool) public isPair;

    function setPairContract(address pairContract, bool enabled) public {
        require(owner == msg.sender, "BentoBox: caller is not the owner");

        pairContracts[pairContract] = enabled;
    }

    function setSwapper(address swapper, bool enabled) public {
        require(owner == msg.sender, "BentoBox: caller is not the owner");

        swappers[swapper] = enabled;
    }

    function deploy(address pairContract, address tokenA, address tokenB, address oracle) public returns (address) {
        require(pairContracts[pairContract], 'BentoBox: Pair Contract not whitelisted');
        bytes20 targetBytes = bytes20(pairContract);
        address clone_address;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            let clone := mload(0x40)
            mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(clone, 0x14), targetBytes)
            mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            clone_address := create(0, clone, 0x37)
        }

        IPair(clone_address).init(address(this), tokenA, tokenB, oracle);
        isPair[clone_address] = true;

        emit PairCreated(pairContract, tokenA, tokenB, oracle, clone_address);
        return clone_address;
    }

    function transfer(address token, address to, uint256 amount) public returns (bool) {
        require(isPair[msg.sender], "BentoBox: Only pair contracts can transfer");

        // solium-disable-next-line security/no-low-level-calls
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "BentoBox: Transfer failed at ERC20");

        return true;
    }

    function transferFrom(address token, address from, uint256 amount) public returns (bool) {
        require(isPair[msg.sender], "BentoBox: Only pair contracts can transferFrom");

        // solium-disable-next-line security/no-low-level-calls
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, address(this), amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "BentoBox: TransferFrom failed at ERC20");
    }
}
