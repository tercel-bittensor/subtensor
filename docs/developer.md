# 1. Why do you need to specify --subtensor.network local for local development?
The purpose of --subtensor.network local is to tell your program/script/service that you are connecting to a local development chain (local network), rather than the mainnet or testnet, etc.
This allows your code to distinguish between different chain environments and select different chain configurations, endpoints, genesis files, initial accounts, etc.

## Where is 'local' defined in the project code?
In the file node/src/command.rs, there is the following code snippet:
```rust
  fn load_spec(&self, id: &str) -> Result<Box<dyn sc_service::ChainSpec>, String> {
      Ok(match id {
          "dev" => Box::new(chain_spec::localnet::localnet_config(true)?),
          "local" => Box::new(chain_spec::localnet::localnet_config(false)?),
          "finney" => Box::new(chain_spec::finney::finney_mainnet_config()?),
          "devnet" => Box::new(chain_spec::devnet::devnet_config()?),
          "" | "test_finney" => Box::new(chain_spec::testnet::finney_testnet_config()?),
          path => Box::new(chain_spec::ChainSpec::from_json_file(
              std::path::PathBuf::from(path),
          )?),
      })
  }
```
Here, "local" is the network identifier you specify in the command line argument --chain local or --subtensor.network local. When you specify local, the code calls chain_spec::localnet::localnet_config(false) to load the configuration for the local development chain.
The specific implementation of localnet_config can be found in node/src/chain_spec/localnet.rs, which sets up the genesis configuration, initial accounts, tokens, permissions, etc. for the local chain.

## Summary
'local' is a network identifier reserved specifically for the local development environment in the node startup parameters and chain configuration.
You need to specify --subtensor.network local so that the code can load the local chain configuration (such as genesis file, ports, initial accounts, etc.) instead of the mainnet or testnet configuration.
The relevant definitions and logic are mainly in node/src/command.rs and node/src/chain_spec/localnet.rs.

# 2. Set the average expected block time
 common/src/lib.rs
```rust
    /// This determines the average expected block time that we are targeting. Blocks will be
    /// produced at a minimum duration defined by `SLOT_DURATION`. `SLOT_DURATION` is picked up by
    /// `pallet_timestamp` which is in turn picked up by `pallet_aura` to implement `fn
    /// slot_duration()`.
    ///
    /// Change this to adjust the block time.
    #[cfg(not(feature = "fast-blocks"))]
    pub const MILLISECS_PER_BLOCK: u64 = 12000;

    /// Fast blocks for development
    #[cfg(feature = "fast-blocks")]
    pub const MILLISECS_PER_BLOCK: u64 = 1000;
```

# 3. Modify Settlement (Epoch) Period
 runtime/src/lib.rs
```rust
#[cfg(not(feature = "fast-blocks"))]
pub const INITIAL_SUBNET_TEMPO: u16 = 360;

#[cfg(feature = "fast-blocks")]
pub const INITIAL_SUBNET_TEMPO: u16 = 10;
```

// ---
// Explanation:
// INITIAL_SUBNET_TEMPO defines the epoch or settlement period, i.e., how many blocks make up one epoch. 
// At the end of each epoch, operations such as weight updates and reward distributions are triggered. 
// A smaller value means more frequent settlements. For local development and testing (with the 'fast-blocks' feature), this value is set lower to speed up testing cycles.
// ---
```rust
#[cfg(not(feature = "fast-blocks"))]
pub const INITIAL_CHILDKEY_TAKE_RATELIMIT: u64 = 216000; // 30 days at 12 seconds per block

#[cfg(feature = "fast-blocks")]
pub const INITIAL_CHILDKEY_TAKE_RATELIMIT: u64 = 5;
```
// ---
// Explanation:
// INITIAL_CHILDKEY_TAKE_RATELIMIT sets the cooldown period for childkey-related operations (such as withdrawals or reward claims).
// It specifies how many blocks must pass before such an operation can be performed again. In production, this is set to a long period (e.g., 216,000 blocks ≈ 30 days),
// while in local development/testing, it is much shorter to facilitate rapid testing.
// ---

4. The default cooldown block number for set_weights
In `pallets/subtensor/src/lib.rs`, `WeightsSetRateLimit` is a storage item, and each `netuid` has its own value.
Usually, `DefaultWeightsSetRateLimit <= INITIAL_SUBNET_TEMPO`
```rust
    /// Default value for weights set rate limit.
    pub fn DefaultWeightsSetRateLimit<T: Config>() -> u64 {
        100
    }
```