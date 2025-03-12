// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console } from "forge-std/Script.sol";
import { FastJPEGFactory } from "../src/FastJPEGFactory.sol";

contract FastJPEGFactoryScript is Script {
    FastJPEGFactory public fastJpegFactory;

    function setUp() public {
        // fastJpegFactory = new FastJPEGFactory();
    }

    function run() public {
        vm.startBroadcast();

        vm.stopBroadcast();
    }
}
