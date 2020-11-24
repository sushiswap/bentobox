bn = (amount) => {
    return new web3.utils.BN(amount);
}

e18 = (amount) => {
    return bn(amount).mul(bn("1000000000000000000"));
}

encodePrice = (reserve0, reserve1) => {
    return [reserve1.mul(bn('2').pow(bn('112'))).div(reserve0), reserve0.mul(bn('2').pow(bn('112'))).div(reserve1)];
}

getInitData = (abi, parameters) => {
    const init = abi.find(element => element.name == "init");
    return web3.eth.abi.encodeFunctionCall(init, parameters);
}

getDataParameter = (abi, parameters) => {
    const init = abi.find(element => element.name == "getDataParameter");
    return "0x" + web3.eth.abi.encodeFunctionCall(init, parameters).substr(10);
}

module.exports = {
    e18,
    encodePrice,
    getInitData,
    getDataParameter
}