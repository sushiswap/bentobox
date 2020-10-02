// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.12;
import "./libraries/BoringMath.sol";
import "./libraries/Ownable.sol";

interface IPair {
    function init(address vault_, address tokenA_, address tokenB_, address oracle_) external;
}

contract Vault is Ownable {
    using BoringMath for uint256;

    // List of reviewed and approved pair contracts that can be used
    mapping(address => bool) public pairContracts;
    mapping(address => bool) public closedLiquidationContracts;

    function addPairContract(address pairContract) public {
        require(owner == msg.sender, "BentoBox: caller is not the owner");

        pairContracts[pairContract] = true;
    }

    function removePairContract(address pairContract) public {
        require(owner == msg.sender, "BentoBox: caller is not the owner");

        pairContracts[pairContract] = false;
    }

    function addClosedLiquidationContract(address closedLiquidationContract) public {
        require(owner == msg.sender, "BentoBox: caller is not the owner");

        closedLiquidationContracts[closedLiquidationContract] = true;
    }

    function removeClosedLiquidationContract(address closedLiquidationContract) public {
        require(owner == msg.sender, "BentoBox: caller is not the owner");

        closedLiquidationContracts[closedLiquidationContract] = false;
    }

    uint32 public totalPairs;
    mapping(uint32 => address) public pairs;
    mapping(address => bool) public isPair;

    /**
     * @dev Creates a new option series and deploys the cloned contract.
     */
    // solium-disable-next-line security/no-inline-assembly
    function deploy(address pairContract, address tokenA_, address tokenB_, address oracle_) public returns (address) {
        require(pairContracts[pairContract], 'BentoBox: Pair Contract not whitelisted');
        bytes20 targetBytes = bytes20(pairContract);
        address clone_address;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            let clone := mload(0x40)
            mstore(
                clone,
                0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            mstore(add(clone, 0x14), targetBytes)
            mstore(
                add(clone, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            clone_address := create(0, clone, 0x37)
        }

        isPair[clone_address] = true;
        pairs[totalPairs] = clone_address;
        totalPairs++;

        IPair(clone_address).init(address(this), tokenA_, tokenB_, oracle_);

        return clone_address;
    }

    /**
     * @dev Calls 'transfer' on an ERC20 token. Sends funds from the vault to the user.
     * @param token The contract address of the ERC20 token.
     * @param to The address to transfer the tokens to.
     * @param amount The amount to transfer.
     */
    function transfer(address token, address to, uint256 amount) public returns (bool) {
        require(isPair[msg.sender], "BentoBox: Only pair contracts can transfer");

        // solium-disable-next-line security/no-low-level-calls
        (bool success, bytes memory data) = token.call(
            // 0xa9059cbb = bytes4(keccak256("transferFrom(address,address,uint256)"))
            abi.encodeWithSelector(0xa9059cbb, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "BentoBox: Transfer failed at ERC20");

        return true;
    }

    /**
     * @dev Calls 'transferFrom' on an ERC20 token. Pulls funds from the user into vault.
     * @param token The contract address of the ERC20 token.
     * @param from The address to transfer the tokens from.
     * @param amount The amount to transfer.
     */
    function transferFrom(address token, address from, uint256 amount) public returns (bool) {
        require(isPair[msg.sender], "BentoBox: Only pair contracts can transferFrom");

        // solium-disable-next-line security/no-low-level-calls
        (bool success, bytes memory data) = token.call(
            // 0x23b872dd = bytes4(keccak256("transferFrom(address,address,uint256)"))
            abi.encodeWithSelector(0x23b872dd, from, address(this), amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "BentoBox: TransferFrom failed at ERC20");
    }
}
