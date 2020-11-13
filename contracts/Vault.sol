// SPDX-License-Identifier: UNLICENSED
// solium-disable security/no-inline-assembly
// solium-disable security/no-low-level-calls
pragma solidity ^0.6.12;
import "./libraries/BoringMath.sol";
import "./libraries/Ownable.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IPair.sol";

interface IFlashLoaner {
    function executeOperation(IERC20 token, uint256 amount, uint256 fee, bytes calldata params) external;
}

// The BentoBox Vault and contract factory.
// This contract stores the funds, handles their transfers. Also takes care of fees, deploying contracts and flash loans.
contract Vault is Ownable {
    using BoringMath for uint256;

    event ContractSet(address indexed masterContract, bool enabled);
    event SwapperSet(address swapper, bool enabled);
    event Created(address indexed masterContract, bytes data, address clone_address);
    event FlashLoan(address indexed user, IERC20 indexed token, uint256 amount, uint256 fee);

    mapping(address => bool) public contracts; // Map of allowed master Contracts.
    mapping(address => bool) public swappers; // Map of allowed Swappers.

    mapping(IERC20 => mapping(address => uint256)) public shareOf; // Balance per token per address/contract
    mapping(IERC20 => uint256) public totalShare; // Total share per token
    mapping(IERC20 => uint256) public totalBalance; // Total balance per token
    address public feeTo;
    address public dev = 0x9e6e344f94305d36eA59912b0911fE2c9149Ed3E;

    // Disables / enables a given master contract. If the master contract doesn't exist yet, it gets added to the map.
    // When a master contract is disabled, it cannot be deployed. However, this doesn't affect already deployed clones.
    function setContract(address newContract, bool enabled) public onlyOwner() {
        contracts[newContract] = enabled;
        emit ContractSet(newContract, enabled);
    }

    // Disables / enables a given Swapper. If the Swapper doesn't exist yet, it gets added to the map.
    function setSwapper(address swapper, bool enabled) public onlyOwner() {
        swappers[swapper] = enabled;
        emit SwapperSet(swapper, enabled);
    }

    // Deploys a given master Contract as a clone.
    function deploy(address masterContract, bytes calldata data) public {
        require(contracts[masterContract], 'BentoBox: Contract not whitelisted');
        bytes20 targetBytes = bytes20(masterContract); // Takes the first 20 bytes of the masterContract's address
        address clone_address; // Address where the clone contract will reside.

        // Creates clone, more info here: https://blog.openzeppelin.com/deep-dive-into-the-minimal-proxy-contract/
        assembly {
            let clone := mload(0x40)
            mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(clone, 0x14), targetBytes)
            mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            clone_address := create(0, clone, 0x37)
        }

        (bool success,) = clone_address.call(data);
        require(success, 'BentoBox: contract init failed.');
        IPair(clone_address).setVault(address(this));

        emit Created(masterContract, data, clone_address);
    }

    function toAmount(IERC20 token, uint256 share) public view returns (uint256) {
        return share.mul(totalBalance[token]) / totalShare[token];
    }

    function toShare(IERC20 token, uint256 amount) public view returns (uint256) {
        return amount.mul(totalShare[token]) / totalBalance[token];
    }

    // Transfers funds from the vault (for msg.sender) to the user. Can be called by any contract or EOA.
    function transferShare(IERC20 token, address to, uint256 share) public returns (uint256) {
        shareOf[token][msg.sender] = shareOf[token][msg.sender].sub(share);
        uint256 amount = share.mul(totalBalance[token]) / totalShare[token];
        totalShare[token] = totalShare[token].sub(share);
        totalBalance[token] = totalBalance[token].sub(amount);

        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(0xa9059cbb, to, amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "BentoBox: Transfer failed at ERC20");
        return amount;
    }

    // Transfers funds from the user to the vault (for msg.sender). Can be called by any contract or EOA.
    function transferShareFrom(IERC20 token, address from, uint256 share) public returns (uint256) {
        shareOf[token][msg.sender] = shareOf[token][msg.sender].add(share);
        uint256 amount = totalShare[token] == 0 ? share : share.mul(totalBalance[token]) / totalShare[token];
        totalShare[token] = totalShare[token].add(share);
        totalBalance[token] = totalBalance[token].add(amount);

        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(0x23b872dd, from, address(this), amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "BentoBox: TransferFrom failed at ERC20");
        return amount;
    }

    // Transfers funds from the vault (for msg.sender) to the user. Can be called by any contract or EOA.
    function transferAmount(IERC20 token, address to, uint256 amount) public returns (uint256) {
        uint256 share = amount.mul(totalShare[token]) / totalBalance[token];
        shareOf[token][msg.sender] = shareOf[token][msg.sender].sub(share);
        totalShare[token] = totalShare[token].sub(share);
        totalBalance[token] = totalBalance[token].sub(amount);

        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(0xa9059cbb, to, amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "BentoBox: Transfer failed at ERC20");
        return share;
    }

    // Transfers funds from the user to the vault (for msg.sender). Can be called by any contract or EOA.
    function transferAmountFrom(IERC20 token, address from, uint256 amount) public returns (uint256) {
        uint256 share = totalShare[token] == 0 ? amount : amount.mul(totalShare[token]) / totalBalance[token];
        shareOf[token][msg.sender] = shareOf[token][msg.sender].add(share);
        totalShare[token] = totalShare[token].add(share);
        totalBalance[token] = totalBalance[token].add(amount);

        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(0x23b872dd, from, address(this), amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "BentoBox: TransferFrom failed at ERC20");
        return share;
    }

    // Register funds added to the vault (for msg.sender).
    function addShare(IERC20 token, uint256 share) public returns (uint256) {
        shareOf[token][msg.sender] = shareOf[token][msg.sender].add(share);
        uint256 amount = totalShare[token] == 0 ? share : share.mul(totalBalance[token]) / totalShare[token];
        totalShare[token] = totalShare[token].add(share);
        totalBalance[token] = totalBalance[token].add(amount);
        return amount;
    }

    // Register funds added to the vault (for msg.sender).
    function addAmount(IERC20 token, uint256 amount) public returns (uint256) {
        uint256 share = totalShare[token] == 0 ? amount : amount.mul(totalShare[token]) / totalBalance[token];
        shareOf[token][msg.sender] = shareOf[token][msg.sender].add(share);
        totalShare[token] = totalShare[token].add(share);
        totalBalance[token] = totalBalance[token].add(amount);
        return share;
    }

    function skim(IERC20 token, address to) public {
        uint256 amount = token.balanceOf(address(this)).sub(totalBalance[token]);
        uint256 share = totalShare[token] == 0 ? amount : amount.mul(totalShare[token]) / totalBalance[token];
        shareOf[token][to] = shareOf[token][to].add(share);
    }

    function sync(IERC20 token) public {
        totalBalance[token] = token.balanceOf(address(this));
    }

    // Take out a flash loan
    function flashLoan(address user, IERC20 token, uint256 amount, bytes calldata params) public {
        // Calculates the fee - 0.08% of the amount.
        uint256 fee = amount.mul(8) / 10000;

        transferAmount(token, user, amount);
        IFlashLoaner(user).executeOperation(token, amount, fee, params);
        transferAmountFrom(token, user, amount.add(fee));

        emit FlashLoan(user, token, amount, fee);
    }

    // Change the fee address
    function setFeeTo(address newFeeTo) public onlyOwner {
        feeTo = newFeeTo;
    }

    // Change the devfee address
    function setDev(address newDev) public {
        require(msg.sender == dev, 'BentoBox: Not dev');
        dev = newDev;
    }
}
