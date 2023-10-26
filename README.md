# A game you cannot win!!

### I'll sell you $100 for only $1

Pretty amazing deal for you right? It's a free $99. So do we have a deal? Great!

Wait... sounds like your friend Billy will give me $5 for my $100, that's a better deal for me.

Aren't you gonna outbid him? If you bid $10 for my $100, you can still win $90. Aren't you gonna do that? Of course you are! Why wouldn't you? It's a rational thing to do.

But there is a catch:

1. Not only do I get the winning bid obviously because the winner is buying my $100
2. 2nd highest bidder also has to pay me their losing bid

So you definitely don't wanna lose or else you're just throwing your money away for nothing.

This game is designed to make bidders keep bidding until the profit incentive is gone, leaving me with a profit out of bids.

Inspired by this [video](https://www.facebook.com/VsauceTwo/videos/862570687923464/?vh=e&mibextid=UVffzb) on Facebook, I've made a smart contract out of it.


# Getting Started

## Requirements

- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
  - You'll know you did it right if you can run `git --version` and you see a response like `git version x.x.x`
- [foundry](https://getfoundry.sh/)
  - You'll know you did it right if you can run `forge --version` and you see a response like `forge 0.2.0 (816e00b 2023-03-16T00:05:26.396218Z)`


## Quickstart

```
git clone https://github.com/dexv2/fun-bid.git
cd fun-bid
forge build
```

# Usage

## Deploy:

```
forge script script/DeployAuctionFactory.s.sol
```

## Testing

1. Unit ✅
2. Integration ✅
3. Forked
4. Staging

## Advanced Testing
1. Fuzzing / Invariant ✅ - Check the Invariants [here](test/fuzz/Invariants.md)

```
forge test
```

or 

```
// Only run test functions matching the specified regex pattern.

forge test --mt <testFunctionName>
```

or

```
forge test --fork-url $SEPOLIA_RPC_URL
```

### Test Coverage

```
forge coverage
```

# Deployment to a testnet or mainnet


1. Setup environment variables

You'll want to set your `SEPOLIA_RPC_URL` and `PRIVATE_KEY` as environment variables. You can add them to a `.env` file, similar to what you see in `.env.example`.

- `PRIVATE_KEY`: The private key of your account (like from [metamask](https://metamask.io/)). **NOTE:** FOR DEVELOPMENT, PLEASE USE A KEY THAT DOESN'T HAVE ANY REAL FUNDS ASSOCIATED WITH IT.
  - You can [learn how to export it here](https://metamask.zendesk.com/hc/en-us/articles/360015289632-How-to-Export-an-Account-Private-Key).
- `SEPOLIA_RPC_URL`: This is url of the sepolia testnet node you're working with. You can get setup with one for free from [Alchemy](https://alchemy.com/?a=673c802981)

Optionally, add your `ETHERSCAN_API_KEY` if you want to verify your contract on [Etherscan](https://etherscan.io/).

2. Get testnet ETH

Head over to [faucets.chain.link](https://faucets.chain.link/) and get some testnet ETH. You should see the ETH show up in your metamask.

3. Deploy

Deploy AuctionFactory, USDT test token, and USDTFaucet.

```
forge script script/DeployAuctionFactory.s.sol --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

## Scripts

After deploying to a testnet or local net, you can run the scripts. 

Using cast deployed in sepolia example: 

### Request USDT test token

```
cast send <USDT_FAUCET_CONTRACT_ADDRESS> "requestUSDT()" --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

### Create an Auction

Creating an Auction makes you an Auctioneer automatically

```
cast send <FACTORY_CONTRACT_ADDRESS> "openAuction()" --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

### Join Auction

```
cast send <AUCTION_CONTRACT_ADDRESS> "joinAuction(uint256)" 1000000000000000000 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

## Estimate gas

You can estimate how much gas things cost by running:

```
forge snapshot
```

And you'll see an output file called `.gas-snapshot`


# Formatting


To run code formatting:
```
forge fmt
```
