const ethers = require('ethers');
const {BigNumber, Contract, utils} = ethers;
const {keccak256, defaultAbiCoder, toUtf8Bytes, solidityPack} = utils;
const PERMIT_TYPEHASH = keccak256(
  toUtf8Bytes('Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)')
);

const getDomainSeparator = (tokenAddress) => {
  return keccak256(
    defaultAbiCoder.encode(
      ['bytes32','uint256', 'address'],
      [
        keccak256(
          toUtf8Bytes(
            'EIP712Domain(uint256 chainId,address verifyingContract)'
          )
        ),
        1,
        tokenAddress
      ]
    )
  );
}

getApprovalDigest = async (
  token_address,
  approve,
  nonce,
  deadline
) => {
  const DOMAIN_SEPARATOR = getDomainSeparator(token_address);
  const msg = defaultAbiCoder.encode(
    ['bytes32', 'address', 'address', 'uint256', 'uint256', 'uint256'],
    [PERMIT_TYPEHASH, approve.owner, approve.spender, approve.value, nonce, deadline]
  );
  const pack = solidityPack(
    ['bytes1', 'bytes1', 'bytes32', 'bytes32'],
    ['0x19', '0x01', DOMAIN_SEPARATOR, keccak256(msg)]
  );
  return keccak256(pack);
}

module.exports = {
    getApprovalDigest,
    getDomainSeparator
}
