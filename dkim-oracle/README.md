## Local Development

In order to deploy this code to a local testnet, you should install the dependencies and compile the contracts:

```bash
# Install node_modules
npm install

# Install Foundry (if not already installed)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install dependencies
forge install

# Compile contracts
forge build

# Run tests
forge test

# Deploy to network
cp .env.example .env

anvil --timestamp 1742270400 --gas-limit 60000000

source .env

forge script src/deploy/DeployDKIMOracleReduced.s.sol --rpc-url local --broadcast
```


### Anvil

Local Ethereum node, akin to Ganache, Hardhat Network.

```shell
$ anvil
```

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/




### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
