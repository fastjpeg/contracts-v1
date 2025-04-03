// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Script, console } from "forge-std/Script.sol";
import { FastJPEGFactory } from "../src/FastJPEGFactory.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

contract SepoliaFastJPEGFactory is Script, StdCheats {
    FastJPEGFactory public fastJpegFactory;

    // All con
    address public constant FACTORY = 0xF62c03E08ada871A0bEb309762E260a7a6a880E6; // uniswap pool factory
    address public constant ROUTER = 0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3; // uniswap router
    address public constant WETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14; // weth
    address public constant FEE_TO = 0x6476383dCCaD86f334A8bA19864Af116b0A57164; // fee to

    function run() public {
        vm.startBroadcast();

        fastJpegFactory = new FastJPEGFactory(FACTORY, ROUTER, FEE_TO);
        console.log("Sepolia::FastJPEGFactory deployed at", address(fastJpegFactory));
        console.log("Sepolia::FeeTo deployed at", FEE_TO);
        vm.stopBroadcast();
    }

    function test() public {
        deployCodeTo("UniswapV2Factory.sol:UniswapV2Factory", abi.encode(address(this)), FACTORY);

        deployCodeTo("WETH.sol:WETH", WETH);

        deployCodeTo("UniswapV2Router02.sol:UniswapV2Router02", abi.encode(FACTORY, WETH), ROUTER);
    }
}
