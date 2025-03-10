// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {FastJPEGToken} from "../src/FastJPEGToken.sol";

contract FastJPEGTokenTest is Test {
    FastJPEGToken public fastJpegToken;
    address public fastJpegOwner;
    address public user1;


    function _setUp() public {
        fastJpegOwner = address(this);
        user1 = vm.addr(1);

        vm.deal(fastJpegOwner, 0 ether);
        vm.deal(user1, 100 ether);

        fastJpegToken = new FastJPEGToken("Fast JPEG Token", "FJPG");
    }

    function testDecimals() public view {
        assertEq(fastJpegToken.decimals(), 18);
    }

    function testSupplyCap() public view {
        assertEq(fastJpegToken.cap(), 1_000_000_000 * 10**18);
    }

    function testMint() public {
        fastJpegToken.mint(user1, 100_000_000 * 10**18);
        assertEq(fastJpegToken.balanceOf(user1), 100_000_000 * 10**18);
    }

    function testBurn() public {
        fastJpegToken.mint(user1, 100_000_000 * 10**18);
        fastJpegToken.burn(user1, 100_000_000 * 10**18);
        assertEq(fastJpegToken.balanceOf(user1), 0);
    }

    function testMintOverCap() public {
        vm.expectRevert("ERC20Capped: cap exceeded");
        fastJpegToken.mint(user1, 1_000_000_001 * 10**18);
    }
    

    function testBurnOverBalance() public {
        vm.expectRevert("ERC20: burn amount exceeds balance");
        fastJpegToken.burn(user1, 1_000_000_001 * 10**18);
    }
}