# Development Docs

## Deployment

[Deployment](docs/DEPLOYMENT.md)

## Local environment

```sh
npx hardhat node
```

## Mainnet forking

```sh
npx hardhat node --fork <https://eth-mainnet.alchemyapi.io/v2/API_KEY>
```

<https://hardhat.org/guides/mainnet-forking.html#mainnet-forking>

## Testing

```sh
yarn test
```

### Single files

```sh
yarn test test/LendingPair.js
```

Mocha & Chai with Waffle matchers (these are really useful).

<https://ethereum-waffle.readthedocs.io/en/latest/matchers.html>

### Running Tests on VSCode

<https://hardhat.org/guides/vscode-tests.html#running-tests-on-visual-studio-code>

## Console

```sh
yarn console
```

<https://hardhat.org/guides/hardhat-console.html>

## Coverage

```sh
yarn coverage
```

<https://hardhat.org/plugins/solidity-coverage.html#tasks>

## Gas Usage

```sh
yarn gas
```

<https://github.com/cgewecke/hardhat-gas-reporter>

## Lint

```sh
yarn lint
```

## Watch

```sh
npx hardhat watch compile
```

## Initial state

<https://hardhat.org/hardhat-network/#hardhat-network-initial-state>

To customise

<https://hardhat.org/config/#hardhat-network>

## Time travel

<https://hardhat.org/hardhat-network/#special-testing-debugging-methods>

## Impersonation

<https://hardhat.org/hardhat-network/#hardhat-network-methods>
