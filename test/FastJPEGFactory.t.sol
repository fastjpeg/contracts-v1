// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;
import {Pool} from "../lib/contracts/contracts/Pool.sol";
import {PoolFactory} from "../lib/contracts/contracts/factories/PoolFactory.sol";

import {Test, console} from "forge-std/Test.sol";
import {BaseTest} from "../lib/contracts/test/BaseTest.sol";
import {FastJPEGFactory} from "../src/FastJPEGFactory.sol";

contract FastJPEGFactoryTest is BaseTest {
    FastJPEGFactory public jpegFactory;

    function _setUp() public override {
        jpegFactory = new FastJPEGFactory(address(factory), address(router));
    }

    function testFactoryOwner() public {
        assertEq(jpegFactory.owner(), address(this));
    }
}
