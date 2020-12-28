// SPDX-License-Identifier: UNLICENSED
// solhint-disable no-inline-assembly

pragma solidity 0.6.12;
import "./Ownable.sol";

contract MasterContractManager is Ownable {
    event LogSetMasterContractApproval(address indexed masterContract, address indexed user, bool indexed approved);

    mapping(address => mapping(address => bool)) public masterContractApproved; // masterContract to user to approval state
    mapping(address => bool) public whitelistedMasterContracts;
    mapping(address => uint256) public nonces;

    // Visibility: public - Make private and move this to helper
    function domainSeparator() public view returns (bytes32) {
        uint256 chainId;
        assembly {chainId := chainid()}
        return keccak256(abi.encode(
            keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)"), 
            "BentoBox V2", 
            chainId, 
            address(this)
        ));
    }

    // *** Public actions *** //
    function whitelistMasterContract(address masterContract, bool approved) external onlyOwner{
        whitelistedMasterContracts[masterContract] = approved;
    }

    function setMasterContractApprovalFallback(address masterContract, bool approved) external {
        require(masterContract != address(0), "BentoBox: masterContract not set"); // Important for security
        require(whitelistedMasterContracts[masterContract], "BentoBox: not whitelisted");
        
        masterContractApproved[masterContract][msg.sender] = approved;
        
        emit LogSetMasterContractApproval(masterContract, msg.sender, approved);
    }

    function setMasterContractApproval(address user, address masterContract, bool approved, uint8 v, bytes32 r, bytes32 s) external {
        require(user != address(0), "BentoBox: User cannot be 0");
        require(masterContract != address(0), "BentoBox: masterContract not set"); // Important for security

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01", domainSeparator(),
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
}