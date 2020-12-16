const {
  utils: { keccak256, defaultAbiCoder, toUtf8Bytes, solidityPack },
} = require("ethers")

const { BN } = require("bn.js")

const { parseUnits } = require("ethers/lib/utils")

const bn = (amount) => {
  return ethers.BigNumber.from(amount)
}

const roundBN = (number) => {
  return new BN(number.toString())
    .divRound(new BN("10000000000000000"))
    .toString()
}

const encodePrice = (reserve0, reserve1) => {
  return [
    reserve1.mul(bn("2").pow(bn("112"))).div(reserve0),
    reserve0.mul(bn("2").pow(bn("112"))).div(reserve1),
  ]
}

const PERMIT_TYPEHASH = keccak256(
  toUtf8Bytes(
    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
  )
)

const e18 = (amount) => {
  return parseUnits(String(amount), 18)
}

function getDomainSeparator(tokenAddress, chainId) {
  return keccak256(
    defaultAbiCoder.encode(
      ["bytes32", "uint256", "address"],
      [
        keccak256(
          toUtf8Bytes("EIP712Domain(uint256 chainId,address verifyingContract)")
        ),
        chainId,
        tokenAddress,
      ]
    )
  )
}

function getApprovalDigest(token, approve, nonce, deadline, chainId = 1) {
  const DOMAIN_SEPARATOR = getDomainSeparator(token.address, chainId)
  const msg = defaultAbiCoder.encode(
    ["bytes32", "address", "address", "uint256", "uint256", "uint256"],
    [
      PERMIT_TYPEHASH,
      approve.owner,
      approve.spender,
      approve.value,
      nonce,
      deadline,
    ]
  )
  const pack = solidityPack(
    ["bytes1", "bytes1", "bytes32", "bytes32"],
    ["0x19", "0x01", DOMAIN_SEPARATOR, keccak256(msg)]
  )
  return keccak256(pack)
}

function getApprovalMsg(tokenAddress, approve, nonce, deadline) {
  const DOMAIN_SEPARATOR = getDomainSeparator(tokenAddress)
  const msg = defaultAbiCoder.encode(
    ["bytes32", "address", "address", "uint256", "uint256", "uint256"],
    [
      PERMIT_TYPEHASH,
      approve.owner,
      approve.spender,
      approve.value,
      nonce,
      deadline,
    ]
  )
  const pack = solidityPack(
    ["bytes1", "bytes1", "bytes32", "bytes32"],
    ["0x19", "0x01", DOMAIN_SEPARATOR, keccak256(msg)]
  )
  return pack
}

function sansBorrowFee(amount) {
  return amount
    .mul(ethers.BigNumber.from(2000))
    .div(ethers.BigNumber.from(2001))
}

module.exports = {
  getDomainSeparator,
  getApprovalDigest,
  getApprovalMsg,
  sansBorrowFee,
  e18,
  bn,
  encodePrice,
  roundBN,
}
