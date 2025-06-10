#!/bin/bash

# Check if `--no-purge` passed as a parameter
NO_PURGE=0

# Check if `--build-only` passed as parameter
BUILD_ONLY=0

CUSTOM_BASE_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-purge)
      NO_PURGE=1
      shift
      ;;
    --build-only)
      BUILD_ONLY=1
      shift
      ;;
    --base-path)
      CUSTOM_BASE_PATH="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done


# Determine the directory this script resides in. This allows invoking it from any location.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# The base directory of the subtensor project
BASE_DIR="$SCRIPT_DIR/.."

if [ -z "$CUSTOM_BASE_PATH" ]; then
  BASE_PATH_ROOT="/tmp"
elif [[ "$CUSTOM_BASE_PATH" != /* ]]; then
  BASE_PATH_ROOT="$BASE_DIR/.data/$CUSTOM_BASE_PATH"
  mkdir -p $BASE_PATH_ROOT
else
  BASE_PATH_ROOT="$CUSTOM_BASE_PATH"
fi

ALICE_BASE_PATH="$BASE_PATH_ROOT/alice"
BOB_BASE_PATH="$BASE_PATH_ROOT/bob"

# Get the value of fast_blocks from the first argument
fast_blocks=${1:-"True"}

# Define the target directory for compilation
if [ "$fast_blocks" == "False" ]; then
  # Block of code to execute if fast_blocks is False
  echo "fast_blocks is Off"
  : "${CHAIN:=local}"
  : "${BUILD_BINARY:=1}"
  : "${FEATURES:="pow-faucet"}"
  BUILD_DIR="$BASE_DIR/target/non-fast-blocks"
else
  # Block of code to execute if fast_blocks is not False
  echo "fast_blocks is On"
  : "${CHAIN:=local}"
  : "${BUILD_BINARY:=1}"
  : "${FEATURES:="pow-faucet fast-blocks"}"
  BUILD_DIR="$BASE_DIR/target/fast-blocks"
fi

# Ensure the build directory exists
mkdir -p "$BUILD_DIR"

SPEC_PATH="${SCRIPT_DIR}/specs/"
FULL_PATH="$SPEC_PATH$CHAIN.json"

# Kill any existing nodes which may have not exited correctly after a previous run.
pkill -9 'node-subtensor'

if [ ! -d "$SPEC_PATH" ]; then
  echo "*** Creating directory ${SPEC_PATH}..."
  mkdir -p "$SPEC_PATH"
fi

if [[ $BUILD_BINARY == "1" ]]; then
  echo "*** Building substrate binary..."
  CARGO_TARGET_DIR="$BUILD_DIR" cargo build --workspace --profile=release --features "$FEATURES" --manifest-path "$BASE_DIR/Cargo.toml"
  echo "*** Binary compiled"
fi

echo "*** Building chainspec..."
"$BUILD_DIR/release/node-subtensor" build-spec --disable-default-bootnode --raw --chain "$CHAIN" >"$FULL_PATH"
echo "*** Chainspec built and output to file"

# Generate node keys
"$BUILD_DIR/release/node-subtensor" key generate-node-key --chain="$FULL_PATH" --base-path "$ALICE_BASE_PATH"
"$BUILD_DIR/release/node-subtensor" key generate-node-key --chain="$FULL_PATH" --base-path "$BOB_BASE_PATH"

if [ $NO_PURGE -eq 1 ]; then
  echo "*** Purging previous state skipped..."
else
  echo "*** Purging previous state..."
  "$BUILD_DIR/release/node-subtensor" purge-chain -y --base-path "$BOB_BASE_PATH" --chain="$FULL_PATH" >/dev/null 2>&1
  "$BUILD_DIR/release/node-subtensor" purge-chain -y --base-path "$ALICE_BASE_PATH" --chain="$FULL_PATH" >/dev/null 2>&1
  echo "*** Previous chainstate purged"
fi

if [ $BUILD_ONLY -eq 0 ]; then
  echo "*** Starting localnet nodes..."

  alice_start=(
    "$BUILD_DIR/release/node-subtensor"
    --base-path "$ALICE_BASE_PATH"
    --chain="$FULL_PATH"
    --alice
    --port 30334
    --rpc-port 9944
    --validator
    --rpc-cors=all
    --allow-private-ipv4
    --discover-local
    --unsafe-force-node-key-generation
  )

  bob_start=(
    "$BUILD_DIR/release/node-subtensor"
    --base-path "$BOB_BASE_PATH"
    --chain="$FULL_PATH"
    --bob
    --port 30335
    --rpc-port 9945
    --validator
    --rpc-cors=all
    --allow-private-ipv4
    --discover-local
    --unsafe-force-node-key-generation
  )

  # Provide RUN_IN_DOCKER local environment variable if run script in the docker image
  if [ "${RUN_IN_DOCKER}" == "1" ]; then
    alice_start+=(--unsafe-rpc-external)
    bob_start+=(--unsafe-rpc-external)
  fi

  trap 'pkill -P $$' EXIT SIGINT SIGTERM

  (
    ("${alice_start[@]}" 2>&1) &
    ("${bob_start[@]}" 2>&1)
    wait
  )
fi
