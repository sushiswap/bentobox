// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

/// @notice Interface for BENTO deposit and withdraw.
interface IBentoBridge {
    function balanceOf(IERC20, address) external view returns (uint256);
    
    function registerProtocol() external;

    function deposit( 
        IERC20 token_,
        address from,
        address to,
        uint256 amount,
        uint256 share
    ) external payable returns (uint256 amountOut, uint256 shareOut);

    function withdraw(
        IERC20 token_,
        address from,
        address to,
        uint256 amount,
        uint256 share
    ) external returns (uint256 amountOut, uint256 shareOut);
}

/// @notice Interface to wrap NFT / includes Zora Protocol `permit()` format.
interface IERC721Wrap {
    struct EIP712Signature {
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }
    
    function transferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    
    /// @notice EIP 2612 adapted for ERC 721.
    function permit(
        address spender,
        uint256 tokenId,
        EIP712Signature calldata sig
    ) external;
}

interface IERC20 {} contract TamagoToken is IERC20 {
    string constant public name = "TAMAGO";
    string constant public symbol = "TAMA";
    uint8 constant public decimals = 18;
    
    uint256 immutable public totalSupply;
    
    event Transfer(address indexed from, address indexed to, uint256 amount);
    
    constructor(uint256 _totalSupply) public {
        totalSupply = _totalSupply;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        emit Transfer(from, to, amount);
        return true;
    }
}

/// @notice Gas-optimized contract to wrap NFT into BENTO. 
contract Tamago {
    IBentoBridge constant bento = IBentoBridge(0xF5BCE5077908a1b7370B9ae04AdC565EBd643966); // BENTO vault contract

    mapping(IERC20 => Tama) public tamas;
    
    struct Tama {
        IERC721Wrap nft;
        uint256 tokenId;
        uint256 ctrlSupply;
        uint256 totalSupply;
    }
    
    constructor() public {
        bento.registerProtocol();
    }
    
    function wrapNFT(IERC721Wrap nft, uint256 tokenId, uint256 ctrlSupply, uint256 totalSupply) external returns (IERC20 wrapper) {
        nft.transferFrom(msg.sender, address(this), tokenId);
        wrapper = new TamagoToken(totalSupply);
        tamas[wrapper] = Tama(nft, tokenId, ctrlSupply, totalSupply);
        bento.deposit(wrapper, address(this), msg.sender, 0, totalSupply);
    }
    
    function unwrapNFT(IERC20 wrapper) external {
        Tama storage tama = tamas[wrapper];
        require(bento.balanceOf(wrapper, msg.sender) >= tama.ctrlSupply, "!ctrlSupply");
        //bento.withdraw(wrapper, address(this), msg.sender, 0, tama.totalSupply);
        tama.nft.transferFrom(address(this), msg.sender, tama.tokenId);
    }
}
