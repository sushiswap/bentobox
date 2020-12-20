// SPDX-License-Identifier: UNLICENSED

// The BentoBox

//  ▄▄▄▄· ▄▄▄ . ▐ ▄ ▄▄▄▄▄      ▄▄▄▄·       ▐▄• ▄ 
//  ▐█ ▀█▪▀▄.▀·•█▌▐█•██  ▪     ▐█ ▀█▪▪      █▌█▌▪
//  ▐█▀▀█▄▐▀▀▪▄▐█▐▐▌ ▐█.▪ ▄█▀▄ ▐█▀▀█▄ ▄█▀▄  ·██· 
//  ██▄▪▐█▐█▄▄▌██▐█▌ ▐█▌·▐█▌.▐▌██▄▪▐█▐█▌.▐▌▪▐█·█▌
//  ·▀▀▀▀  ▀▀▀ ▀▀ █▪ ▀▀▀  ▀█▄▀▪·▀▀▀▀  ▀█▄▀▪•▀▀ ▀▀

// This contract stores funds, handles their transfers.

// Copyright (c) 2020 BoringCrypto - All rights reserved
// Twitter: @Boring_Crypto

// WARNING!!! DO NOT USE!!! BEING AUDITED!!!

// solhint-disable no-inline-assembly
// solhint-disable avoid-low-level-calls
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;
import "./libraries/BoringMath.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IMasterContract.sol";

