// SPDX-License-Identifier: UNLICENSED
// solhint-disable no-inline-assembly

pragma solidity 0.6.12;
import "./Ownable.sol";

contract MasterContractManager is Ownable {
    event LogWhiteListMasterContract(address indexed masterContract, bool approved);
    event LogSetMasterContractApproval(address indexed masterContract, address indexed user, bool approved);

    mapping(address => mapping(address => bool)) public masterContractApproved; // masterContract to user to approval state
    mapping(address => bool) public whitelistedMasterContracts;
    mapping(address => uint256) public nonces;

    function domainSeparator() private view returns (bytes32) {
        uint256 chainId;
        assembly {chainId := chainid()}
        return keccak256(abi.encode(
            keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)"), 
            "BentoBox V2",
            chainId, 
            address(this)
        ));
    }

    function whitelistMasterContract(address masterContract, bool approved) public onlyOwner {
        whitelistedMasterContracts[masterContract] = approved;
        emit LogWhiteListMasterContract(masterContract, approved);
    }

    function setMasterContractApproval(address user, address masterContract, bool approved, uint8 v, bytes32 r, bytes32 s) public {
        require(masterContract != address(0), "MasterCMgr: masterC not set"); // Important for security

        if (r == 0) {
            require(user == msg.sender, "MasterCMgr: user not sender");
            require(whitelistedMasterContracts[masterContract], "MasterCMgr: not whitelisted");
        } else {
            require(user != address(0), "MasterCMgr: User cannot be 0"); // Important for security

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
            require(recoveredAddress == user, "MasterCMgr: Invalid Signature");
        }

        masterContractApproved[masterContract][user] = approved;
        emit LogSetMasterContractApproval(masterContract, user, approved);
    }
}