# Development

If you want to contribute to our smart contracts, please use the following instructions.

All information in this document is only for development purpose. Please don't deploy
smart contracts on mainnet using this manual.

## Install Foundry Forge

All our smart contracts were written using [Solidity](https://soliditylang.org/) programming
language. For compiling, testing, and deployment, we use Foundry Forge, because it's a way
better than Hardhat.

Please use their [official documentation](https://getfoundry.sh/) to install Foundry Forge first.

## Prepare environment variables

After installing Foundry, you need to configure your `.env` file by copying it from `.env.example`:

```sh
cp .env.example .env
```

Now we need to configure your test wallet's private key for deployment.

In the terminal session, run a local node (Anvil) by executing:

```sh
make node
```

It will start a local testnet node shipped with [Foundry](https://book.getfoundry.sh/anvil/).

You will see in your terminal the following output (in your case, values will be different):

```text
Available Accounts
==================

(0) "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
(1) "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"

...

Private Keys
==================

(0) 0xac09...ff80
(1) 0x59c6...690d

...

Wallet
==================
Mnemonic:          test test test test test test test test test test test junk

...

Chain ID
==================

31337

...
```

Now copy the second available account from the "Available Accounts" section
(in this case, `0x7099...79C8`) and put it in your `.env` file in the
`BENEFICIARY_ADDRESS` variable.

Then copy the first private key from the "Private Keys" section above (in this case,
`0xac09...ff80`) and put in your `.env` file in the `DEPLOYER_PRIVATE_KEY` variable.

If you want, you can change your default commission in the `PLATFORM_COMMISSION_RATE`
variable.

## Deploying smart contracts

In another terminal session, execute the following command to deploy smart contracts:

```sh
make deploy_localhost
```

This command executes script `./script/FutuSho.s.sol`, which is responsible for deploying
the test token (ERC20) and the marketplace smart contract with a given private key and
sets a beneficiary address to your second wallet address from Anvil. Also, it sets
a default commission. All values will be loaded from the `.env` file.

When you execute the command above, you will see the following output:

```sh
...

  [617089] → new MyToken@0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9
    ├─ emit Transfer(from: 0x0000000000000000000000000000000000000000, to: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, value: 1000000000000000000000000 [1e24])
    └─ ← 2130 bytes of code

  [2422650] → new FutuSho@0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9
    ├─ emit OwnershipTransferred(previousOwner: 0x0000000000000000000000000000000000000000, newOwner: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266)
    └─ ← 10639 bytes of code

  [133994] FutuSho::addPaymentContract(MyToken: [0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9])
    ├─ emit PaymentContractAdded(newPaymentContract: MyToken: [0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9])
    └─ ← ()

...
```

Here are:

- ERC20 token contract: `0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9`
- FutúSho smart contract: `0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9`

In your case, addresses will be different.

Now you can request basic information from your smart contracts.

### How to call smart contracts from the terminal

We will use `cast` tool from Foundry to call our smart contracts.
[Here is the documentation.](https://book.getfoundry.sh/reference/cast/)

Our native network coin balance (in ETH):

```sh
cast balance 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

Output:
9999975934675702706971
```

Our ERC20 token balance (in MYTOKEN):

```sh
cast call 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 "balanceOf(address)(uint256)" "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"

Output:
1000000000000000000000000 [1e24]
```


## Configure your MetaMask

Now we need to import your test account into your crypto wallet to have access
to smart contracts.

### Import test account

I would suggest you have another browser, just to not mix up your mainnet wallets and
wallet for development purposes. It's not mandatory, but a friendly reminder.

Open MetaMask and add a new account by importing the mnemonic key from test account:
`test test test test test test test test test test test junk` (taken from the
`make node` output from above). Set up your wallet password. Please note, this is a
test wallet and should be used only for testing purposes on your development machine.

### Add your local blockchain node

In MetaMask, open "Settings" - "Networks" - "Add Network" - "Add a network manually".

Use the following options:

- Network name: Localhost
- New RPC URL: http://127.0.0.1:8545
- Chain ID: 31337
- Currency symbol: ETH

Confirm this dialog, and you will see your test wallet account with ~10000 ETH.

When you import your test account into MetaMask, you will see your wallet address,
which in our case will be `0xf39Fd...2266`.

That's it. Now you are ready to test out smart contracts!

### Import our ERC20 token into MetaMask

In MetaMask, click on "Import tokens" and fill out the following sections:

- Token contract address: `0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9` (you will have another address)
- Token symbol: ETH
- Token decimal: 18

Click "Next" and confirm "Import".

In your MetaMask, you will see your available token balance, which is 1000000 MYTOKEN.

## Running tests

The entire test suite can be run by executing the following command:

```sh
make test
```

Or if you'd like to have additional gas report, please use:

```sh
make test_with_gas
```

## If you have any questions

Please, reach out to us on [Discord](https://futusho.com/discord).
