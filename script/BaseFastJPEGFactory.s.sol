// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Script, console } from "forge-std/Script.sol";
import { FastJPEGFactory } from "../src/FastJPEGFactory.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

contract BaseFastJPEGFactory is Script, StdCheats {
    FastJPEGFactory public fastJpegFactory;

    // All con
    address public constant FACTORY = 0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6; // uniswap pool factory
    address public constant ROUTER = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24; // uniswap router
    address public constant WETH = 0x4200000000000000000000000000000000000006; // weth
    address public constant FEE_TO = 0x6476383dCCaD86f334A8bA19864Af116b0A57164; // fee to

    function run() public {
        vm.startBroadcast();

        fastJpegFactory = new FastJPEGFactory(FACTORY, ROUTER, FEE_TO);
        console.log("Base::FastJPEGFactory deployed at", address(fastJpegFactory));
        console.log("Base::FeeTo deployed at", FEE_TO);
        vm.stopBroadcast();
    }

    function test() public {
        deployCodeTo("UniswapV2Factory.sol:UniswapV2Factory", abi.encode(address(this)), FACTORY);

        deployCodeTo("WETH.sol:WETH", WETH);

        deployCodeTo("UniswapV2Router02.sol:UniswapV2Router02", abi.encode(FACTORY, WETH), ROUTER);
    }
}
