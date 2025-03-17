#!/bin/sh

svm use 0.5.16
# Build the Factory imports with Solidity 0.5.16
forge build --contracts script/Imports-Factory.s.sol --use 0.5.16

svm use 0.6.6
# Build the Router imports with Solidity 0.6.6
forge build --contracts script/Imports-Router.s.sol --use 0.6.6

svm use 0.8.19
# Build the Factory imports with Solidity 0.8.19
forge build --contracts script/Imports-Factory.s.sol --use 0.8.19

# Build the Router imports with Solidity 0.8.19
forge build --contracts script/Imports-Router.s.sol --use 0.8.19
