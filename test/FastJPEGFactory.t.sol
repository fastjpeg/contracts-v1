// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;
import {Test, console} from "forge-std/Test.sol";
import {FastJPEGFactory, FastJPEGToken} from "../src/FastJPEGFactory.sol";
import {UniswapV2Factory} from "../lib/v2-core/contracts/UniswapV2Factory.sol";
import {UniswapV2Router02} from "../lib/v2-periphery/contracts/UniswapV2Router02.sol";

contract FastJPEGFactoryTest is Test {
    IUniswapV2Factory public factory;
    IUniswapV2Router02 public router;
    FastJPEGFactory public fastJpegFactory;
    string public tokenName = "Fast JPEG Token";
    string public tokenSymbol = "FJPG";
    // Test users
    address public fastJpegOwner;
    address public user1;
    address public user2;
    address public user3;
    address public user4;

    function setUp() public {
        factory = new UniswapV2Factory(0x0);
        router = new UniswapV2Router02(address(factory), 0x0);

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

    function testCalculatePurchaseAmount() public view {
        uint256 tokensToMint1Ether = fastJpegFactory.calculatePurchaseAmount(1 ether, 0);
        assertEq(tokensToMint1Ether, 357_770_876_399966351425467786);

        uint256 tokensToMint2Ether = fastJpegFactory.calculatePurchaseAmount(2 ether, 0);
        assertEq(tokensToMint2Ether, 505_964_425_626940693119822967);    

        uint256 tokensToMint3Ether = fastJpegFactory.calculatePurchaseAmount(3 ether, 0); 
        assertEq(tokensToMint3Ether, 619_677_335_393186701628682463);

        uint256 tokensToMint4Ether = fastJpegFactory.calculatePurchaseAmount(4 ether, 0);
        assertEq(tokensToMint4Ether, 715_541_752_799932702850935573);

        uint256 tokensToMint5Ether = fastJpegFactory.calculatePurchaseAmount(5 ether, 0);
        assertEq(tokensToMint5Ether, 800_000_000_000000000000000000);        
    }

    function testCalculateSaleReturn() public view {
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

        assertEq(token.balanceOf(user1), 355977527380591821538147077, "User should have 355977527380591821538147077 FJPGtokens");
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

        assertEq(token.balanceOf(user1), 255977527380591821538147077, "User should have 255977527380591821538147077 FJPG tokens");
        assertEq(token.balanceOf(fastJpegOwner), 0, "Owner should have 0 FJPG tokens");
        assertEq(address(fastJpegFactory).balance, 0.511910113467825279 ether, "Factory should have 0.511910113467825279 ether");
        assertEq(fastJpegOwner.balance, 0.014780898865321747 ether, "Owner should have  0.014780898865321747 ether");
    }

    function testSellAll() public {
        vm.startPrank(user1);
        address tokenAddress = fastJpegFactory.createToken(tokenName, tokenSymbol);
        fastJpegFactory.buy{value: 1 ether}(tokenAddress);

        uint256 tokenBalance = FastJPEGToken(tokenAddress).balanceOf(user1);

        fastJpegFactory.sell(tokenAddress, tokenBalance);
        vm.stopPrank();

        FastJPEGToken token = FastJPEGToken(tokenAddress);

        assertEq(token.balanceOf(user1), 0, "User should have 0 FJPG tokens");
        assertEq(token.balanceOf(fastJpegOwner), 0, "Owner should have 0 FJPG tokens");
        assertEq(address(fastJpegFactory).balance, 1, "Factory should have 1 wei");
        assertEq(fastJpegOwner.balance, 0.019899999999999999 ether, "Owner should have  0.019899999999999999 ether");
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
            fastJpegFactory.tokens(tokenAddress);
            
        // Verify token info in the factory
        assertEq(storedTokenAddress, tokenAddress, "Stored token address should match");
        assertEq(poolAddress, address(0), "Pool address should be zero initially");
        assertEq(reserveBalance, 0, "Initial ETH collected should be 0");
        assertEq(tokensSold, 0, "Tokens sold should be 0");
        assertFalse(isGraduated, "Token should not be graduated initially");
        
        // Check token balance
        assertEq(token.balanceOf(user1), 0, "User1 should receive 0 tokens");
    }

    function testCreateTokenAirdrop() public {
        address[] memory airdropRecipients = new address[](4);
        airdropRecipients[0] = user1;
        airdropRecipients[1] = user2;
        airdropRecipients[2] = user3;
        airdropRecipients[3] = user4;

        vm.startPrank(user1);
        address tokenAddress = fastJpegFactory.createTokenAirdrop{value: 1 ether}(tokenName, tokenSymbol, airdropRecipients);
        vm.stopPrank();

        // Check token balance
        assertEq(FastJPEGToken(tokenAddress).balanceOf(user1), 40_000_000 * 10**18, "User1 should receive 40m tokens");
        assertEq(FastJPEGToken(tokenAddress).balanceOf(user2), 40_000_000 * 10**18, "User2 should receive 40m tokens");
        assertEq(FastJPEGToken(tokenAddress).balanceOf(user3), 40_000_000 * 10**18, "User3 should receive 40m tokens");
        assertEq(FastJPEGToken(tokenAddress).balanceOf(user4), 40_000_000 * 10**18, "User4 should receive 40m tokens");
    }

    function testCreateTokenAirdropOverPayEth() public {
        address[] memory airdropRecipients = new address[](4);
        airdropRecipients[0] = user1;
        airdropRecipients[1] = user2;
        airdropRecipients[2] = user3;
        airdropRecipients[3] = user4;

        vm.startPrank(user1);
        fastJpegFactory.createTokenAirdrop{value: 2 ether}(tokenName, tokenSymbol, airdropRecipients);
        vm.stopPrank();

        assertEq(address(fastJpegFactory).balance, 0.99 ether, "Factory should have 1 ether");
        assertEq(fastJpegOwner.balance, 0.01 ether, "Owner should have 0.01 ether");
        assertEq(user1.balance, 99 ether, "User1 should have 99 ether");
    }

    function testCreateTokenAirdropNoRecipients() public {
        vm.startPrank(user1);
        fastJpegFactory.createTokenAirdrop(tokenName, tokenSymbol, new address[](0));
        vm.stopPrank();

        assertEq(address(fastJpegFactory).balance, 0 ether, "Factory should have 0 ether");
        assertEq(fastJpegOwner.balance, 0 ether, "Owner should have 0 ether");
        assertEq(user1.balance, 100 ether, "User1 should have 100 ether");
    }
}
