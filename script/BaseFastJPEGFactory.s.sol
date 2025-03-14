// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Script, console } from "forge-std/Script.sol";
import { FastJPEGFactory } from "../src/FastJPEGFactory.sol";

contract BaseFastJPEGFactoryScript is Script {
    FastJPEGFactory public fastJpegFactory;

    // https://aerodrome.finance/security#contracts
    address public constant POOL_FACTORY = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da; // aerodrome pool factory
    address public constant ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43; // aerodrome router

    function setUp() public {
        fastJpegFactory = new FastJPEGFactory(POOL_FACTORY, ROUTER);
        console.log("Base::FastJPEGFactory deployed at", address(fastJpegFactory));
    }
}
