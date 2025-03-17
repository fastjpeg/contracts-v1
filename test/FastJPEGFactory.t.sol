// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Test, console } from "forge-std/Test.sol";
import { FastJPEGFactory, FastJPEGToken } from "../src/FastJPEGFactory.sol";
import { IERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IUniswapV2Factory } from "../lib/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import { IUniswapV2Router02 } from "../lib/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import { WETH } from "../lib/solmate/src/tokens/WETH.sol";
import { AnvilFastJPEGFactoryScript } from "../script/AnvilFastJPEGFactory.s.sol";

contract FastJPEGFactoryTest is Test {
    IUniswapV2Factory factory = IUniswapV2Factory(0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6);
    IUniswapV2Router02 router = IUniswapV2Router02(0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24);

    FastJPEGFactory fastJpegFactory;
    string public tokenName = "Fast JPEG Token";
    string public tokenSymbol = "FJPG";
    // Test users
    address public fastJpegOwner;
    address public user1;
    address public user2;
    address public user3;
    address public user4;

    function setUp() public {
        // AnvilFastJPEGFactoryScript script = new AnvilFastJPEGFactoryScript();
        // script.run();

        // // Deploy FastJPEGFactory
        // fastJpegFactory = new FastJPEGFactory(address(factory), address(router));

        // // Initialize test users with different addresses
        // fastJpegOwner = address(this);
        // user1 = vm.addr(1);
        // user2 = vm.addr(2);
        // user3 = vm.addr(3);
        // user4 = vm.addr(4);

        // vm.deal(fastJpegOwner, 0 ether);

        // // Fund the test users with some ETH for transactions
        // vm.deal(user1, 100 ether);
        // vm.deal(user2, 100 ether);
        // vm.deal(user3, 100 ether);
        // vm.deal(user4, 100 ether);
    }

    // function testFactoryOwner() public view {
    //     assertEq(fastJpegFactory.owner(), fastJpegOwner);
    // }

    // function testCalculatePurchaseAmount() public view {
    //     uint256 tokensToMint1Ether = fastJpegFactory.calculatePurchaseAmount(2 ether, 0);
    //     assertEq(tokensToMint1Ether, 357_770_876.399966351425467786 ether);

    //     uint256 tokensToMint2Ether = fastJpegFactory.calculatePurchaseAmount(4 ether, 0);
    //     assertEq(tokensToMint2Ether, 505_964_425.626940693119822967 ether);

    //     uint256 tokensToMint3Ether = fastJpegFactory.calculatePurchaseAmount(6 ether, 0);
    //     assertEq(tokensToMint3Ether, 619_677_335.393186701628682463 ether);

    //     uint256 tokensToMint4Ether = fastJpegFactory.calculatePurchaseAmount(8 ether, 0);
    //     assertEq(tokensToMint4Ether, 715_541_752.799932702850935573 ether);

    //     uint256 tokensToMint5Ether = fastJpegFactory.calculatePurchaseAmount(10 ether, 0);
    //     assertEq(tokensToMint5Ether, 800_000_000 ether);
    // }

    // function testCalculateSaleReturn() public view {
    //     uint256 priceFor100Tokens = fastJpegFactory.calculateSaleReturn(100_000_000 * 1e18, 400_000_000 * 1e18);
    //     assertEq(priceFor100Tokens, 1.09375 ether);

    //     uint256 priceFor200Tokens = fastJpegFactory.calculateSaleReturn(200_000_000 * 1e18, 400_000_000 * 1e18);
    //     assertEq(priceFor200Tokens, 1.875 ether);

    //     uint256 priceFor300Tokens = fastJpegFactory.calculateSaleReturn(800_000_000 * 1e18, 800_000_000 * 1e18);
    //     assertEq(priceFor300Tokens, 10 ether);
    // }

    // function testBuy() public {
    //     vm.startPrank(user1);
    //     address tokenAddress = fastJpegFactory.createToken(tokenName, tokenSymbol);
    //     fastJpegFactory.buy{ value: 2 ether }(tokenAddress);
    //     vm.stopPrank();

    //     FastJPEGToken token = FastJPEGToken(tokenAddress);

    //     assertEq(
    //         token.balanceOf(user1),
    //         355977527380591821538147077,
    //         "User should have 355977527380591821538147077 FJPGtokens"
    //     );
    //     assertEq(token.balanceOf(fastJpegOwner), 0, "Owner should have 0 FJPG tokens");
    //     assertEq(address(fastJpegFactory).balance, 1.98 ether, "Factory should have 0.99 ether");
    //     assertEq(fastJpegOwner.balance, 0.02 ether, "Owner should have 0.01 ether");
    // }

    // function testSell() public {
    //     vm.startPrank(user1);
    //     address tokenAddress = fastJpegFactory.createToken(tokenName, tokenSymbol);
    //     fastJpegFactory.buy{ value: 2 ether }(tokenAddress);
    //     fastJpegFactory.sell(tokenAddress, 100_000_000 * 1e18);
    //     vm.stopPrank();

    //     FastJPEGToken token = FastJPEGToken(tokenAddress);

    //     assertEq(
    //         token.balanceOf(user1),
    //         255977527380591821538147077,
    //         "User should have 255977527380591821538147077 FJPG tokens"
    //     );
    //     assertEq(token.balanceOf(fastJpegOwner), 0, "Owner should have 0 FJPG tokens");
    //     assertEq(
    //         address(fastJpegFactory).balance,
    //         1.023820226935650558 ether,
    //         "Factory should have 1.023820226935650558 ether"
    //     );
    //     assertEq(fastJpegOwner.balance, 0.029561797730643494 ether, "Owner should have  0.029561797730643494 ether");
    // }

    // function testSellAll() public {
    //     vm.startPrank(user1);
    //     address tokenAddress = fastJpegFactory.createToken(tokenName, tokenSymbol);
    //     fastJpegFactory.buy{ value: 1 ether }(tokenAddress);

    //     uint256 tokenBalance = FastJPEGToken(tokenAddress).balanceOf(user1);

    //     fastJpegFactory.sell(tokenAddress, tokenBalance);
    //     vm.stopPrank();

    //     FastJPEGToken token = FastJPEGToken(tokenAddress);

    //     assertEq(token.balanceOf(user1), 0, "User should have 0 FJPG tokens");
    //     assertEq(token.balanceOf(fastJpegOwner), 0, "Owner should have 0 FJPG tokens");
    //     assertEq(address(fastJpegFactory).balance, 1, "Factory should have 1 wei");
    //     assertEq(fastJpegOwner.balance, 0.019899999999999999 ether, "Owner should have  0.019899999999999999 ether");
    // }

    // function testCreateToken() public {
    //     // Impersonate user1
    //     vm.prank(user1);
    //     address tokenAddress = fastJpegFactory.createToken(tokenName, tokenSymbol);

    //     // Assertions
    //     assertTrue(tokenAddress != address(0), "Token address should not be zero");

    //     // Check token details
    //     FastJPEGToken token = FastJPEGToken(tokenAddress);
    //     assertEq(token.name(), tokenName, "Token name should match");
    //     assertEq(token.symbol(), tokenSymbol, "Token symbol should match");
    //     assertEq(token.totalSupply(), 0, "Token total supply should be 1b");

    //     // Get the token info from the factory
    //     (
    //         address storedTokenAddress,
    //         address creator,
    //         address poolAddress,
    //         uint256 reserveBalance,
    //         uint256 tokensSold,
    //         bool isGraduated
    //     ) = fastJpegFactory.tokens(tokenAddress);

    //     // Verify token info in the factory
    //     assertEq(storedTokenAddress, tokenAddress, "Stored token address should match");
    //     assertEq(creator, user1, "Creator should match");
    //     assertEq(poolAddress, address(0), "Pool address should be zero initially");
    //     assertEq(reserveBalance, 0, "Initial ETH collected should be 0");
    //     assertEq(tokensSold, 0, "Tokens sold should be 0");
    //     assertFalse(isGraduated, "Token should not be graduated initially");

    //     // Check token balance
    //     assertEq(token.balanceOf(user1), 0, "User1 should receive 0 tokens");
    // }

    // function testCreateTokenAirdrop() public {
    //     address[] memory airdropRecipients = new address[](4);
    //     airdropRecipients[0] = user1;
    //     airdropRecipients[1] = user2;
    //     airdropRecipients[2] = user3;
    //     airdropRecipients[3] = user4;

    //     vm.startPrank(user1);
    //     address tokenAddress =
    //         fastJpegFactory.createTokenAirdrop{ value: 2 ether }(tokenName, tokenSymbol, airdropRecipients);
    //     vm.stopPrank();

    //     // Check token balance
    //     assertEq(
    //         FastJPEGToken(tokenAddress).balanceOf(user1),
    //         235_977_527.380591821538147077 ether,
    //         "User1 should receive 40m tokens"
    //     );
    //     assertEq(FastJPEGToken(tokenAddress).balanceOf(user2), 40_000_000 ether, "User2 should receive 40m tokens");
    //     assertEq(FastJPEGToken(tokenAddress).balanceOf(user3), 40_000_000 ether, "User3 should receive 40m tokens");
    //     assertEq(FastJPEGToken(tokenAddress).balanceOf(user4), 40_000_000 ether, "User4 should receive 40m tokens");
    // }

    // function testCreateTokenAirdropOverPayEth() public {
    //     address[] memory airdropRecipients = new address[](4);
    //     airdropRecipients[0] = user1;
    //     airdropRecipients[1] = user2;
    //     airdropRecipients[2] = user3;
    //     airdropRecipients[3] = user4;

    //     vm.startPrank(user1);
    //     fastJpegFactory.createTokenAirdrop{ value: 4 ether }(tokenName, tokenSymbol, airdropRecipients);
    //     vm.stopPrank();

    //     assertEq(address(fastJpegFactory).balance, 3.96 ether, "Factory should have 3.96 ether");
    //     assertEq(fastJpegOwner.balance, 0.04 ether, "Owner should have 0.04 ether");
    //     assertEq(user1.balance, 96 ether, "User1 should have 96 ether");
    // }

    // function testCreateTokenAirdropNoRecipients() public {
    //     vm.startPrank(user1);
    //     fastJpegFactory.createTokenAirdrop(tokenName, tokenSymbol, new address[](0));
    //     vm.stopPrank();

    //     assertEq(address(fastJpegFactory).balance, 0 ether, "Factory should have 0 ether");
    //     assertEq(fastJpegOwner.balance, 0 ether, "Owner should have 0 ether");
    //     assertEq(user1.balance, 100 ether, "User1 should have 100 ether");
    // }

    // function testNotGraduateToken() public {
    //     vm.startPrank(user1);
    //     address tokenAddress = fastJpegFactory.createToken(tokenName, tokenSymbol);
    //     fastJpegFactory.buy{ value: 10 ether }(tokenAddress);
    //     vm.stopPrank();

    //     (,,,,, bool isGraduated) = fastJpegFactory.tokens(tokenAddress);
    //     // check if token is not graduated
    //     assertEq(isGraduated, false, "Token should not be graduated");
    // }

    // function testGraduateToken() public {
    //     vm.startPrank(user1);
    //     address tokenAddress = fastJpegFactory.createToken(tokenName, tokenSymbol);
    //     fastJpegFactory.buy{ value: 12 ether }(tokenAddress);
    //     vm.stopPrank();

    //     (,,,,, bool isGraduated) = fastJpegFactory.tokens(tokenAddress);
    //     // check if token is graduated
    //     assertEq(isGraduated, true, "Token should be graduated");

    //     // assert that 0xdead owns the LP tokens
    //     address wethAddress = address(router.WETH());
    //     address lpTokenAddress = factory.getPair(tokenAddress, wethAddress);
    //     assertEq(
    //         IERC20(lpTokenAddress).balanceOf(address(fastJpegFactory)),
    //         0,
    //         "LP tokens should not be owned by factory address"
    //     );
    //     assertEq(
    //         IERC20(lpTokenAddress).balanceOf(address(0x000000000000000000000000000000000000dEaD)),
    //         43127717305695649348467,
    //         "LP tokens should be owned by 0xdead address"
    //     );

    //     // Assert
    //     // - it takes 5 ETH tdo get to graduate to Aerodrome
    //     // - 0.1 ETH is paid to Token Creator (Creator Incentive)
    //     // - 0.5 ETH is paid to FastJPEGFactory owner (Migration Fee)
    // }
}
