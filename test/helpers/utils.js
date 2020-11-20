
e18 = (amount) => {
    return new web3.utils.BN(amount).mul(new web3.utils.BN("1000000000000000000"));
}

encodePrice = (reserve0, reserve1) => {
  return [reserve1.mul(new web3.utils.BN('2').pow(new web3.utils.BN('112'))).div(reserve0), reserve0.mul(new web3.utils.BN('2').pow(new web3.utils.BN('112'))).div(reserve1)];
}

module.exports = {
    e18,
    encodePrice
}