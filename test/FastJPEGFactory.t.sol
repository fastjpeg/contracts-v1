// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;
import {Pool} from "../lib/contracts/contracts/Pool.sol";
import {PoolFactory} from "../lib/contracts/contracts/factories/PoolFactory.sol";

import {Test, console} from "forge-std/Test.sol";
import {BaseTest} from "../lib/contracts/test/BaseTest.sol";
import {FastJPEGFactory, FastJPEGToken} from "../src/FastJPEGFactory.sol";

contract FastJPEGFactoryTest is BaseTest {
    FastJPEGFactory public jpegFactory;
    
    // Test users
    address public fastJpegOwner;
    address public user1;
    address public user2;
    address public user3;
    address public user4;

    function _setUp() public override {
        jpegFactory = new FastJPEGFactory(address(factory), address(router));
        
        // Initialize test users with different addresses
        fastJpegOwner = address(this);
        user1 = vm.addr(1);
        user2 = vm.addr(2);
        user3 = vm.addr(3);
        user4 = vm.addr(4);
        
        vm.deal(fastJpegOwner, 0 ether);

        // Fund the test users with some ETH for transactions
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);
        vm.deal(user4, 100 ether);
    }

    function testFactoryOwner() public view {
        assertEq(jpegFactory.owner(), fastJpegOwner);
    }

    function testLaunchToken() public {
        // Setup test parameters
        string memory tokenName = "Fast JPEG Test Token";
        string memory tokenSymbol = "FJTT";
        
        // Set up event expectations before the action
        // vm.expectEmit(true, true, false, true);
        // // emit TokenLaunched(address(0), user1); // We can't know the token address beforehand, so we use address(0) here
        
        // Impersonate user1
        vm.prank(user1);
        
        // Call launchToken method and capture the token address
        address tokenAddress = jpegFactory.launchToken(tokenName, tokenSymbol);
        
        // Assertions
        assertTrue(tokenAddress != address(0), "Token address should not be zero");
        
        // Check token details
        FastJPEGToken token = FastJPEGToken(tokenAddress);
        assertEq(token.name(), tokenName, "Token name should match");
        assertEq(token.symbol(), tokenSymbol, "Token symbol should match");
        
        // Get the token info from the factory
        (address storedTokenAddress, uint256 ethCollected, uint256 tokensRemaining, bool isPromoted, uint256 airdropEthUsed, address poolAddress) = 
            jpegFactory.launchedTokens(tokenAddress);
            
        // Verify token info in the factory
        assertEq(storedTokenAddress, tokenAddress, "Stored token address should match");
        assertEq(ethCollected, 0, "Initial ETH collected should be 0");
        assertEq(tokensRemaining, jpegFactory.BONDING_SUPPLY(), "Tokens remaining should equal BONDING_SUPPLY");
        assertFalse(isPromoted, "Token should not be promoted initially");
        assertEq(airdropEthUsed, 0, "Initial airdrop ETH used should be 0");
        assertEq(poolAddress, address(0), "Pool address should be zero initially");
        
        // Check token balance
        assertEq(token.balanceOf(user1), 0, "User1 should receive 0 tokens");
    }
    function testBuyTokens() public {
        address tokenAddress = jpegFactory.launchToken("Fast JPEG Test Token", "FJTT");

        // Get initial tokensRemaining
        (, , uint256 initialTokensRemaining, , ,) = jpegFactory.launchedTokens(tokenAddress);
        
        // Calculate the price for buying 100 tokens
        uint256 price = jpegFactory.calculateBuyPrice(tokenAddress, 100);
        
        // Impersonate user1 and send ETH with the transaction
        vm.prank(user1);
        jpegFactory.buyTokens{value: price}(tokenAddress, 100);

        // Check token balance
        assertEq(FastJPEGToken(tokenAddress).balanceOf(user1), 100, "User1 should receive 100 tokens");

        // Calculate expected fee
        uint256 expectedFee = (price * jpegFactory.TRADE_FEE_BPS()) / jpegFactory.BPS_DENOMINATOR();
        assertEq(fastJpegOwner.balance, expectedFee, "Owner should have received the correct fee");
        
        // Check that tokensRemaining was updated correctly
        (, , uint256 updatedTokensRemaining, , ,) = jpegFactory.launchedTokens(tokenAddress);
        assertEq(updatedTokensRemaining, initialTokensRemaining - 100, "Tokens remaining should be reduced by 100");
    }

    function testSellTokens() public {
        address tokenAddress = jpegFactory.launchToken("Fast JPEG Test Token", "FJTT");

        // Calculate the price for buying 100 tokens
        uint256 price = jpegFactory.calculateBuyPrice(tokenAddress, 100);  
        
        // Impersonate user1 and send ETH with the transaction
        vm.prank(user1);
        jpegFactory.buyTokens{value: price}(tokenAddress, 100);

        // Check token balance
        assertEq(FastJPEGToken(tokenAddress).balanceOf(user1), 100, "User1 should receive 100 tokens");
        
        // Get tokensRemaining after buying
        (, , uint256 tokensRemainingAfterBuy, , ,) = jpegFactory.launchedTokens(tokenAddress);
        
        // Calculate expected buy fee
        uint256 expectedBuyFee = (price * jpegFactory.TRADE_FEE_BPS()) / jpegFactory.BPS_DENOMINATOR();
        assertEq(fastJpegOwner.balance, expectedBuyFee, "Owner should have received the correct buy fee");

        // Approve tokens for selling
        vm.startPrank(user1);
        FastJPEGToken(tokenAddress).approve(address(jpegFactory), 50);
        
        // Sell 50 tokens
        jpegFactory.sellTokens(tokenAddress, 50);
        vm.stopPrank();

        // Check token balance
        assertEq(FastJPEGToken(tokenAddress).balanceOf(user1), 50, "User1 should have 50 tokens remaining");

        // Calculate sell price and expected sell fee
        uint256 sellPrice = jpegFactory.calculateSellPrice(tokenAddress, 50);
        uint256 expectedSellFee = (sellPrice * jpegFactory.TRADE_FEE_BPS()) / jpegFactory.BPS_DENOMINATOR();
        
        // Check that owner has received both buy and sell fees
        assertEq(fastJpegOwner.balance, expectedBuyFee + expectedSellFee, "Owner should have received both buy and sell fees");
        
        // Check that tokensRemaining was updated correctly after selling
        (, , uint256 tokensRemainingAfterSell, , ,) = jpegFactory.launchedTokens(tokenAddress);
        assertEq(tokensRemainingAfterSell, tokensRemainingAfterBuy + 50, "Tokens remaining should be increased by 50 after selling");
    }
}
