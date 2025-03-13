// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Script, console } from "forge-std/Script.sol";
import { FastJPEGFactory } from "../src/FastJPEGFactory.sol";

contract FastJPEGFactoryScript is Script {
    FastJPEGFactory public fastJpegFactory;
    address public constant POOL_FACTORY = 0x0000000000000000000000000000000000000000;
    address public constant ROUTER = 0x0000000000000000000000000000000000000000;

    function setUp() public {
        fastJpegFactory = new FastJPEGFactory(POOL_FACTORY, ROUTER);
        // console.log("FastJPEGFactory deployed at", address(fastJpegFactory));
    }

    function run() public {
        vm.startBroadcast();

        vm.stopBroadcast();
    }
}
