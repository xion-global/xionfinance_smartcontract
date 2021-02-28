# Xion Finance Smart Contracts

The Xion Finance smart contracts running on the xDai chain and Ethereum Mainnet, powering the Xion ecosystem.

## Smart Contracts

### Xion Global Token - XGT

The Xion Global Token (XGT) is a standard ERC20 token based on the OpenZeppelin contracts. We added the following features on top of it:

- Protection against sending tokens to the token address itself, e.g.:
  - `require(recipient != address(this), "XGT-CANT-TRANSFER-TO-CONTRACT");`
- A function that burns XGT for our subscription contract (_we intend to burn a certain amount of XGT in the future_)
- Two functions facilitating transfers between Mainnet and xDai via the [Arbitrary Message Bridge](https://docs.tokenbridge.net/eth-xdai-amb-bridge/about-the-eth-xdai-amb)

There is also a mainnet version of this contract, which follows the same logic.

Deployed at [0xf1738912ae7439475712520797583ac784ea9033](https://blockscout.com/poa/xdai/address/0xf1738912ae7439475712520797583ac784ea9033).

### XGT Generator

This contract handles the rewarding of users with XGT, whether it is through earning, farming or cash-backs. This allows us to reward liquidity providers of pools that are not ours (such as the Honeyswap Pool) with XGT.

Deployed at [0xa294A842A34ab045ddb1E6eE07c417a1e13c2eDf](https://blockscout.com/poa/xdai/address/0xa294A842A34ab045ddb1E6eE07c417a1e13c2eDf).

#### Earning

Leveraging the [Arbitrary Message Bridge](https://docs.tokenbridge.net/eth-xdai-amb-bridge/about-the-eth-xdai-amb), we know how much users provided to our lending protocol on Mainnet, such that we can start the XGT generator for them on xDai. This process doesn't require additional transactions from the user.
When withdrawing their DAI on mainnet, the xDai contract is notified through the bridge to stop XGT generation.

For example, the corresponding function (called by the bridge on xDai) after a deposit looks like this:

```
function tokensStaked(uint256 _amount, address _user) external {
  require(msg.sender == address(bridge), "XGTGEN-NOT-BRIDGE");
  require(stakingContractsMainnet[bridge.messageSender()], "XGTGEN-NOT-MAINNET-CONTRACT");
  userDAITokens[_user] = userDAITokens[_user].add(_amount);
  _startGeneration(_amount, _user, xgtGenerationRateStake);
}
```

#### Farming

As soon as a user is involved in a transfer of Pool tokens (either through minting, burning, or trading them), our backend node picks this up and calls the XGT generator contract to indicate that a certain user needs to be updated. The corresponding function works in a trustless manner, such that the contract itself verifies how many XGT LP tokens the user has. Based on this, the generator of XGT starts (or ends).

#### Cashbacks

In the future, Xion will also offer cash-backs for users making use of their e-commerce platform. This functionality will be part of a later update.

### XGT Stake

This contract facilitates "earning" on Xion Finance. Users can stake their DAI, which is currently converted into cDAI and thus generating interest. Leveraging the [Arbitrary Message Bridge](https://docs.tokenbridge.net/eth-xdai-amb-bridge/about-the-eth-xdai-amb), we notify the xDai XGT Generator contract to start generating XGT for the user, which they can claim at any time. Being rewarded with XGT tokens, a small percentage of the interest.

Users can deposit tokens through this function:

```
function depositTokens(uint256 _amount) external
```

and subsequently, withdraw them with this function:

```
function withdrawTokens(uint256 _amount) external
```

Deployed at [0xa294A842A34ab045ddb1E6eE07c417a1e13c2eDf](https://etherscan.io/address/0xa294a842a34ab045ddb1e6ee07c417a1e13c2edf).

### Vesting

In order to incentivize the team and investors long-term, we are making use of a standard vesting contract, that distributes the allocated tokens over a period of 24 months.

Deployed at [0x080Dd0D9A441FA76f67A59260229dBce897148a4](https://blockscout.com/poa/xdai/address/0x080Dd0D9A441FA76f67A59260229dBce897148a4).

### Upgradeability

We are leveraging the Upgradeability features by OpenZeppelin, allowing us to introduce features without changing the contract's address as well as fixing any unforeseen bugs that could lead to a financial loss for our users. The safety of our users and consequently their funds is of utmost importance to us!

## License

[GNU Affero General Public License v3.0](https://github.com/xion-global/xionfinance_smartcontract/blob/master/LICENSE)
