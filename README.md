## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**


### Install SVM

```sh
git clone https://github.com/fastjpeg/fastjpeg-contracts
cd fastjpeg-contracts
cargo install svm-rs
svm install 0.5.16
svm install 0.6.6
```

###

Start chain

```sh
anvil --chain-id 31337 --fork-url "https://lb.drpc.org/ogrpc?network=base&dkey=AmRKOjzeAU1HukkCkUA3_r8yxoJD_FgR75-snqSgS7QB"
```

Deploy contract

```sh
forge script script/AnvilFastJPEGFactory.s.sol:AnvilFastJPEGFactory --rpc-url http://localhost:8545 --broadcast
```

FastJPEG factory address

```sh
0x834Ea01e45F9b5365314358159d92d134d89feEb
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
