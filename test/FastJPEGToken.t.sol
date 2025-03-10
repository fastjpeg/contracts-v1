// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {BaseTest} from "../lib/contracts/test/BaseTest.sol";
import {FastJPEGToken} from "../src/FastJPEGToken.sol";

contract FastJPEGTokenTest is BaseTest {
    FastJPEGToken public fastJpegToken;
    address public fastJpegOwner;
    address public user1;


    function _setUp() public override {
        fastJpegOwner = address(this);
        user1 = vm.addr(1);

        vm.deal(fastJpegOwner, 0 ether);
        vm.deal(user1, 100 ether);

        fastJpegToken = new FastJPEGToken("Fast JPEG Token", "FJPG");
    }

    function testCalculatePurchaseAmount() public {
        uint256 tokensToMint1Ether = fastJpegToken.calculatePurchaseAmount(1 ether, 0);
        assertEq(tokensToMint1Ether, 357770876399966351425467786);

        uint256 tokensToMint2Ether = fastJpegToken.calculatePurchaseAmount(2 ether, 0);
        assertEq(tokensToMint2Ether, 505964425626940693119822967);    

        uint256 tokensToMint3Ether = fastJpegToken.calculatePurchaseAmount(3 ether, 0); 
        assertEq(tokensToMint3Ether, 619677335393186701628682463);

        uint256 tokensToMint4Ether = fastJpegToken.calculatePurchaseAmount(4 ether, 0);
        assertEq(tokensToMint4Ether, 715541752799932702850935573);

        uint256 tokensToMint5Ether = fastJpegToken.calculatePurchaseAmount(5 ether, 0);
        assertEq(tokensToMint5Ether, 800000000000000000000000000);        
    }

    function testCalculateSaleReturn() public {
        uint256 priceFor100Tokens = fastJpegToken.calculateSaleReturn(100_000_000 * 1e18, 400_000_000 * 1e18);  
        assertEq(priceFor100Tokens, 546875000000000000);

        uint256 priceFor200Tokens = fastJpegToken.calculateSaleReturn(200_000_000 * 1e18, 400_000_000 * 1e18);  
        assertEq(priceFor200Tokens, 937500000000000000);

        uint256 priceFor300Tokens = fastJpegToken.calculateSaleReturn(800_000_000 * 1e18, 800_000_000 * 1e18); 
        assertEq(priceFor300Tokens, 5 ether); 
    }        

    function testBuy() public {
        vm.prank(user1);
        fastJpegToken.buy{value: 1 ether}();

        assertEq(fastJpegToken.balanceOf(user1), 357_770_876_399966351425467786, "User should have 357770876399966351425467786 FJPGtokens");
        assertEq(fastJpegToken.balanceOf(fastJpegOwner), 0, "Owner should have 0 FJPG tokens");
        assertEq(address(fastJpegToken).balance, 0.99 ether, "Owner should have 0.99 ether");
        assertEq(fastJpegOwner.balance, 0.01 ether, "Owner should have 0.01 ether");
    }

    function testSell() public {
        vm.prank(user1);
        fastJpegToken.buy{value: 1 ether}();
        vm.prank(user1);
        fastJpegToken.sell(100_000_000 * 1e18);

        assertEq(fastJpegToken.balanceOf(user1), 257_770_876_399966351425467786, "User should have 257770876399966351425467786 FJPG tokens");
        assertEq(fastJpegToken.balanceOf(fastJpegOwner), 0, "Owner should have 0 FJPG tokens");
        assertEq(address(fastJpegToken).balance, 0.509108005625052576 ether, "Owner should have 0.509108005625052576 ether");
        assertEq(fastJpegOwner.balance, 0.014808919943749474 ether, "Owner should have  0.014808919943749474 ether");
    }
}   