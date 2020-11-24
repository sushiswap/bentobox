#!/usr/bin/env bash

# Exit script as soon as a command fails.
set -o errexit

# Executes cleanup function at script exit.
trap cleanup EXIT

cleanup() {
  # Kill the ganache instance that we started (if we started one and if it's still running).
  if [ -n "$ganache_pid" ] && ps -p $ganache_pid > /dev/null; then
    kill -9 $ganache_pid
  fi
}

ganache_port=7545

ganache_running() {
  nc -z localhost "$ganache_port"
}

start_ganache() {
  # We define 10 accounts with balance 1M ether, needed for high-value tests.
  local accounts=(
    --account="0x278a5de700e29faae8e40e366ec5012b5ec63d36ec77e8a2417154cc1d25383f,990000000000000000000"
    --account="0x7bc8feb5e1ce2927480de19d8bc1dc6874678c016ae53a2eec6a6e9df717bfac,1000000000000000000000000"
    --account="0x94890218f2b0d04296f30aeafd13655eba4c5bbf1770273276fee52cbe3f2cb4,1000000000000000000000000"
    --account="0x12340218f2b0d04296f30aeafd13655eba4c5bbf1770273276fee52cbe3f2cb4,1000000000000000000000000"
    --account="0x043a569345b08ead19d1d4ba3462b30632feba623a2a85a3b000eb97f709f09f,1000000000000000000000000"
  )

  ganache-cli --gasLimit 9000000 "${accounts[@]}" -p "$ganache_port" > /dev/null &

  ganache_pid=$!
}

if ganache_running; then
  echo "Using existing ganache instance"
else
  echo "Starting our own ganache instance"
  start_ganache
fi

truffle test "$@"
