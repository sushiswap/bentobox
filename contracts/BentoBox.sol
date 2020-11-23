// SPDX-License-Identifier: UNLICENSED
// solium-disable security/no-inline-assembly
// solium-disable security/no-low-level-calls
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;
import "./libraries/BoringMath.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IMasterContract.sol";
import "./interfaces/IFlashLoaner.sol";

// The BentoBox
// This contract stores the funds, handles their transfers. Also takes care of fees and flash loans.
contract BentoBox {
    using BoringMath for uint256;

    event Created(address indexed masterContract, bytes data, address indexed clone_address);
    event FlashLoaned(address indexed user, IERC20 indexed token, uint256 amount, uint256 fee);
    event MasterContractApprovalSet(address indexed masterContract, address indexed user, bool indexed approved);
    // TODO: Add events for transfers?

    mapping(address => address) public getMasterContract; // Mapping from clone contracts to their masterContract
    mapping(address => mapping(address => bool)) public masterContractApproved; // Mapping from masterContract to user to approval state
    mapping(IERC20 => mapping(address => uint256)) public shareOf; // Balance per token per address/contract
    mapping(IERC20 => uint256) public totalShare; // Total share per token
    mapping(IERC20 => uint256) public totalBalance; // Total balance per token
    IERC20 private WETH; // TODO: Hardcode WETH on final deploy and remove constructor
    //IERC20 private constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    constructor(IERC20 WETH_) public {
        WETH = WETH_;
    }

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
        getMasterContract[clone_address] = masterContract;

        (bool success,) = clone_address.call(abi.encodeWithSelector(0x23b872dd, data));
        require(success, 'BentoBox: contract init failed.');
        IMasterContract(clone_address).setBentoBox(address(this), masterContract);

        emit Created(masterContract, data, clone_address);
    }    

    // *** View functions *** //
    function toAmount(IERC20 token, uint256 share) public view returns (uint256) {
        uint256 _totalShare = totalShare[token];
        return _totalShare == 0 ? share : share.mul(totalBalance[token]) / _totalShare;
    }

    function toShare(IERC20 token, uint256 amount) public view returns (uint256) {
        uint256 _totalShare = totalShare[token];
        return _totalShare == 0 ? amount : amount.mul(_totalShare) / totalBalance[token];
    }

    // *** Public actions *** //
    function setMasterContractApproval(address masterContract, bool approved) public {
        require(masterContract != address(0), 'BentoBox: masterContract must be set'); // Important for security
        masterContractApproved[masterContract][msg.sender] = approved;
        emit MasterContractApprovalSet(masterContract, msg.sender, approved);
    }

    modifier allowed(address from) {
        require(msg.sender == from || masterContractApproved[getMasterContract[msg.sender]][from], 'BentoBox: Transfer not approved');
        _;
    }

    function deposit(IERC20 token, address from, uint256 amount) public returns (uint256) { return deposit(token, from, msg.sender, amount); }
    function deposit(IERC20 token, address from, address to, uint256 amount) public allowed(from) returns (uint256) {
        uint256 share = toShare(token, amount);
        _deposit(token, from, to, amount, share);
        return share;
    }

    function depositShare(IERC20 token, address from, uint256 share) public returns (uint256) { return depositShare(token, from, msg.sender, share); }
    function depositShare(IERC20 token, address from, address to, uint256 share) public allowed(from) returns (uint256) {
        uint256 amount = toAmount(token, share);
        _deposit(token, from, to, amount, share);
        return amount;
    }

    function depositWithPermit(IERC20 token, address from, uint256 amount, uint deadline, uint8 v, bytes32 r, bytes32 s) public returns (uint256) { return depositWithPermit(token, from, msg.sender, amount, deadline, v, r, s); }
    function depositWithPermit(IERC20 token, address from, address to, uint256 amount, uint deadline, uint8 v, bytes32 r, bytes32 s) public allowed(from) returns (uint256) {
        uint256 share = toShare(token, amount);
        _approveWithPermit(token, from, amount, deadline, v, r, s);
        _deposit(token, from, to, amount, share);
        return share;
    }

    function depositShareWithPermit(IERC20 token, address from, uint256 share, uint deadline, uint8 v, bytes32 r, bytes32 s) public returns (uint256) { return depositShareWithPermit(token, from, msg.sender, share, deadline, v, r, s); }
    function depositShareWithPermit(IERC20 token, address from, address to, uint256 share, uint deadline, uint8 v, bytes32 r, bytes32 s) public allowed(from) returns (uint256) {
        uint256 amount = toAmount(token, share);
        _approveWithPermit(token, from, amount, deadline, v, r, s);
        _deposit(token, from, to, amount, share);
        return amount;
    }

    function withdraw(IERC20 token, address to, uint256 amount) public returns (uint256) { return withdraw(token, msg.sender, to, amount); }
    function withdraw(IERC20 token, address from, address to, uint256 amount) public allowed(from) returns (uint256) {
        uint256 share = toShare(token, amount);
        _withdraw(token, from, to, amount, share);
        return share;        
    }

    function withdrawShare(IERC20 token, address to, uint256 share) public returns (uint256) { return withdrawShare(token, msg.sender, to, share); }
    function withdrawShare(IERC20 token, address from, address to, uint256 share) public allowed(from) returns (uint256) {
        uint256 amount = toAmount(token, share);
        _withdraw(token, from, to, amount, share);
        return amount;
    }

    // *** Approved contract actions *** //
    // Clones of master contracts can transfer from any account that has approved them
    function transfer(IERC20 token, address from, address to, uint256 amount) allowed(from) public returns (uint256) {
        require(to != address(0), 'BentoBox: to not set'); // To avoid a bad UI from burning funds
        uint256 share = toShare(token, amount);
        shareOf[token][from] = shareOf[token][from].sub(share);
        shareOf[token][to] = shareOf[token][to].add(share);
        return share;
    }

    function transferMultiple(IERC20 token, address from, address[] calldata tos, uint256[] calldata amounts) allowed(from) public returns (uint256) {
        require(tos[0] != address(0), 'BentoBox: to[0] not set'); // To avoid a bad UI from burning funds
        uint256 totalShares;
        for (uint256 i=0; i < tos.length; i++) {
            address to = tos[i];
            uint256 share = toShare(token, amounts[i]);
            shareOf[token][to] = shareOf[token][to].add(share);
            totalShares = totalShares.add(share);
        }
        shareOf[token][from] = shareOf[token][from].sub(totalShares);
        return totalShares;
    }

    function transferShare(IERC20 token, address from, address to, uint256 share) allowed(from) public {
        require(to != address(0), 'BentoBox: to not set'); // To avoid a bad UI from burning funds
        shareOf[token][from] = shareOf[token][from].sub(share);
        shareOf[token][to] = shareOf[token][to].add(share);
    }

    function transferMultipleShare(IERC20 token, address from, address[] calldata tos, uint256[] calldata shares) allowed(from) public {
        require(tos[0] != address(0), 'BentoBox: to[0] not set'); // To avoid a bad UI from burning funds
        uint256 totalShares;
        for (uint256 i=0; i < tos.length; i++) {
            address to = tos[i];
            uint256 share = shares[i];
            shareOf[token][to] = shareOf[token][to].add(share);
            totalShares = totalShares.add(share);
        }
        shareOf[token][from] = shareOf[token][from].sub(totalShares);
    }

    function skim(IERC20 token) public returns (uint256) { return skim(token, msg.sender); }
    function skim(IERC20 token, address to) public returns (uint256) {
        uint256 amount = token.balanceOf(address(this)).sub(totalBalance[token]);
        uint256 share = totalShare[token] == 0 ? amount : amount.mul(totalShare[token]) / totalBalance[token];
        shareOf[token][to] = shareOf[token][to].add(share);
        return share;
    }

    function skimETH() public returns (uint256) { return skimETH(msg.sender); }
    function skimETH(address to) public returns (uint256) {
        IWETH(address(WETH)).deposit{value: address(this).balance}();
        return skim(WETH, to);
    }

    bool private entryAllowed = true;
    modifier checkEntry() {
        require(entryAllowed, 'BentoBox: Cannot call sync from flashloan');
        entryAllowed = false;
        _;
        entryAllowed = true;
    }

    function sync(IERC20 token) public checkEntry {
        totalBalance[token] = token.balanceOf(address(this));
    }

    // Take out a flash loan
    function flashLoan(IERC20 token, uint256 amount, address user, bytes calldata params) public checkEntry {
        uint256 fee = amount.mul(5) / 10000;
        uint256 total = amount.add(fee);

        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(0xa9059cbb, user, amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "BentoBox: Transfer failed at ERC20");
        IFlashLoaner(user).executeOperation(token, amount, fee, params);
        (success, data) = address(token).call(abi.encodeWithSelector(0x23b872dd, user, address(this), total));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "BentoBox: TransferFrom failed at ERC20");

        emit FlashLoaned(user, token, amount, fee);
    }

    function flashLoanMultiple(IERC20[] calldata tokens, uint256[] calldata amounts, address user, bytes calldata params) public checkEntry {
        uint256[] memory fees = new uint256[](tokens.length);
        uint256[] memory totals = new uint256[](tokens.length);

        for (uint i = 0; i < tokens.length; i++) {
            uint256 amount = amounts[i];
            fees[i] = amount.mul(5) / 10000;
            totals[i] = amount.add(fees[i]);

            (bool success, bytes memory data) = address(tokens[i]).call(abi.encodeWithSelector(0xa9059cbb, user, amount));
            require(success && (data.length == 0 || abi.decode(data, (bool))), "BentoBox: Transfer failed at ERC20");
        }

        IFlashLoaner(user).executeOperationMultiple(tokens, amounts, fees, params);

        for (uint i = 0; i < tokens.length; i++) {
            (bool success, bytes memory data) = address(tokens[i]).call(abi.encodeWithSelector(0x23b872dd, user, address(this), totals[i]));
            require(success && (data.length == 0 || abi.decode(data, (bool))), "BentoBox: TransferFrom failed at ERC20");

            emit FlashLoaned(user, tokens[i], amounts[i], fees[i]);
        }
    }    

    function batch(bytes[] calldata calls, bool revertOnFail) public payable returns(bool[] memory, bytes[] memory) {
        bool[] memory successes = new bool[](calls.length);
        bytes[] memory results = new bytes[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(calls[i]);
            require(success || !revertOnFail, 'BentoBox: Transaction failed');
            successes[i] = success;
            results[i] = result;
        }
        return (successes, results);
    }

    // *** Internal functions *** //
    function _approveWithPermit(IERC20 token, address from, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) internal {
        token.permit(from, address(this), amount, deadline, v, r, s);
    }
    
    function _deposit(IERC20 token, address from, address to, uint256 amount, uint256 share) internal {
        require(to != address(0), 'BentoBox: to not set'); // To avoid a bad UI from burning funds
        shareOf[token][to] = shareOf[token][to].add(share);
        totalShare[token] = totalShare[token].add(share);
        totalBalance[token] = totalBalance[token].add(amount);

        if (address(token) == address(WETH)) {
            IWETH(address(WETH)).deposit{value: amount}();
        } else {
            (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(0x23b872dd, from, address(this), amount));
            require(success && (data.length == 0 || abi.decode(data, (bool))), "BentoBox: TransferFrom failed at ERC20");
        }
    }

    function _withdraw(IERC20 token, address from, address to, uint256 amount, uint256 share) internal {
        require(to != address(0), 'BentoBox: to not set'); // To avoid a bad UI from burning funds
        shareOf[token][from] = shareOf[token][from].sub(share);
        totalShare[token] = totalShare[token].sub(share);
        totalBalance[token] = totalBalance[token].sub(amount);
        if (address(token) == address(WETH)) {
            IWETH(address(WETH)).withdraw(amount);
            (bool success,) = to.call{value: amount}(new bytes(0));
            require(success, "BentoBox: ETH transfer failed");
        } else {
            (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(0xa9059cbb, to, amount));
            require(success && (data.length == 0 || abi.decode(data, (bool))), "BentoBox: Transfer failed at ERC20");
        }
    }
}
