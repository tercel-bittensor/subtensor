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