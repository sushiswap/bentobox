// SPDX-License-Identifier: MIT
// TokenA does not revert on errors, it just returns false
pragma solidity 0.6.12;
contract TokenA {
    string public constant symbol = "A";
    string public constant name = "Token A";
    uint8 public constant decimals = 18;
    uint256 public totalSupply = 1e25;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping (address => uint256)) allowance;
    mapping(address => uint256) public nonces;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    constructor() public {
        balanceOf[msg.sender] = totalSupply;
    }

    function transfer(address to, uint256 amount) public returns (bool success) {
        if (balanceOf[msg.sender] >= amount && amount > 0 && balanceOf[to] + amount > balanceOf[to]) {
            balanceOf[msg.sender] -= amount;
            balanceOf[to] += amount;
            emit Transfer(msg.sender, to, amount);
            return true;
        } else {
            return false;
        }
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool success) {
        if (balanceOf[from] >= amount && allowance[from][msg.sender] >= amount && amount > 0 && balanceOf[to] + amount > balanceOf[to]) {
            balanceOf[from] -= amount;
            allowance[from][msg.sender] -= amount;
            balanceOf[to] += amount;
            emit Transfer(from, to, amount);
            return true;
        } else {
            return false;
        }
    }

    function approve(address spender, uint256 amount) public returns (bool success) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function DOMAIN_SEPARATOR() public view returns (bytes32){
      uint256 chainId;
      assembly {chainId := chainid()}
      return keccak256(abi.encode(keccak256("EIP712Domain(uint256 chainId,address verifyingContract)"), chainId, address(this)));
    }

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external {
        require(block.timestamp < deadline, 'BentoBox: Expired');
        bytes32 digest = keccak256(abi.encodePacked(
            '\x19\x01', DOMAIN_SEPARATOR(),
            keccak256(abi.encode(0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9, owner, spender, value, nonces[owner]++, deadline))
        ));
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress == owner, 'BentoBox: Invalid Signature');
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }
}
