# Development Docs

...

## Deployment

npx hardhat run --network hardhat scripts/deploy.js

## Local environment

npx hardhat node

## Mainnet forking

npx hardhat node --fork https://eth-mainnet.alchemyapi.io/v2/API_KEY

https://hardhat.org/guides/mainnet-forking.html#mainnet-forking

## Testing

yarn test

### Single files

yarn test test/LendingPair.js

Mocha & Chai with Waffle matchers (these are really useful).

https://ethereum-waffle.readthedocs.io/en/latest/matchers.html

### Running Tests on VSCode

https://hardhat.org/guides/vscode-tests.html#running-tests-on-visual-studio-code

## Console

yarn console

https://hardhat.org/guides/hardhat-console.html

## Coverage

yarn test:coverage

https://hardhat.org/plugins/solidity-coverage.html#tasks

## Gas Usage

yarn test:gas

https://github.com/cgewecke/hardhat-gas-reporter

## Lint

yarn lint

## Verify

> run the verify task, passing the address of the contract, the network where it's deployed, and the constructor arguments that were used to deploy it (if any)

npx hardhat verify --network mainnet DEPLOYED_CONTRACT_ADDRESS "Constructor argument 1"

https://hardhat.org/plugins/nomiclabs-hardhat-etherscan.html#hardhat-etherscan

## Watch

npx hardhat watch compile

## Initial state

https://hardhat.org/hardhat-network/#hardhat-network-initial-state

To customise

https://hardhat.org/config/#hardhat-network

## Time travel

https://hardhat.org/hardhat-network/#special-testing-debugging-methods

## Impersonation

https://hardhat.org/hardhat-network/#hardhat-network-methods
