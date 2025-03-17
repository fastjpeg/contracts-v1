// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Script, console } from "forge-std/Script.sol";
import { FastJPEGFactory } from "../src/FastJPEGFactory.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

contract AnvilFastJPEGFactoryScript is Script, StdCheats {
    FastJPEGFactory public fastJpegFactory;

    // All con
    address public constant POOL_FACTORY = 0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6; // uniswap pool factory
    address public constant ROUTER = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24; // uniswap router
    address public constant WETH = 0x4200000000000000000000000000000000000006; // weth

    function run() public {
        deployCodeTo("UniswapV2Factory.sol:UniswapV2Factory", abi.encode(address(this)), POOL_FACTORY);

        deployCodeTo("WETH.sol:WETH", WETH);

        deployCodeTo("UniswapV2Router.sol:UniswapV2Router", abi.encode(address(this)), ROUTER);

        console.log("Anvil::FastJPEGFactory deployed at", address(fastJpegFactory));
    }
}
