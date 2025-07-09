#!/bin/bash
cd "$(dirname "$0")"
BUILD_BINARY=1 RUN_IN_DOCKER=1 ./localnet.sh --no-purge  --base-path local
