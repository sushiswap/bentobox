getInitData = (abi, parameters) => {
  const init = abi.find(element => element.name == "init");
  return web3.eth.abi.encodeFunctionCall(init, parameters);
}

module.exports = {
    getInitData
}
