pragma solidity ^0.6.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {

  bytes32 public DOMAIN_SEPARATOR;

  // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
  bytes32
    public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

  mapping(address => uint256) public nonces;

  constructor(
    string memory name,
    string memory symbol,
    uint256 supply
  ) ERC20(name, symbol) public {
    _mint(msg.sender, supply);
    uint256 chainId;
    assembly {
      chainId := chainid()
    }
    DOMAIN_SEPARATOR = keccak256(
      abi.encode(
        keccak256(
          "EIP712Domain(uint256 chainId,address verifyingContract)"
        ),
        chainId,
        address(this)
      )
    );
  }

  function burn(uint256 amount) public{
    _burn(msg.sender, amount);
  }

  function mint(address recipient, uint256 amount) public returns (bool) {
    _mint(recipient, amount);
  }

  function renounceMinter() public {
    // do nothing
  }

  function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {
    require(deadline >= block.timestamp, "mockERC20: EXPIRED");
    bytes memory msg = abi.encode(
      PERMIT_TYPEHASH,
      owner,
      spender,
      value,
      nonces[owner]++,
      deadline
    );
    bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, keccak256(msg)));
    address recoveredAddress = ecrecover(digest, v, r, s);
    require(recoveredAddress != address(0) && recoveredAddress == owner, "mockERC20: INVALID_SIGNATURE");
    _approve(owner, spender, value);
  }

}