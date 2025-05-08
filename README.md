<div align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/fastjpeg/.github/refs/heads/main/fastjpeg-wordmark.svg" style="max-height: 48px;">
  <img alt="fastjpeg" src="https://raw.githubusercontent.com/fastjpeg/.github/refs/heads/main/fastjpeg-wordmark.svg" style="max-height: 48px;">
</picture>
<h1>
<a href="https://bun.sh/guides/install/workspaces">contracts</a>
</h1>
</div>


### Setup project

```sh
## Clone
git clone https://github.com/fastjpeg/fastjpeg-contracts
cd fastjpeg-contracts

## Install Foundey
curl -L https://foundry.paradigm.xyz | bash
foundryup
forge build


## Install SVM
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
0x6476383dccad86f334a8ba19864af116b0a57164
```

### Verify Contract
```sh
forge verify-contract --rpc-url "https://lb.drpc.org/ogrpc?network=sepolia&dkey=AmRKOjzeAU1HukkCkUA3_r8yxoJD_FgR75-snqSgS7QB" \
  --etherscan-api-key $ETHERSCAN_API_KEY_SEPOLIA \
  0xcAfe5f609AFD116cB3AF6b37B0781a86A0F12F9D \
  src/FastJPEGFactory.sol:FastJPEGFactory \
  --watch
```
