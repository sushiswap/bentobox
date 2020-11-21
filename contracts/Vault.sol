// SPDX-License-Identifier: UNLICENSED
// solium-disable security/no-inline-assembly
// solium-disable security/no-low-level-calls
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;
import "./libraries/BoringMath.sol";
import "./libraries/Ownable.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/ILendingPair.sol";

interface IWETH {
    function deposit() external payable;
    function withdraw(uint256) external;
}

interface IMasterContract {
    // JSON with information about the master contract
    function contractInfo() external view returns (string memory);
}

interface IFlashLoaner {
    function executeOperation(IERC20 token, uint256 amount, uint256 fee, bytes calldata params) external;
}

// The BentoBox Vault
// This contract stores the funds, handles their transfers. Also takes care of fees and flash loans.
contract Vault is Ownable {
    using BoringMath for uint256;

    event SwapperSet(address swapper, bool enabled);
    event Created(address indexed masterContract, bytes data, address clone_address);
    event FlashLoan(address indexed user, IERC20 indexed token, uint256 amount, uint256 fee);

    mapping(address => IMasterContract) public getMasterContract;
    mapping(address => bool) public swappers; // Map of allowed Swappers.

    mapping(IMasterContract => mapping(address => bool)) public masterContractApproved;
    mapping(IERC20 => mapping(address => uint256)) public shareOf; // Balance per token per address/contract
    mapping(IERC20 => uint256) public totalShare; // Total share per token
    mapping(IERC20 => uint256) public totalBalance; // Total balance per token
    address public feeTo;
    address public dev = 0x9e6e344f94305d36eA59912b0911fE2c9149Ed3E;
    // TODO: should we deploy our own WETH?
    IERC20 private weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    // Deploys a given master Contract as a clone.
    function deploy(address masterContract, bytes calldata data) public {
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
        getMasterContract[clone_address] = IMasterContract(masterContract);

        (bool success,) = clone_address.call(data);
        require(success, 'BentoBox: contract init failed.');
        ILendingPair(clone_address).setVault(address(this));

        emit Created(masterContract, data, clone_address);
    }    

    // *** View functions *** //
    function toAmount(IERC20 token, uint256 share) public view returns (uint256) {
        return share.mul(totalBalance[token]) / totalShare[token];
    }

    function toShare(IERC20 token, uint256 amount) public view returns (uint256) {
        uint256 _totalShare = totalShare[token];
        return _totalShare == 0 ? amount : amount.mul(_totalShare) / totalBalance[token];
    }

    // *** Public actions *** //
    function setMasterContractApproval(IMasterContract masterContract, bool approved) public {
        masterContractApproved[masterContract][msg.sender] = approved;
    }

    modifier allowed(address from) {
        require(msg.sender == from || masterContractApproved[getMasterContract[msg.sender]][from], 'BentoBox: Transfer not approved');
        _;
    }    

    function deposit(IERC20 token, address from, uint256 amount) public returns (uint256) { deposit(token, from, msg.sender, amount); }
    function deposit(IERC20 token, address from, address to, uint256 amount) public allowed(from) returns (uint256) {
        uint256 share = toShare(token, amount);
        _deposit(token, from, to, amount, share);
        return share;
    }

    function depositShare(IERC20 token, address from, uint256 share) public returns (uint256) { depositShare(token, from, msg.sender, share); }
    function depositShare(IERC20 token, address from, address to, uint256 share) public allowed(from) returns (uint256) {
        uint256 amount = toAmount(token, share);
        _deposit(token, from, to, amount, share);
        return amount;
    }

    function withdraw(IERC20 token, address to, uint256 amount) public returns (uint256) { withdraw(token, msg.sender, to, amount); }
    function withdraw(IERC20 token, address from, address to, uint256 amount) public allowed(from) returns (uint256) {
        uint256 share = toShare(token, amount);
        _withdraw(token, from, to, amount, share);
        return share;        
    }

    function withdrawShare(IERC20 token, address to, uint256 share) public returns (uint256) { withdrawShare(token, msg.sender, to, share); }
    function withdrawShare(IERC20 token, address from, address to, uint256 share) public allowed(from) returns (uint256) {
        uint256 amount = toAmount(token, share);
        _withdraw(token, from, to, amount, share);
        return amount;
    }

    // *** Approved contract actions *** //
    // Clones of master contracts can transfer from any account that has approved them
    function transferShareNew(IERC20 token, address from, address to, uint256 share) allowed(from) public {
        shareOf[token][from] = shareOf[token][from].sub(share);
        shareOf[token][to] = shareOf[token][to].add(share);
    }

    function skim(IERC20 token) public returns (uint256) { return skim(token, msg.sender); }
    function skim(IERC20 token, address to) public returns (uint256) {
        uint256 amount = token.balanceOf(address(this)).sub(totalBalance[token]);
        uint256 share = totalShare[token] == 0 ? amount : amount.mul(totalShare[token]) / totalBalance[token];
        shareOf[token][to] = shareOf[token][to].add(share);
        return share;
    }

    function sync(IERC20 token) public {
        totalBalance[token] = token.balanceOf(address(this));
    }

    // Take out a flash loan
    function flashLoan(address user, IERC20 token, uint256 amount, bytes calldata params) public {
        // Calculates the fee - 0.08% of the amount.
        uint256 fee = amount.mul(8) / 10000;
        uint256 total = amount.add(fee);

        // TODO: Reentrancy issue with sync!
        _withdraw(token, address(this), user, amount, toShare(token, amount));
        IFlashLoaner(user).executeOperation(token, amount, fee, params);
        _deposit(token, user, address(this), total, toShare(token, total));

        emit FlashLoan(user, token, amount, fee);
    }

    // *** Admin function *** //
    // Disables / enables a given Swapper. If the Swapper doesn't exist yet, it gets added to the map.
    function setSwapper(address swapper, bool enabled) public onlyOwner {
        swappers[swapper] = enabled;
        emit SwapperSet(swapper, enabled);
    }

    // Change the weth address
    function setWeth(IERC20 newWeth) public onlyOwner {
        weth = newWeth;
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

    function _deposit(IERC20 token, address from, address to, uint256 amount, uint256 share) internal {
        shareOf[token][to] = shareOf[token][to].add(share);
        totalShare[token] = totalShare[token].add(share);
        totalBalance[token] = totalBalance[token].add(amount);

        if (address(token) == address(weth)) {
            IWETH(address(weth)).deposit{value: msg.value}();
        } else {
            (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(0x23b872dd, from, address(this), amount));
            require(success && (data.length == 0 || abi.decode(data, (bool))), "BentoBox: TransferFrom failed at ERC20");
        }
    }

    function _withdraw(IERC20 token, address from, address to, uint256 amount, uint256 share) internal {
        shareOf[token][from] = shareOf[token][from].sub(share);
        totalShare[token] = totalShare[token].sub(share);
        totalBalance[token] = totalBalance[token].sub(amount);
        if (address(token) == address(weth)) {
            IWETH(address(weth)).withdraw(amount);
            (bool success,) = to.call{value: amount}(new bytes(0));
            require(success, "BentoBox: ETH transfer failed");
        } else {
            (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(0xa9059cbb, to, amount));
            require(success && (data.length == 0 || abi.decode(data, (bool))), "BentoBox: Transfer failed at ERC20");
        }
    }
}
