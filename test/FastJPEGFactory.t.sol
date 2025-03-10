// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;
import {Pool} from "../lib/contracts/contracts/Pool.sol";
import {PoolFactory} from "../lib/contracts/contracts/factories/PoolFactory.sol";

import {Test, console} from "forge-std/Test.sol";
import {BaseTest} from "../lib/contracts/test/BaseTest.sol";
import {FastJPEGFactory, FastJPEGToken} from "../src/FastJPEGFactory.sol";

contract FastJPEGFactoryTest is BaseTest {
    FastJPEGToken public fastJpegToken;
    FastJPEGFactory public fastJpegFactory;
    string public tokenName = "Fast JPEG Token";
    string public tokenSymbol = "FJPG";
    // Test users
    address public fastJpegOwner;
    address public user1;
    address public user2;
    address public user3;
    address public user4;

    function _setUp() public override {
        fastJpegToken = new FastJPEGToken(tokenName, tokenSymbol);
        fastJpegFactory = new FastJPEGFactory(address(factory), address(router));
        
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
        assertEq(fastJpegFactory.owner(), fastJpegOwner);
    }

      function testCalculatePurchaseAmount() public {
        uint256 tokensToMint1Ether = fastJpegFactory.calculatePurchaseAmount(1 ether, 0);
        assertEq(tokensToMint1Ether, 357770876399966351425467786);

        uint256 tokensToMint2Ether = fastJpegFactory.calculatePurchaseAmount(2 ether, 0);
        assertEq(tokensToMint2Ether, 505964425626940693119822967);    

        uint256 tokensToMint3Ether = fastJpegFactory.calculatePurchaseAmount(3 ether, 0); 
        assertEq(tokensToMint3Ether, 619677335393186701628682463);

        uint256 tokensToMint4Ether = fastJpegFactory.calculatePurchaseAmount(4 ether, 0);
        assertEq(tokensToMint4Ether, 715541752799932702850935573);

        uint256 tokensToMint5Ether = fastJpegFactory.calculatePurchaseAmount(5 ether, 0);
        assertEq(tokensToMint5Ether, 800000000000000000000000000);        
    }

    function testCalculateSaleReturn() public {
        uint256 priceFor100Tokens = fastJpegFactory.calculateSaleReturn(100_000_000 * 1e18, 400_000_000 * 1e18);  
        assertEq(priceFor100Tokens, 546875000000000000);

        uint256 priceFor200Tokens = fastJpegFactory.calculateSaleReturn(200_000_000 * 1e18, 400_000_000 * 1e18);  
        assertEq(priceFor200Tokens, 937500000000000000);

        uint256 priceFor300Tokens = fastJpegFactory.calculateSaleReturn(800_000_000 * 1e18, 800_000_000 * 1e18); 
        assertEq(priceFor300Tokens, 5 ether); 
    }        

    function testBuy() public {
        vm.startPrank(user1);
        address tokenAddress = fastJpegFactory.createToken(tokenName, tokenSymbol);
        fastJpegFactory.buy{value: 1 ether}(tokenAddress);
        vm.stopPrank();

        FastJPEGToken token = FastJPEGToken(tokenAddress);

        assertEq(token.balanceOf(user1), 357_770_876_399966351425467786, "User should have 357770876399966351425467786 FJPGtokens");
        assertEq(token.balanceOf(fastJpegOwner), 0, "Owner should have 0 FJPG tokens");
        assertEq(address(fastJpegFactory).balance, 0.99 ether, "Factory should have 0.99 ether");
        assertEq(fastJpegOwner.balance, 0.01 ether, "Owner should have 0.01 ether");
    }

    function testSell() public {
        vm.startPrank(user1);
        address tokenAddress = fastJpegFactory.createToken(tokenName, tokenSymbol);
        fastJpegFactory.buy{value: 1 ether}(tokenAddress);
        fastJpegFactory.sell(tokenAddress, 100_000_000 * 1e18);
        vm.stopPrank();

        FastJPEGToken token = FastJPEGToken(tokenAddress);

        assertEq(token.balanceOf(user1), 257_770_876_399966351425467786, "User should have 257770876399966351425467786 FJPG tokens");
        assertEq(token.balanceOf(fastJpegOwner), 0, "Owner should have 0 FJPG tokens");
        assertEq(address(fastJpegFactory).balance, 0.509108005625052576 ether, "Factory should have 0.509108005625052576 ether");
        assertEq(fastJpegOwner.balance, 0.014808919943749474 ether, "Owner should have  0.014808919943749474 ether");
    }

    function testCreateToken() public {
        // Impersonate user1
        vm.prank(user1);
        address tokenAddress = fastJpegFactory.createToken(tokenName, tokenSymbol);
        
        // Assertions
        assertTrue(tokenAddress != address(0), "Token address should not be zero");
        
        // Check token details
        FastJPEGToken token = FastJPEGToken(tokenAddress);
        assertEq(token.name(), tokenName, "Token name should match");
        assertEq(token.symbol(), tokenSymbol, "Token symbol should match");
        assertEq(token.totalSupply(), 0, "Token total supply should be 1b");

        // Get the token info from the factory
        (address storedTokenAddress, address poolAddress, uint256 reserveBalance, uint256 tokensSold, bool isGraduated) = 
            fastJpegFactory.undergraduateTokens(tokenAddress);
            
        // Verify token info in the factory
        assertEq(storedTokenAddress, tokenAddress, "Stored token address should match");
        assertEq(poolAddress, address(0), "Pool address should be zero initially");
        assertEq(reserveBalance, 0, "Initial ETH collected should be 0");
        assertEq(tokensSold, 0, "Tokens sold should be 0");
        assertFalse(isGraduated, "Token should not be graduated initially");
        
        // Check token balance
        assertEq(token.balanceOf(user1), 0, "User1 should receive 0 tokens");
    }


    // function testBuyTokens() public {
    //     address tokenAddress = jpegFactory.createToken("Fast JPEG Test Token", "FJTT");

    //     // Get initial tokensRemaining
    //     (, , uint256 initialTokensRemaining, , ,) = jpegFactory.launchedTokens(tokenAddress);
        
    //     // Calculate the price for buying 100 tokens
    //     uint256 price = jpegFactory.calculateBuyPrice(tokenAddress, 100);
        
    //     // Impersonate user1 and send ETH with the transaction
    //     vm.prank(user1);
    //     jpegFactory.buyTokens{value: price}(tokenAddress, 100);

    //     // Check token balance
    //     assertEq(FastJPEGToken(tokenAddress).balanceOf(user1), 100, "User1 should receive 100 tokens");

    //     // Calculate expected fee
    //     uint256 expectedFee = (price * jpegFactory.TRADE_FEE_BPS()) / jpegFactory.BPS_DENOMINATOR();
    //     assertEq(fastJpegOwner.balance, expectedFee, "Owner should have received the correct fee");
        
    //     // Check that tokensRemaining was updated correctly
    //     (, , uint256 updatedTokensRemaining, , ,) = jpegFactory.launchedTokens(tokenAddress);
    //     assertEq(updatedTokensRemaining, initialTokensRemaining - 100, "Tokens remaining should be reduced by 100");
    // }

    // function testSellTokens() public {
    //     address tokenAddress = jpegFactory.createToken("Fast JPEG Test Token", "FJTT");

    //     // Calculate the price for buying 100 tokens
    //     uint256 price = jpegFactory.calculateBuyPrice(tokenAddress, 100);  
        
    //     // Impersonate user1 and send ETH with the transaction
    //     vm.prank(user1);
    //     jpegFactory.buyTokens{value: price}(tokenAddress, 100);

    //     // Check token balance
    //     assertEq(FastJPEGToken(tokenAddress).balanceOf(user1), 100, "User1 should receive 100 tokens");
        
    //     // Get tokensRemaining after buying
    //     (, , uint256 tokensRemainingAfterBuy, , ,) = jpegFactory.launchedTokens(tokenAddress);
        
    //     // Calculate expected buy fee
    //     uint256 expectedBuyFee = (price * jpegFactory.TRADE_FEE_BPS()) / jpegFactory.BPS_DENOMINATOR();
    //     assertEq(fastJpegOwner.balance, expectedBuyFee, "Owner should have received the correct buy fee");

    //     // Approve tokens for selling
    //     vm.startPrank(user1);
    //     FastJPEGToken(tokenAddress).approve(address(jpegFactory), 50);
        
    //     // Sell 50 tokens
    //     jpegFactory.sellTokens(tokenAddress, 50);
    //     vm.stopPrank();

    //     // Check token balance
    //     assertEq(FastJPEGToken(tokenAddress).balanceOf(user1), 50, "User1 should have 50 tokens remaining");

    //     // Calculate sell price and expected sell fee
    //     uint256 sellPrice = jpegFactory.calculateSellPrice(tokenAddress, 50);
    //     uint256 expectedSellFee = (sellPrice * jpegFactory.TRADE_FEE_BPS()) / jpegFactory.BPS_DENOMINATOR();
        
    //     // Check that owner has received both buy and sell fees
    //     assertEq(fastJpegOwner.balance, expectedBuyFee + expectedSellFee, "Owner should have received both buy and sell fees");
        
    //     // Check that tokensRemaining was updated correctly after selling
    //     (, , uint256 tokensRemainingAfterSell, , ,) = jpegFactory.launchedTokens(tokenAddress);
    //     assertEq(tokensRemainingAfterSell, tokensRemainingAfterBuy + 50, "Tokens remaining should be increased by 50 after selling");
    // }

    // function testLuanchTokenWithAirdrop() public {
    //     address[] memory airdropRecipients = new address[](4);
    //     airdropRecipients[0] = user1;
    //     airdropRecipients[1] = user2;
    //     airdropRecipients[2] = user3;
    //     airdropRecipients[3] = user4;

    //     vm.prank(user1);
    //     address tokenAddress = jpegFactory.createTokenAirdrop{ value: 1 ether }("Fast JPEG Test Token", "FJTT", airdropRecipients);

    //     // Check token balance
    //     assertEq(FastJPEGToken(tokenAddress).balanceOf(user1), 40_000_000 * 10**18, "User1 should receive 40m tokens");
    //     assertEq(FastJPEGToken(tokenAddress).balanceOf(user2), 40_000_000 * 10**18, "User2 should receive 40m tokens");
    //     assertEq(FastJPEGToken(tokenAddress).balanceOf(user3), 40_000_000 * 10**18, "User3 should receive 40m tokens");
    //     assertEq(FastJPEGToken(tokenAddress).balanceOf(user4), 40_000_000 * 10**18, "User4 should receive 40m tokens");

    //     // Check that onwer has recieved trade fee
    //     uint256 tradeFee = (1 ether * jpegFactory.TRADE_FEE_BPS()) / jpegFactory.BPS_DENOMINATOR();
    //     assertEq(fastJpegOwner.balance, tradeFee, "Owner should have received the correct trade fee");
    //     // check tokens remaining
    //     (, , uint256 tokensRemaining, , ,) = jpegFactory.launchedTokens(tokenAddress);
    //     assertEq(tokensRemaining, 800_000_000 * 10**18, "Tokens remaining should be 800m");
    // }
}
