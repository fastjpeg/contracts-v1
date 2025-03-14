// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Script, console } from "forge-std/Script.sol";
import { FastJPEGFactory } from "../src/FastJPEGFactory.sol";

contract SepoliaFastJPEGFactoryScript is Script {
    FastJPEGFactory public fastJpegFactory;

    // https://docs.uniswap.org/contracts/v2/reference/smart-contracts/v2-deployments
    address public constant POOL_FACTORY = 0xF62c03E08ada871A0bEb309762E260a7a6a880E6; // uniswap pool factory
    address public constant ROUTER = 0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3; // uniswap router

    function setUp() public {
        fastJpegFactory = new FastJPEGFactory(POOL_FACTORY, ROUTER);
        console.log("Sepolia::FastJPEGFactory deployed at", address(fastJpegFactory));
    }
}
