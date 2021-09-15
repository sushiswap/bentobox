const { weth, getBigNumber } = require("../test/utilities")

module.exports = async function (hre) {

  const { deployer, funder } = await hre.ethers.getNamedSigners()

  const chainId = await hre.getChainId()

  const polygon = {
    incentiveToken: "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270",
    lendingPool: "0x8dff5e27ea6b7ac08ebfdf9eb090f32ee9a30fcf",
    incentiveControler: "0x357D51124f59836DeD84c8a1730D72B749d8BC23",
    bentoBox: "0x0319000133d3AdA02600f0875d2cf03D442C3367",
    factory: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
    bridgeToken: "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619",
    token: "0x2791bca1f2de4661ed88a30c99a7a9449aa84174", // usdc
  }

  const kovan = {
    incentiveToken: "0x0000000000000000000000000000000000000000", // no incentives
    incentiveControler: "0x0000000000000000000000000000000000000000", // no incentives
    bentoBox: "0xc381a85ed7C7448Da073b7d6C9d4cBf1Cbf576f0",
    lendingPool: "0xE0fBa4Fc209b4948668006B2bE61711b7f465bAe",
    factory: "0x0000000000000000000000000000000000000000",
    bridgeToken: "0x0000000000000000000000000000000000000000", // bridge token for rewards
    token: "0xd0A1E359811322d97991E03f863a0C30C2cF029C", // weth
  }

  let params;

  if (chainId == 137) { // polygon
    params = polygon;
  } else if (chainId == 42) {
    params = kovan;
  } else {
    return;
  }

  const strategy = await hre.deployments.deploy("AaveStrategy", {
    from: deployer.address,
    args: [
      params.incentiveToken,
      params.lendingPool,
      params.incentiveControler,
      [
        params.token,
        params.bentoBox,
        "0x123A06e1d15189d02f9d073F10f5c3107342f3A2",
        params.factory,
        params.bridgeToken
      ]
    ],
    log: true,
    deterministicDeployment: false,
  })

}
