function weth(chainId) {
  return {
    "1": "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2", // Mainnet
    "3": "0xc778417E063141139Fce010982780140Aa0cD5Ab",  // Ropsten
    "4": "0xc778417E063141139Fce010982780140Aa0cD5Ab", // Rinkeby
    "5": "0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6", // Gorli
    "42": "0xd0A1E359811322d97991E03f863a0C30C2cF029C", // Kovan
    "56": "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c", // Binance
    "97": "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd", // Binance Testnet
    "137": "0x084666322d3ee89aAbDBBCd084323c9AF705C7f5", // Matic
    "250": "0x21be370d5312f44cb42ce377bc9b8a0cef1a4c83", // Fantom
    "4002": "0xf1277d1ed8ad466beddf92ef448a132661956621", // Fantom Testnet
    "1287": "0x1Ff68A3621C17a38E689E5332Efcab9e6bE88b5D", // Moonbeam Testnet
    "43113": "0xd00ae08403B9bbb9124bB305C09058E32C39A48c", // Fuji Testnet (Avalanche)
    "43114": "0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7", // Avalanche
    "80001": "0x5B67676a984807a212b1c59eBFc9B3568a474F0a", // Mumbai Testnet (MATIC)
    "79377087078960": "0xf8456e5e6A225C2C1D74D8C9a4cB2B1d5dc1153b", // Arbitrum Testnet
    }[chainId.toString()]
}

module.exports = async function ({ ethers, artifacts, deployments, getChainId, getNamedAccounts }) {
  const { deploy } = deployments
  const { deployer, funder } = await ethers.getNamedSigners()
  const chainId = await getChainId()
  const wethAddress = weth(chainId)
  if (!wethAddress) { 
    console.log("No WETH address for chain", chainId)
    return; 
  }

  const gasPrice = await funder.provider.getGasPrice()
  const multiplier = chainId == "1" || chainId == "56" || chainId == "250" ? 1 : 3
  console.log("Gasprice:", gasPrice.toString(), " with multiplier ", multiplier)

  //const bento = await artifacts.readArtifact("BentoBoxV1")
  //console.log(bento.bytecode.length)

  // Goal: 4946355

  console.log("Sending native token to fund deployment")
  let tx = await funder.sendTransaction({
    to: deployer.address,
    value: gasPrice.mul(5190000).mul(multiplier),
    gasPrice: gasPrice.mul(multiplier) 
  });
  await tx.wait();

  console.log("Deploying contract")
  tx = await deploy("BentoBoxV1", {
    from: deployer.address,
    args: [wethAddress],
    log: true,
    deterministicDeployment: false,
    gasLimit: 5000000,
    gasPrice: gasPrice.mul(multiplier)    
  })
}
