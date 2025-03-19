// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Test, console } from "forge-std/Test.sol";
import { FJC } from "../src/FastJPEGFactory.sol";
import { ERC20Capped } from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Capped.sol";
import { ERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { IERC20Errors } from "../lib/openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol";

contract FastJPEGCoinTest is Test {
    FJC public fastJpegCoin;
    address public owner;
    address public user1;

    function setUp() public {
        owner = address(this);
        user1 = vm.addr(1);

        vm.deal(owner, 0 ether);
        vm.deal(user1, 100 ether);

        fastJpegCoin = new FJC("Fast JPEG Coin", "FJPC");
    }

    function test_decimals() public view {
        assertEq(fastJpegCoin.decimals(), 18);
    }

    function test_supplyCap() public view {
        assertEq(fastJpegCoin.cap(), 1_000_000_000 * 10 ** 18);
    }

    function test_mint() public {
        fastJpegCoin.mint(user1, 100_000_000 * 10 ** 18);
        assertEq(fastJpegCoin.balanceOf(user1), 100_000_000 * 10 ** 18);
    }

    function test_burn() public {
        fastJpegCoin.mint(user1, 100_000_000 * 10 ** 18);
        fastJpegCoin.burn(user1, 100_000_000 * 10 ** 18);
        assertEq(fastJpegCoin.balanceOf(user1), 0);
    }

    function test_mintOverCap() public {
        // Test that minting over the cap reverts with ERC20ExceededCap error
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20Capped.ERC20ExceededCap.selector, 1000000001000000000000000000, 1000000000000000000000000000
            )
        );
        // vm.expectRevert("ERC20Capped: cap exceeded");
        fastJpegCoin.mint(user1, 1_000_000_001 * 10 ** 18);
    }

    function test_burnOverBalance() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, user1, 0, 1000000001000000000000000000
            )
        );
        fastJpegCoin.burn(user1, 1_000_000_001 * 10 ** 18);
    }
}
