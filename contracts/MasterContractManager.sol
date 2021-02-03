// SPDX-License-Identifier: UNLICENSED
// Audit on 5-Jan-2021 by Keno and BoringCrypto

// P1 - P3: OK
pragma solidity 0.6.12;
import "@boringcrypto/boring-solidity/contracts/BoringOwnable.sol";
import "@boringcrypto/boring-solidity/contracts/BoringFactory.sol";

// solhint-disable no-inline-assembly

// T1 - T4: OK
contract MasterContractManager is BoringOwnable, BoringFactory {
    // E1: OK
    event LogWhiteListMasterContract(address indexed masterContract, bool approved);
    // E1: OK
    event LogSetMasterContractApproval(address indexed masterContract, address indexed user, bool approved);

    // V1 - V5: OK
    mapping(address => mapping(address => bool)) public masterContractApproved; // masterContract to user to approval state
    // V1 - V5: OK
    mapping(address => bool) public whitelistedMasterContracts;
    // V1 - V5: OK
    mapping(address => uint256) public nonces;

    bytes32 private constant DOMAIN_SEPARATOR_SIGNATURE_HASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");
    // See https://eips.ethereum.org/EIPS/eip-191
    string private constant EIP191_PREFIX_FOR_EIP712_STRUCTURED_DATA = "\x19\x01";
    bytes32 private constant APPROVAL_SIGNATURE_HASH = 
        keccak256("SetMasterContractApproval(string warning,address user,address masterContract,bool approved,uint256 nonce)");
    
    // F1 - F8: OK
    // C1 - C19: OK
    // C20: Recalculating the domainSeparator is cheaper than reading it from storage
    function domainSeparator() private view returns (bytes32) {
        uint256 chainId;
        assembly {chainId := chainid()}
        return keccak256(abi.encode(
            DOMAIN_SEPARATOR_SIGNATURE_HASH, 
            "BentoBox V2",
            chainId, 
            address(this)
        ));
    }

    // F1 - F9: OK
    // F4: Approving masterContract 0 would be very bad, however it cannot be approved by the user and the owner should know better
    // C1 - C21: OK
    function whitelistMasterContract(address masterContract, bool approved) public onlyOwner {
        whitelistedMasterContracts[masterContract] = approved;
        emit LogWhiteListMasterContract(masterContract, approved);
    }

    // F1 - F9: OK
    // F4: Don't allow masterContract 0 to be approved. Unknown contracts will have a masterContract of 0.
    // F4: User can't be 0 for signed approvals because the recoveredAddress will be 0 if ecrecover fails
    // C1 - C21: OK
    function setMasterContractApproval(address user, address masterContract, bool approved, uint8 v, bytes32 r, bytes32 s) public {
        // Checks
        require(masterContract != address(0), "MasterCMgr: masterC not set"); // Important for security

        // If no signature is provided, the fallback is executed
        if (r == 0  && s == 0 && v == 0) {
            require(user == msg.sender, "MasterCMgr: user not sender");
            require(masterContractOf[user] == address(0), "MasterCMgr: user is clone");
            require(whitelistedMasterContracts[masterContract], "MasterCMgr: not whitelisted");
        } else {
            require(user != address(0), "MasterCMgr: User cannot be 0"); // Important for security
            // C10: nonce + chainId are used to prevent replays
            // C11: signature is EIP-712 compliant
            // C12: abi.encodePacked has fixed length parameters
            bytes32 digest = keccak256(abi.encodePacked(
                EIP191_PREFIX_FOR_EIP712_STRUCTURED_DATA,
                domainSeparator(),
                keccak256(abi.encode(
                    APPROVAL_SIGNATURE_HASH,
                    approved ? "Give FULL access to funds in (and approved to) BentoBox?" : "Revoke access to BentoBox?",
                    user, masterContract, approved, nonces[user]++
                ))
            ));
            address recoveredAddress = ecrecover(digest, v, r, s);
            require(recoveredAddress == user, "MasterCMgr: Invalid Signature");
        }

        // Effects
        masterContractApproved[masterContract][user] = approved;
        emit LogSetMasterContractApproval(masterContract, user, approved);
    }
}