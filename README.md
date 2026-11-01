# Kronex

Kronex is a public proof-of-work blockchain with an Ethereum-compatible execution
layer. It is built on [go-ethereum](https://github.com/ethereum/go-ethereum), so
accounts, transactions, Solidity contracts and the JSON-RPC API work exactly as they
do on Ethereum, and it is sealed with **kHeavyHash**, so the kHeavyHash mining
hardware and software that already exist mine Kronex with no firmware change.

Blocks are also **merge-mined** against four other proof-of-work networks. Work
already being done on Bitcoin Cash (SHA256d), Litecoin and Dogecoin (Scrypt),
Ravencoin (KawPoW) and Zcash (Equihash) can commit to Kronex and be paid for it,
without giving up the parent-chain reward.

| | |
| --- | --- |
| Website | [kronex.network](https://kronex.network/) |
| Documentation | [docs.kronex.network](https://docs.kronex.network/) |
| Testnet explorer | [explorer-testnet.kronex.network](https://explorer-testnet.kronex.network/) |
| Web wallet | [wallet.kronex.network](https://wallet.kronex.network/) |
| Testnet JSON-RPC | `https://rpc-testnet.kronex.network` |
| Node binaries | [Releases](https://github.com/kronexnetwork/kronex/releases) |
| Docker image | `ghcr.io/kronexnetwork/krnxd` |

This repository hosts the `krnxd` node releases. `krnxd` is the Kronex client: it
syncs the chain, serves JSON-RPC, builds blocks for miners and accepts their work.

## Networks

| Network | Chain ID | Status | Block time | Reward lockup |
| --- | --- | --- | --- | --- |
| Testnet | `5768` | Live | 10 s | 5 minutes |
| Mainnet | `5769` | Not launched | 10 s | 14 days |

Mainnet parameters are pinned but the network has not launched; `krnxd` refuses to
start a mainnet chain until it does. Everything below is written against the
testnet. The full comparison is in [Networks](https://docs.kronex.network/learn/networks).

The testnet exists to be reset. Do not build anything that assumes its state or its
five-minute lockup survives.

## Download

Every release ships `krnxd` for:

| Platform | Archive |
| --- | --- |
| Linux x86-64 | `krnxd-<version>-linux-amd64.tar.gz` |
| Linux ARM64 | `krnxd-<version>-linux-arm64.tar.gz` |
| macOS Apple Silicon | `krnxd-<version>-darwin-arm64.tar.gz` |
| macOS Intel | `krnxd-<version>-darwin-amd64.tar.gz` |
| Windows x86-64 | `krnxd-<version>-windows-amd64.zip` |

The Linux binaries are static and run on any distribution, including Alpine.

Get the archive from [Releases](https://github.com/kronexnetwork/kronex/releases),
then:

```bash
tar -xzf krnxd-<version>-linux-amd64.tar.gz
cd krnxd-<version>-linux-amd64
./krnxd version
```

### Verify the download

`SHA256SUMS` is attached to every release. Check the archive against it before
running anything:

```bash
sha256sum --check --ignore-missing SHA256SUMS
```

On macOS use `shasum -a 256 --check --ignore-missing SHA256SUMS`.

### macOS

The binaries are not notarized. If you downloaded the archive with a browser, macOS
quarantines it and refuses to run `krnxd`; clear the flag once:

```bash
xattr -d com.apple.quarantine ./krnxd
```

Archives fetched with `curl` carry no quarantine flag.

## Run a testnet node

```bash
krnxd --testnet
```

That is a full node: it finds peers through the built-in bootnodes, syncs the chain
and keeps it. The testnet genesis is compiled into the binary, so no `init` step and
no genesis file is needed.

To expose JSON-RPC, add the HTTP flags. Include `krnx` in the API list if you want
the Kronex-specific methods, such as mining work and merged-mining status:

```bash
krnxd --testnet \
  --http --http.addr 127.0.0.1 --http.port 8545 \
  --http.api eth,net,web3,krnx
```

Then check that the node answers and is on the right chain:

```bash
curl -s -X POST http://127.0.0.1:8545 \
  -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}'
```

The result is `0x1688`, which is 5768.

Keep RPC bound to `127.0.0.1` unless the node sits behind a proxy you control. The
`krnx` namespace contains submit methods, and `krnxadmin` must never be reachable from
outside the host.

### Data directory and ports

| | |
| --- | --- |
| Linux | `~/.kronex/testnet` |
| macOS | `~/Library/Kronex/testnet` |
| Windows | `%LOCALAPPDATA%\Kronex\testnet` |

`--datadir` overrides the location; an explicit path is used exactly as given. The
IPC socket lives inside it, so a console on a running node is
`krnxd attach ~/.kronex/testnet/krnxd.ipc`.

The node listens for peers on `30303` (TCP and UDP). Open it on your firewall if the
node should be reachable by others; it syncs fine without that. JSON-RPC uses `8545`
(HTTP) and `8546` (WebSocket) and is off by default.

`krnxd --help` lists every flag. A config file works too: `krnxd --testnet dumpconfig`
writes the current configuration as TOML, and `krnxd --config node.toml` loads one.

### Docker

Every release is also published as an image for `linux/amd64` and `linux/arm64` at
`ghcr.io/kronexnetwork/krnxd`. `:testnet` follows the latest testnet release and
`:v1.0.1-testnet.1` pins one.

```bash
docker run -d --name krnxd \
  -v krnxd-data:/root/.kronex \
  -p 30303:30303 -p 30303:30303/udp \
  ghcr.io/kronexnetwork/krnxd:testnet
```

The image runs `krnxd --testnet` by default. Arguments you pass replace that command
line, so repeat `--testnet` when adding flags. Inside a container RPC has to listen
on all interfaces to be reachable through the port mapping; keep the mapping itself
on the loopback address:

```bash
docker run -d --name krnxd \
  -v krnxd-data:/root/.kronex \
  -p 30303:30303 -p 30303:30303/udp \
  -p 127.0.0.1:8545:8545 \
  ghcr.io/kronexnetwork/krnxd:testnet \
  --testnet --http --http.addr 0.0.0.0 --http.api eth,net,web3,krnx
```

The image is built from the release archive by [`Dockerfile`](Dockerfile), which
verifies it against `SHA256SUMS`; `docker build --build-arg VERSION=v1.0.1-testnet.1 .`
reproduces it locally.

## Mining

Kronex can be mined two ways at once: directly with kHeavyHash, or merged from one of
the four parent chains. [Mining](https://docs.kronex.network/guides/mining) covers
both; the short version follows.

### Direct mining (kHeavyHash)

A node hands out work only while it is building blocks. Run it with mining enabled
and the reward address set, with the node's own CPU mining switched off:

```bash
krnxd --testnet \
  --http --http.addr 127.0.0.1 --http.port 8545 --http.api eth,net,web3,krnx \
  --mine --miner.threads 0 --miner.etherbase 0xYOUR_ADDRESS --miner.recommit 3s
```

| Flag | Why |
| --- | --- |
| `--mine` | without it no pending block is built and `krnx_getWork` errors |
| `--miner.threads 0` | templates keep being built, the node does not hash itself |
| `--miner.etherbase` | the address the block reward is credited to |
| `--miner.recommit` | how often the template is rebuilt |
| `--miner.notify URL` | optional: the node POSTs new work to your pool |

The node then serves `krnx_getWork`, `krnx_submitWork` and `krnx_submitHashrate`
(also mirrored under `eth_`). A stratum pool or bridge sits between the node and the
miners: GMiner, lolMiner, BzMiner, IceRiver and Goldshell hardware all mine the
standard kHeavyHash pre-image. The node-to-pool contract, with the work package field
by field and reference clients in Go, Rust, Node.js and Python, is in the
[pool operator reference](https://docs.kronex.network/guides/mining-pool).

The testnet difficulty floor is sized for kHeavyHash ASICs. `--miner.threads N`
makes the node hash on its own CPU, which is useful on a private network and not on
the testnet.

### Merged mining

A Bitcoin Cash, Litecoin, Ravencoin or Zcash pool commits to Kronex inside the
coinbase it already builds and earns workshare rewards on top of the parent-chain
payout, without changing what the miners' hardware does. How the binding works is in
[Merged mining](https://docs.kronex.network/learn/merged-mining); the integration
steps are in [Pool integration](https://docs.kronex.network/guides/pool-integration).

### Rewards

Block and workshare rewards are paid into a time-based lockup rather than being
spendable at once: 5 minutes on the testnet, 14 days on mainnet. See
[Rewards](https://docs.kronex.network/learn/rewards).

## Build on Kronex

Kronex keeps the Ethereum JSON-RPC surface: `eth_`, `net_`, `web3_` and `txpool_`
behave as on any go-ethereum node, so Hardhat, Foundry, ethers, viem and web3.js work
once you set the chain ID and the endpoint. The EVM is at London, and transaction
types 0, 1 and 2 are accepted.

```text
Chain ID : 5768
RPC      : https://rpc-testnet.kronex.network
Explorer : https://explorer-testnet.kronex.network
```

Everything Kronex adds lives under the `krnx_` namespace, documented in the
[RPC reference](https://docs.kronex.network/rpc/overview). Start with
[Smart contracts](https://docs.kronex.network/guides/smart-contracts).

The [web wallet](https://wallet.kronex.network/) talks to the public testnet RPC, so
it needs no node of your own.

## License

`krnxd` is a fork of go-ethereum, taken before the Merge, with the consensus layer
replaced. The node library is licensed under the
[GNU Lesser General Public License v3.0](COPYING.LESSER) and the `krnxd` binary under
the [GNU General Public License v3.0](COPYING), as inherited from go-ethereum.
