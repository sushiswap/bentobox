// SPDX-License-Identifier: UNLICENSED

// The BentoBox

//  ▄▄▄▄· ▄▄▄ . ▐ ▄ ▄▄▄▄▄      ▄▄▄▄·       ▐▄• ▄ 
//  ▐█ ▀█▪▀▄.▀·•█▌▐█•██  ▪     ▐█ ▀█▪▪      █▌█▌▪
//  ▐█▀▀█▄▐▀▀▪▄▐█▐▐▌ ▐█.▪ ▄█▀▄ ▐█▀▀█▄ ▄█▀▄  ·██· 
//  ██▄▪▐█▐█▄▄▌██▐█▌ ▐█▌·▐█▌.▐▌██▄▪▐█▐█▌.▐▌▪▐█·█▌
//  ·▀▀▀▀  ▀▀▀ ▀▀ █▪ ▀▀▀  ▀█▄▀▪·▀▀▀▀  ▀█▄▀▪•▀▀ ▀▀

// This contract stores funds, handles their transfers. Also takes care of flash loans and rebasing tokens.

// Copyright (c) 2020 BoringCrypto - All rights reserved
// Twitter: @Boring_Crypto

// solium-disable security/no-inline-assembly
// solium-disable security/no-low-level-calls
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;
import "./libraries/BoringMath.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IMasterContract.sol";
import "./interfaces/IFlashLoaner.sol";

