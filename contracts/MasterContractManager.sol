// SPDX-License-Identifier: UNLICENSED
// Audit on 5-Jan-2021 by Keno and BoringCrypto
pragma solidity 0.6.12;
import "@boringcrypto/boring-solidity/contracts/BoringOwnable.sol";
import "@boringcrypto/boring-solidity/contracts/BoringFactory.sol";

// solhint-disable no-inline-assembly

contract MasterContractManager is BoringOwnable, BoringFactory {
    event LogWhiteListMasterContract(address indexed masterContract, bool approved);
    event LogSetMasterContractApproval(address indexed masterContract, address indexed user, bool approved);
    event LogRegisterProtocol(address indexed protocol);

    // masterContract to user to approval state
    mapping(address => mapping(address => bool)) public masterContractApproved;
    // masterContract to whitelisted state for approval without signed message
    mapping(address => bool) public whitelistedMasterContracts;
    // user nonces for masterContract approvals
    mapping(address => uint256) public nonces;

    bytes32 private constant DOMAIN_SEPARATOR_SIGNATURE_HASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");
    // See https://eips.ethereum.org/EIPS/eip-191
    string private constant EIP191_PREFIX_FOR_EIP712_STRUCTURED_DATA = "\x19\x01";
    bytes32 private constant APPROVAL_SIGNATURE_HASH =
        keccak256("SetMasterContractApproval(string warning,address user,address masterContract,bool approved,uint256 nonce)");
    
    // solhint-disable-next-line var-name-mixedcase
    bytes32 private immutable DOMAIN_SEPARATOR;

    constructor() public {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        DOMAIN_SEPARATOR = keccak256(abi.encode(DOMAIN_SEPARATOR_SIGNATURE_HASH, "BentoBox V2", chainId, address(this)));
    }

    function registerProtocol() public {
        masterContractOf[msg.sender] = msg.sender;
        emit LogRegisterProtocol(msg.sender);
    }

    function whitelistMasterContract(address masterContract, bool approved) public onlyOwner {
        // Checks
        require(masterContract != address(0), "MasterCMgr: Cannot approve 0");

        // Effects
        whitelistedMasterContracts[masterContract] = approved;
        emit LogWhiteListMasterContract(masterContract, approved);
    }

    // F4 - Check behaviour for all function arguments when wrong or extreme
    // F4: Don't allow masterContract 0 to be approved. Unknown contracts will have a masterContract of 0.
    // F4: User can't be 0 for signed approvals because the recoveredAddress will be 0 if ecrecover fails
    function setMasterContractApproval(
        address user,
        address masterContract,
        bool approved,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        // Checks
        require(masterContract != address(0), "MasterCMgr: masterC not set"); // Important for security

        // If no signature is provided, the fallback is executed
        if (r == 0 && s == 0 && v == 0) {
            require(user == msg.sender, "MasterCMgr: user not sender");
            require(masterContractOf[user] == address(0), "MasterCMgr: user is clone");
            require(whitelistedMasterContracts[masterContract], "MasterCMgr: not whitelisted");
        } else {
            // Important for security - any address without masterContract has address(0) as masterContract
            // So approving address(0) would approve every address, leading to full loss of funds
            // Also, ecrecover returns address(0) on failure. So we check this:
            require(user != address(0), "MasterCMgr: User cannot be 0");

            // C10 - Protect signatures against replay, use nonce and chainId (SWC-121)
            // C10: nonce + chainId are used to prevent replays
            // C11 - All signatures strictly EIP-712 (SWC-117 SWC-122)
            // C11: signature is EIP-712 compliant
            // C12 - abi.encodePacked can't contain variable length user input (SWC-133)
            // C12: abi.encodePacked has fixed length parameters
            bytes32 digest =
                keccak256(
                    abi.encodePacked(
                        EIP191_PREFIX_FOR_EIP712_STRUCTURED_DATA,
                        DOMAIN_SEPARATOR,
                        keccak256(
                            abi.encode(
                                APPROVAL_SIGNATURE_HASH,
                                approved ? "Give FULL access to funds in (and approved to) BentoBox?" : "Revoke access to BentoBox?",
                                user,
                                masterContract,
                                approved,
                                nonces[user]++
                            )
                        )
                    )
                );
            address recoveredAddress = ecrecover(digest, v, r, s);
            require(recoveredAddress == user, "MasterCMgr: Invalid Signature");
        }

        // Effects
        masterContractApproved[masterContract][user] = approved;
        emit LogSetMasterContractApproval(masterContract, user, approved);
    }
}
