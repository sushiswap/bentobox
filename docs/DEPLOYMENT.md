# Deployment

...

## Mainnet

yarn mainnet:deploy
yarn mainnet:verify
hardhat tenderly:verify --network mainnet ContractName=Address
hardhat tenderly:push --network mainnet ContractName=Address

## Ropsten

yarn ropsten:deploy
yarn ropsten:verify
hardhat tenderly:verify --network ropsten ContractName=Address

## Kovan

yarn ropsten:deploy
yarn ropsten:verify
hardhat tenderly:verify --network kovan ContractName=Address