contract BentoBox {
    using BoringMath for uint256;

    event LogDeploy(address indexed masterContract, bytes data, address indexed clone_address);
    event LogFlashLoan(address indexed user, IERC20 indexed token, uint256 amount, uint256 feeAmount);
    event LogSetMasterContractApproval(address indexed masterContract, address indexed user, bool indexed approved);
    event LogDeposit(IERC20 indexed token, address indexed from, address indexed to, uint256 amount, uint256 share);
    event LogWithdraw(IERC20 indexed token, address indexed from, address indexed to, uint256 amount, uint256 share);
    event LogTransfer(IERC20 indexed token, address indexed from, address indexed to, uint256 amount, uint256 share);

    mapping(address => address) public masterContractOf; // Mapping from clone contracts to their masterContract
    mapping(address => mapping(address => bool)) public masterContractApproved; // Mapping from masterContract to user to approval state
    mapping(IERC20 => mapping(address => uint256)) public shareOf; // Balance per token per address/contract
    mapping(IERC20 => uint256) public totalShare; // Total share per token
    mapping(IERC20 => uint256) public totalAmount; // Total balance per token
    IERC20 public WETH; // TODO: Hardcode WETH on final deploy and remove constructor
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
        masterContractOf[clone_address] = masterContract;

        // TODO: Roll init call and setBentoBox call into one and fix signature to init
        (bool success,) = clone_address.call(data);
        require(success, 'BentoBox: contract init failed.');
        IMasterContract(clone_address).setBentoBox(address(this), masterContract);

        emit LogDeploy(masterContract, data, clone_address);
    }

    // *** View functions *** //
    function toAmount(IERC20 token, uint256 share) public view returns (uint256 amount) {
        uint256 _totalShare = totalShare[token];
        amount = _totalShare == 0 ? share : share.mul(totalAmount[token]) / _totalShare;
    }


    function toShare(IERC20 token, uint256 amount) public view returns (uint256 share) {
        uint256 _totalShare = totalShare[token];
        share = _totalShare == 0 ? amount : amount.mul(_totalShare) / totalAmount[token];
    }

    // *** Public actions *** //
    function setMasterContractApproval(address masterContract, bool approved) public {
        require(masterContract != address(0), 'BentoBox: masterContract must be set'); // Important for security
        masterContractApproved[masterContract][msg.sender] = approved;
        emit LogSetMasterContractApproval(masterContract, msg.sender, approved);
    }

    modifier allowed(address from) {
        require(msg.sender == from || masterContractApproved[masterContractOf[msg.sender]][from], 'BentoBox: Transfer not approved');
        _;
    }

    function deposit(IERC20 token, address from, uint256 amount) public payable returns (uint256 share) { share = depositTo(token, from, msg.sender, amount); }
    function depositTo(IERC20 token, address from, address to, uint256 amount) public payable allowed(from) returns (uint256 share) {
        share = toShare(token, amount);
        _deposit(token, from, to, amount, share);
    }

    function depositShare(IERC20 token, address from, uint256 share) public payable returns (uint256 amount) { amount = depositShareTo(token, from, msg.sender, share); }
    function depositShareTo(IERC20 token, address from, address to, uint256 share) public payable allowed(from) returns (uint256 amount) {
        amount = toAmount(token, share);
        _deposit(token, from, to, amount, share);
    }

    function depositWithPermit(IERC20 token, address from, uint256 amount, uint deadline, uint8 v, bytes32 r, bytes32 s) public payable returns (uint256 share) { share = depositWithPermitTo(token, from, msg.sender, amount, deadline, v, r, s); }
    function depositWithPermitTo(IERC20 token, address from, address to, uint256 amount, uint deadline, uint8 v, bytes32 r, bytes32 s) public payable allowed(from) returns (uint256 share) {
        share = toShare(token, amount);
        _approveWithPermit(token, from, amount, deadline, v, r, s);
        _deposit(token, from, to, amount, share);
    }

    function depositShareWithPermit(IERC20 token, address from, uint256 share, uint deadline, uint8 v, bytes32 r, bytes32 s) public payable returns (uint256 amount) { amount = depositShareWithPermitTo(token, from, msg.sender, share, deadline, v, r, s); }
    function depositShareWithPermitTo(IERC20 token, address from, address to, uint256 share, uint deadline, uint8 v, bytes32 r, bytes32 s) public payable allowed(from) returns (uint256 amount) {
        amount = toAmount(token, share);
        _approveWithPermit(token, from, amount, deadline, v, r, s);
        _deposit(token, from, to, amount, share);
    }

    function withdraw(IERC20 token, address to, uint256 amount) public returns (uint256 share) { share = withdrawFrom(token, msg.sender, to, amount); }
    function withdrawFrom(IERC20 token, address from, address to, uint256 amount) public allowed(from) returns (uint256 share) {
        share = toShare(token, amount);
        _withdraw(token, from, to, amount, share);
    }

    function withdrawShare(IERC20 token, address to, uint256 share) public returns (uint256 amount) { amount = withdrawShareFrom(token, msg.sender, to, share); }
    function withdrawShareFrom(IERC20 token, address from, address to, uint256 share) public allowed(from) returns (uint256 amount) {
        amount = toAmount(token, share);
        _withdraw(token, from, to, amount, share);
    }

    // *** Approved contract actions *** //
    // Clones of master contracts can transfer from any account that has approved them
    function transfer(IERC20 token, address to, uint256 amount) public returns (uint256 share) { share = transferFrom(token, msg.sender, to, amount); }
    function transferFrom(IERC20 token, address from, address to, uint256 amount) allowed(from) public returns (uint256 share) {
        require(to != address(0), 'BentoBox: to not set'); // To avoid a bad UI from burning funds
        share = toShare(token, amount);
        shareOf[token][from] = shareOf[token][from].sub(share);
        shareOf[token][to] = shareOf[token][to].add(share);

        emit LogTransfer(token, from, to, amount, share);
    }

    function transferMultiple(IERC20 token, address[] calldata tos, uint256[] calldata amounts) public returns (uint256 sumShares) { sumShares = transferMultipleFrom(token, msg.sender, tos, amounts); }
    function transferMultipleFrom(IERC20 token, address from, address[] calldata tos, uint256[] calldata amounts) allowed(from) public returns (uint256 sumShares) {
        require(tos[0] != address(0), 'BentoBox: to[0] not set'); // To avoid a bad UI from burning funds
        for (uint256 i=0; i < tos.length; i++) {
            address to = tos[i];
            uint256 share = toShare(token, amounts[i]);
            shareOf[token][to] = shareOf[token][to].add(share);
            sumShares = sumShares.add(share);
            emit LogTransfer(token, from, to, amounts[i], share);
        }
        shareOf[token][from] = shareOf[token][from].sub(sumShares);
    }

    function transferShare(IERC20 token, address to, uint256 share) public returns (uint256 amount) { amount = transferShareFrom(token, msg.sender, to, share); }
    function transferShareFrom(IERC20 token, address from, address to, uint256 share) allowed(from) public returns (uint256 amount) {
        require(to != address(0), 'BentoBox: to not set'); // To avoid a bad UI from burning funds
        amount = toAmount(token, share);
        shareOf[token][from] = shareOf[token][from].sub(share);
        shareOf[token][to] = shareOf[token][to].add(share);
        emit LogTransfer(token, from, to, amount, share);
    }

    function transferMultipleShare(IERC20 token, address[] calldata tos, uint256[] calldata shares) public returns (uint256 sumAmounts) { sumAmounts = transferMultipleShareFrom(token, msg.sender, tos, shares); }
    function transferMultipleShareFrom(IERC20 token, address from, address[] calldata tos, uint256[] calldata shares) allowed(from) public returns (uint256 sumAmounts) {
        require(tos[0] != address(0), 'BentoBox: to[0] not set'); // To avoid a bad UI from burning funds
        uint256 totalShares;
        for (uint256 i=0; i < tos.length; i++) {
            uint256 amount = toAmount(token, shares[i]);
            sumAmounts = sumAmounts.add(amount);
            totalShares = totalShares.add(shares[i]);
            shareOf[token][tos[i]] = shareOf[token][tos[i]].add(shares[i]);
            emit LogTransfer(token, from, tos[i], amount, shares[i]);
        }
        shareOf[token][from] = shareOf[token][from].sub(totalShares);
    }

    function skim(IERC20 token) public returns (uint256 share) { share = skimTo(token, msg.sender); }
    function skimTo(IERC20 token, address to) public returns (uint256 share) {
        require(to != address(0), 'BentoBox: to not set'); // To avoid a bad UI from burning funds
        uint256 amount = token.balanceOf(address(this)).sub(totalAmount[token]);
        share = toShare(token, amount);
        shareOf[token][to] = shareOf[token][to].add(share);
        totalShare[token] = totalShare[token].add(share);
        totalAmount[token] = totalAmount[token].add(amount);
        emit LogDeposit(token, address(this), to, amount, share);
    }

    function skimETH() public returns (uint256 share) { share = skimETHTo(msg.sender); }
    function skimETHTo(address to) public returns (uint256 share) {
        IWETH(address(WETH)).deposit{value: address(this).balance}();
        share = skimTo(WETH, to);
    }

    bool private entryAllowed = true;
    modifier checkEntry() {
        require(entryAllowed, 'BentoBox: Cannot call sync from flashloan');
        entryAllowed = false;
        _;
        entryAllowed = true;
    }

    function sync(IERC20 token) public checkEntry {
        totalAmount[token] = token.balanceOf(address(this));
    }

    // Take out a flash loan
    function flashLoan(IERC20 token, uint256 amount, address user, bytes calldata params) public checkEntry {
        uint256 feeAmount = amount.mul(5) / 10000;
        uint256 returnAmount = amount.add(feeAmount);

        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(0xa9059cbb, user, amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "BentoBox: Transfer failed at ERC20");
        IFlashLoaner(user).executeOperation(token, amount, feeAmount, params);
        (success, data) = address(token).call(abi.encodeWithSelector(0x23b872dd, user, address(this), returnAmount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "BentoBox: TransferFrom failed at ERC20");
        totalAmount[token] = totalAmount[token] + feeAmount;

        emit LogFlashLoan(user, token, amount, feeAmount);
    }

    function flashLoanMultiple(IERC20[] calldata tokens, uint256[] calldata amounts, address user, bytes calldata params) public checkEntry {
        uint256[] memory feeAmounts = new uint256[](tokens.length);
        uint256[] memory returnAmounts = new uint256[](tokens.length);

        for (uint i = 0; i < tokens.length; i++) {
            uint256 amount = amounts[i];
            feeAmounts[i] = amount.mul(5) / 10000;
            returnAmounts[i] = amount.add(feeAmounts[i]);

            (bool success, bytes memory data) = address(tokens[i]).call(abi.encodeWithSelector(0xa9059cbb, user, amount));
            require(success && (data.length == 0 || abi.decode(data, (bool))), "BentoBox: Transfer failed at ERC20");
        }

        IFlashLoaner(user).executeOperationMultiple(tokens, amounts, feeAmounts, params);

        for (uint i = 0; i < tokens.length; i++) {
            (bool success, bytes memory data) = address(tokens[i]).call(abi.encodeWithSelector(0x23b872dd, user, address(this), returnAmounts[i]));
            require(success && (data.length == 0 || abi.decode(data, (bool))), "BentoBox: TransferFrom failed at ERC20");
            totalAmount[tokens[i]] = totalAmount[tokens[i]] + feeAmounts[i];

            emit LogFlashLoan(user, tokens[i], amounts[i], feeAmounts[i]);
        }
    }

    function batch(bytes[] calldata calls, bool revertOnFail) public payable returns(bool[] memory successes, bytes[] memory results) {
        successes = new bool[](calls.length);
        results = new bytes[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(calls[i]);
            require(success || !revertOnFail, 'BentoBox: Transaction failed');
            successes[i] = success;
            results[i] = result;
        }
    }

    // *** Internal functions *** //
    function _approveWithPermit(IERC20 token, address from, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) internal {
        token.permit(from, address(this), amount, deadline, v, r, s);
    }

    function _deposit(IERC20 token, address from, address to, uint256 amount, uint256 share) internal {
        require(to != address(0), 'BentoBox: to not set'); // To avoid a bad UI from burning funds
        shareOf[token][to] = shareOf[token][to].add(share);
        totalShare[token] = totalShare[token].add(share);
        totalAmount[token] = totalAmount[token].add(amount);

        if (address(token) == address(WETH)) {
            IWETH(address(WETH)).deposit{value: amount}();
        } else {
            (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(0x23b872dd, from, address(this), amount));
            require(success && (data.length == 0 || abi.decode(data, (bool))), "BentoBox: TransferFrom failed at ERC20");
        }
        emit LogDeposit(token, from, to, amount, share);
    }

    function _withdraw(IERC20 token, address from, address to, uint256 amount, uint256 share) internal {
        require(to != address(0), 'BentoBox: to not set'); // To avoid a bad UI from burning funds
        shareOf[token][from] = shareOf[token][from].sub(share);
        totalShare[token] = totalShare[token].sub(share);
        totalAmount[token] = totalAmount[token].sub(amount);
        if (address(token) == address(WETH)) {
            IWETH(address(WETH)).withdraw(amount);
            (bool success,) = to.call{value: amount}(new bytes(0));
            require(success, "BentoBox: ETH transfer failed");
        } else {
            (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(0xa9059cbb, to, amount));
            require(success && (data.length == 0 || abi.decode(data, (bool))), "BentoBox: Transfer failed at ERC20");
        }
        emit LogWithdraw(token, from, to, amount, share);
    }
}
