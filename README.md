# Xion Finance Smart Contracts

The Xion Finance smart contracts running on the xDai chain, the Binance Smart Chain and Ethereum Mainnet, powering the Xion ecosystem.

## Smart Contracts

### Xion Global Token <img src="https://xion.finance/images/xgt_icon.png" width="16" height="16"> XGT

The Xion Global Token (XGT) is a standard ERC20 token based on the OpenZeppelin contracts. We added the following features on top of it:

- Protection against sending tokens to the token address itself, e.g.:
  - `require(recipient != address(this), "XGT-CANT-TRANSFER-TO-CONTRACT");`

There is also a mainnet and a Binance Smart Chain version of this contract, which follows the same logic.

Deployed at [0xC25AF3123d2420054c8fcd144c21113aa2853F39](https://blockscout.com/xdai/mainnet/tokens/0xC25AF3123d2420054c8fcd144c21113aa2853F39) on the xDai chain.  
Deployed at [0xC25AF3123d2420054c8fcd144c21113aa2853F39](https://bscscan.com/token/0xc25af3123d2420054c8fcd144c21113aa2853f39) on the Binance Smart Chain.  
Deployed at [0xC25AF3123d2420054c8fcd144c21113aa2853F39](https://etherscan.io/token/0xc25af3123d2420054c8fcd144c21113aa2853f39) on the Ethereum Mainnet.

### XGT Bridge

In order to allow users to use their XGT on any of these chains above, we created a custom XGT cross chain bridge based on xDai's [Arbitrary Message Bridge](https://docs.tokenbridge.net/eth-xdai-amb-bridge/about-the-eth-xdai-amb). Users can freely and without any fee (besides the gas) send their XGT between xDai and Binance Smart Chain as well as between xDai and Ethereum Mainnet.

### XGT Reward Chest

In order to reward our users, we developed a custom reward chest contract, handling the rewarding of users with XGT, whether it is through earning, farming or cash-backs. This allows us to reward liquidity providers of pools that are not ours (such as the Pancake Swap and Honeyswap Pools) with XGT.

The contract itself only provides the base functionality, while the individual modules are providing the specific features.

Deployed at [0xC2F128d188d095A47d5459C75de8185060df5E2f](https://blockscout.com/xdai/mainnet/address/0xC2F128d188d095A47d5459C75de8185060df5E2f).

#### Earning

_Comming soon!_

#### Farming (PoolModule)

As soon as a user is involved in a transfer of Pool tokens (either through minting, burning, or trading them), our backend node picks this up and calls the XGT Reward Chest contract to indicate that a certain user needs to be updated. The corresponding function works in a trustless manner, such that the contract itself verifies how many XGT LP tokens the user has. Based on this, the Reward Chest of XGT starts (or ends).

#### Cashbacks (Cashback Module)

In the near future, Xion will also offer cash-backs for users making use of their e-commerce platform. This functionality will be part of a later update.

#### Airdrops (Airdrop Module)

With our new airdrop module, we are able to easily distribute regular as well as vested airdrops to our users. The resulting XGT can be claimed via the Reward Chest like any other reward.

### Vesting

In order to incentivize the team and investors long-term, we are making use of a standard vesting contracts, that distributes the allocated tokens over a predefined vesting schedule.

Deployed at [0x58835f7a691de30057d1835aeee9bf280521722d](https://bscscan.com/address/0x58835f7a691de30057d1835aeee9bf280521722d).

### Upgradeability

We are leveraging the Upgradeability features by OpenZeppelin, allowing us to introduce features without changing the contract's address as well as fixing any unforeseen bugs that could lead to a financial loss for our users. The safety of our users and consequently their funds is of utmost importance to us!
However, we are **not** using this feature for the bridges and token itself, in order to maintain decentralization and not even having the possibility to gain access to our users funds.

## License

[GNU Affero General Public License v3.0](https://github.com/xion-global/xionfinance_smartcontract/blob/master/LICENSE)
