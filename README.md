## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**




```sh
export OPTIMISM_RPC_URL=https://optimism.llamarpc.com
```




Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/FastJPEGFactory.s.sol:FastJPEGFactoryScript --rpc-url anvil --broadcast --verify -vvvv --sender 0x0000000000000000000000000000000000000000
```

### Cast

```shell
$ cast <subcommand>
```

### Genreate ABI
```sh
forge build --silent && jq '.abi' ./out/FastJPEGFactory.sol/FastJPEGFactory.json
``` 

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
