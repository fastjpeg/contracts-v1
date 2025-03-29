<div align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/fastjpeg/.github/refs/heads/main/fastjpeg-wordmark.svg">
  <img alt="fastjpeg" src="https://raw.githubusercontent.com/fastjpeg/.github/refs/heads/main/fastjpeg-wordmark.svg">
</picture>
<h1>
<a href="https://bun.sh/guides/install/workspaces">contracts</a>
</h1>
</div>


### Install SVM

```sh
git clone https://github.com/fastjpeg/fastjpeg-contracts
cd fastjpeg-contracts
cargo install svm-rs
svm install 0.5.16
svm install 0.6.6
```

| Action          | Command          |
|-----------------|------------------|
| Start chain     | `bun run anvil`  |
| Deploy contract | `bun run deploy` |
| Generate ABI    | `bun run abi`    |

FastJPEG factory address

```sh
0x716473Fb4E7cD49c7d1eC7ec6d7490A03d9dA332
```

feeTo

```sh
0xe1AB8145F7E55DC933d51a18c793F901A3A0b276
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

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
