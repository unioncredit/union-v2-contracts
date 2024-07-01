# Union Contracts V2

## Background

Union is a member-owned trust backed credit network built on the EVM where members can underwrite lines of credit to other member addresses.  
The contracts operates as a DAO and enables any address to accumulate a credit line on-chain in a permission-less, crypto-native way.
The protocol itself is not an underwriter of risk, but rather a mechanism to lower the cost of coordinating trust into available credit.

Built using [foundry](https://book.getfoundry.sh/) and [hardhat](https://hardhat.org/)

## Deployments

-   Optimism

    -   [contract addresses](https://github.com/unioncredit/union-v2-contracts/blob/master/deployments/optimism/deployment.json)
    -   [deployment config](https://github.com/unioncredit/union-v2-contracts/blob/master/deployments/optimism/config.json)

-   Goerli

    -   [contract addresses](https://github.com/unioncredit/union-v2-contracts/blob/master/deployments/goerli/deployment.json)
    -   [deployment config](https://github.com/unioncredit/union-v2-contracts/blob/master/deployments/goerli/config.json)

-   Optimism Goerli

    -   [contract addresses](https://github.com/unioncredit/union-v2-contracts/blob/master/deployments/optimism-goerli/deployment.json)
    -   [deployment config](https://github.com/unioncredit/union-v2-contracts/blob/master/deployments/optimism-goerli/config.json)

-   Base Sepolia

    -   [contract addresses](https://github.com/unioncredit/union-v2-contracts/blob/master/deployments/optimism-goerli/deployment.json)
    -   [deployment config](https://github.com/unioncredit/union-v2-contracts/blob/master/deployments/optimism-goerli/config.json)

## Install

To install dependencies:

```
git clone git@github.com:unioncredit/union-v2-contracts.git && cd union-v2-contracts
yarn install
```

## Compile

To compile with hardhat:

```
yarn hh:compile
```

## Foundry

Union V1.5 Contracts also includes a suit of tests (fuzzing tests) writte in solidity with foundry

To install Foundry (assuming a Linux or macOS System):

```
curl -L https://foundry.paradigm.xyz | bash
```

This will download foundryup. To start Foundry, run:

```
foundryup
```

To install dependencies:

```
forge install
```

To run tests:

```
forge test
```

The following modifiers are also available:

-   Level 2 (-vv): Logs emitted during tests are also displayed.
-   Level 3 (-vvv): Stack traces for failing tests are also displayed.
-   Level 4 (-vvvv): Stack traces for all tests are displayed, and setup traces for failing tests are displayed.
-   Level 5 (-vvvvv): Stack traces and setup traces are always displayed.

```
forge -vv
```

To profile gas usage:

```
forge test --gas-report
forge snapshot
```

## Fork Tests

Integration tests can be run using hardhat.

```
yarn hh:test
```

They can also be run in fork mode. (Some tests can be excluded from running in fork mode and other tests can only run in fork mode)

```
FORK_NODE_URL=<URL> FORK_BLOCK=<NUMBER> yarn hh:test
```

You can also define which config should be used for the fork mode.

```
CONFIG=arbitrum FORK_NODE_URL=<URL> FORK_BLOCK=<NUMBER> yarn hh:test
```

## Format

```
yarn format
```

## Other Scripts

Deposit to L2

yarn hardhat --network sepolia --config hardhat-task.config.ts op:deposit --pk <private_key> --l1-rpc-url https://eth-sepolia.public.blastapi.io --l2-rpc-url https://sepolia.base.org --l1-union 0xE4ADdfdf5641EB4e15F60a81F63CEd4884B49823 --l2-union 0xB025ee78b54B5348BD638Fe4a6D77Ec2F813f4f9 --amount 10000
