getDataParameter = (abi, parameters) => {
  const init = abi.find(element => element.name == "getDataParameter");
  return web3.eth.abi.encodeFunctionCall(init, parameters);
}

module.exports = {
    getDataParameter
}