contract BentoBox {
    using BoringMath for uint256;
    using BoringMath128 for uint128;

    event LogDeploy(address indexed masterContract, bytes data, address indexed cloneAddress);
    event LogSetMasterContractApproval(address indexed masterContract, address indexed user, bool indexed approved);
    event LogDeposit(IERC20 indexed token, address indexed from, address indexed to, uint256 amount);
    event LogWithdraw(IERC20 indexed token, address indexed from, address indexed to, uint256 amount);
    event LogTransfer(IERC20 indexed token, address indexed from, address indexed to, uint256 amount);

    mapping(address => address) public masterContractOf; // Mapping from clone contracts to their masterContract
    mapping(address => mapping(address => bool)) public masterContractApproved; // masterContract to user to approval state
    mapping(IERC20 => mapping(address => uint256)) public balanceOf; // Balance per token per address/contract
    mapping(IERC20 => uint256) public totalSupply;
    // solhint-disable-next-line var-name-mixedcase
    IERC20 public immutable WETH;

    mapping(address => uint256) public nonces;

    // solhint-disable-next-line var-name-mixedcase
    constructor(IERC20 WETH_) public {
        WETH = WETH_;
    }

    // Deploys a given master Contract as a clone.
    function deploy(address masterContract, bytes calldata data) external {
        bytes20 targetBytes = bytes20(masterContract); // Takes the first 20 bytes of the masterContract's address
        address cloneAddress; // Address where the clone contract will reside.

        // Creates clone, more info here: https://blog.openzeppelin.com/deep-dive-into-the-minimal-proxy-contract/
        assembly {
            let clone := mload(0x40)
            mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(clone, 0x14), targetBytes)
            mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            cloneAddress := create(0, clone, 0x37)
        }
        masterContractOf[cloneAddress] = masterContract;

        IMasterContract(cloneAddress).init(data);

        emit LogDeploy(masterContract, data, cloneAddress);
    }

    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        uint256 chainId;
        assembly {chainId := chainid()}
        return keccak256(abi.encode(keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)"), "BentoBox V1", chainId, address(this)));
    }

    // *** Public actions *** //
    function setMasterContractApproval(address user, address masterContract, bool approved, uint8 v, bytes32 r, bytes32 s) external {
        require(user != address(0), "BentoBox: User cannot be 0");
        require(masterContract != address(0), "BentoBox: masterContract not set"); // Important for security

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01", DOMAIN_SEPARATOR(),
            keccak256(abi.encode(
                // keccak256("SetMasterContractApproval(string warning,address user,address masterContract,bool approved,uint256 nonce)");
                0x1962bc9f5484cb7a998701b81090e966ee1fce5771af884cceee7c081b14ade2,
                approved ? "Give FULL access to funds in (and approved to) BentoBox?" : "Revoke access to BentoBox?",
                user, masterContract, approved, nonces[user]++
            ))
        ));
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress == user, "BentoBox: Invalid Signature");

        masterContractApproved[masterContract][user] = approved;
        emit LogSetMasterContractApproval(masterContract, user, approved);
    }

    modifier allowed(address from) {
        require(msg.sender == from || masterContractApproved[masterContractOf[msg.sender]][from], "BentoBox: Transfer not approved");
        _;
    }

    function permit(IERC20 token, address from, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
        token.permit(from, address(this), amount, deadline, v, r, s);
    }

    function deposit(IERC20 token, address from, uint256 amount) external payable { depositTo(token, from, msg.sender, amount); }
    function depositTo(IERC20 token, address from, address to, uint256 amount) public payable allowed(from) {
        _deposit(token, from, to, amount);
    }

    function withdraw(IERC20 token, address to, uint256 amount) external { withdrawFrom(token, msg.sender, to, amount); }
    function withdrawFrom(IERC20 token, address from, address to, uint256 amount) public allowed(from) {
        _withdraw(token, from, to, amount);
    }

    // *** Approved contract actions *** //
    // Clones of master contracts can transfer from any account that has approved them
    function transfer(IERC20 token, address to, uint256 amount) external { transferFrom(token, msg.sender, to, amount); }
    function transferFrom(IERC20 token, address from, address to, uint256 amount) public allowed(from) {
        require(to != address(0), "BentoBox: to not set"); // To avoid a bad UI from burning funds
        balanceOf[token][from] = balanceOf[token][from].sub(amount);
        balanceOf[token][to] = balanceOf[token][to].add(amount);

        emit LogTransfer(token, from, to, amount);
    }

    function transferMultiple(IERC20 token, address[] calldata tos, uint256[] calldata amounts) external
    {
        transferMultipleFrom(token, msg.sender, tos, amounts);
    }
    function transferMultipleFrom(IERC20 token, address from, address[] calldata tos, uint256[] calldata amounts) public allowed(from) {
        require(tos[0] != address(0), "BentoBox: to[0] not set"); // To avoid a bad UI from burning funds
        uint256 totalAmount;
        for (uint256 i=0; i < tos.length; i++) {
            address to = tos[i];
            balanceOf[token][to] = balanceOf[token][to].add(amounts[i]);
            totalAmount = totalAmount.add(amounts[i]);
            emit LogTransfer(token, from, to, amounts[i]);
        }
        balanceOf[token][from] = balanceOf[token][from].sub(totalAmount);
    }

    function skim(IERC20 token) external returns (uint256 amount) { amount = skimTo(token, msg.sender); }
    function skimTo(IERC20 token, address to) public returns (uint256 amount) {
        require(to != address(0), "BentoBox: to not set"); // To avoid a bad UI from burning funds
        amount = token.balanceOf(address(this)).sub(totalSupply[token]);
        balanceOf[token][to] = balanceOf[token][to].add(amount);
        totalSupply[token] = totalSupply[token].add(amount);
        emit LogDeposit(token, address(this), to, amount);
    }

    function skimETH() external returns (uint256 amount) { amount = skimETHTo(msg.sender); }
    function skimETHTo(address to) public returns (uint256 amount) {
        IWETH(address(WETH)).deposit{value: address(this).balance}();
        amount = skimTo(WETH, to);
    }

    function batch(bytes[] calldata calls, bool revertOnFail) external payable returns(bool[] memory successes, bytes[] memory results) {
        successes = new bool[](calls.length);
        results = new bytes[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(calls[i]);
            require(success || !revertOnFail, "BentoBox: Transaction failed");
            successes[i] = success;
            results[i] = result;
        }
    }

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}

    // *** Private functions *** //
    function _deposit(IERC20 token, address from, address to, uint256 amount) private {
        require(to != address(0), "BentoBox: to not set"); // To avoid a bad UI from burning funds
        balanceOf[token][to] = balanceOf[token][to].add(amount);
        uint256 supply = totalSupply[token];
        totalSupply[token] = supply.add(amount);

        if (address(token) == address(WETH)) {
            IWETH(address(WETH)).deposit{value: amount}();
        } else {
            if (supply == 0) { // During the first deposit, we check that this token is 'real'
                require(token.totalSupply() > 0, "BentoBox: No tokens");
            }
            (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(0x23b872dd, from, address(this), amount));
            require(success && (data.length == 0 || abi.decode(data, (bool))), "BentoBox: TransferFrom failed");
        }
        emit LogDeposit(token, from, to, amount);
    }

    function _withdraw(IERC20 token, address from, address to, uint256 amount) private {
        require(to != address(0), "BentoBox: to not set"); // To avoid a bad UI from burning funds
        balanceOf[token][from] = balanceOf[token][from].sub(amount);
        totalSupply[token] = totalSupply[token].sub(amount);
        if (address(token) == address(WETH)) {
            IWETH(address(WETH)).withdraw(amount);
            (bool success,) = to.call{value: amount}(new bytes(0));
            require(success, "BentoBox: ETH transfer failed");
        } else {
            (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(0xa9059cbb, to, amount));
            require(success && (data.length == 0 || abi.decode(data, (bool))), "BentoBox: Transfer failed");
        }
        emit LogWithdraw(token, from, to, amount);
    }
}
