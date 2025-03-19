// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Test, console } from "forge-std/Test.sol";
import { FastJPEGFactory, FJC } from "../src/FastJPEGFactory.sol";
import { IERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IUniswapV2Factory } from "../lib/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import { IUniswapV2Router02 } from "../lib/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import { WETH } from "../lib/solmate/src/tokens/WETH.sol";
import { AnvilFastJPEGFactory } from "../script/AnvilFastJPEGFactory.s.sol";

contract FastJPEGFactoryTest is Test {
    IUniswapV2Factory uniswapV2Factory = IUniswapV2Factory(0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6);
    IUniswapV2Router02 uniswapV2Router = IUniswapV2Router02(0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24);
    WETH weth = WETH(payable(0x4200000000000000000000000000000000000006));
    FastJPEGFactory factory;
    string public coinName = "Fast JPEG Coin";
    string public coinSymbol = "FJPG";
    // Test users
    address public owner;
    address public user1;
    address public user2;
    address public user3;
    address public user4;
    address public feeTo;

    function setUp() public {
        // Initialize test users with different addresses
        owner = address(this);
        user1 = vm.addr(1);
        user2 = vm.addr(2);
        user3 = vm.addr(3);
        user4 = vm.addr(4);
        feeTo = vm.addr(5);

        AnvilFastJPEGFactory script = new AnvilFastJPEGFactory();
        script.test();

        // Deploy FastJPEGFactory
        factory = new FastJPEGFactory(address(uniswapV2Factory), address(uniswapV2Router), feeTo);

        // Fund the test users with some ETH for transactions
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);
        vm.deal(user4, 100 ether);
        vm.deal(feeTo, 0 ether);
    }

    function test_factory() public view {
        assertNotEq(factory.feeTo(), address(0), "Factory feeTo should not be zero");
    }

    function test_router() public view {
        assertEq(address(uniswapV2Router.WETH()), address(weth), "Wrapped WETH should be correct");
    }

    function test_calculatePurchaseAmount() public view {
        uint256 coinsToMint1Ether = factory.calculatePurchaseAmount(2 ether, 0);
        assertEq(coinsToMint1Ether, 357_770_876.399966351425467786 ether);

        uint256 coinsToMint2Ether = factory.calculatePurchaseAmount(4 ether, 0);
        assertEq(coinsToMint2Ether, 505_964_425.626940693119822967 ether);

        uint256 coinsToMint3Ether = factory.calculatePurchaseAmount(6 ether, 0);
        assertEq(coinsToMint3Ether, 619_677_335.393186701628682463 ether);

        uint256 coinsToMint4Ether = factory.calculatePurchaseAmount(8 ether, 0);
        assertEq(coinsToMint4Ether, 715_541_752.799932702850935573 ether);

        uint256 coinsToMint5Ether = factory.calculatePurchaseAmount(10 ether, 0);
        assertEq(coinsToMint5Ether, 800_000_000 ether);
    }

    function test_calculateSaleReturn() public view {
        uint256 priceFor100Coins = factory.calculateSaleReturn(100_000_000 * 1e18, 400_000_000 * 1e18);
        assertEq(priceFor100Coins, 1.09375 ether);

        uint256 priceFor200Coins = factory.calculateSaleReturn(200_000_000 * 1e18, 400_000_000 * 1e18);
        assertEq(priceFor200Coins, 1.875 ether);

        uint256 priceFor300Coins = factory.calculateSaleReturn(800_000_000 * 1e18, 800_000_000 * 1e18);
        assertEq(priceFor300Coins, 10 ether);
    }

    function test_buy() public {
        vm.startPrank(user1);
        address coinAddress = factory.newCoin(coinName, coinSymbol);
        factory.buy{ value: 2 ether }(coinAddress);
        vm.stopPrank();

        FJC coin = FJC(coinAddress);

        assertEq(
            coin.balanceOf(user1), 355977527380591821538147077, "User should have 355977527380591821538147077 FJPGCoins"
        );
        assertEq(coin.balanceOf(owner), 0, "Owner should have 0 FJPGCoins");
        assertEq(address(factory).balance, 1.98 ether, "Factory should have 1.98 ether");
        assertEq(coin.balanceOf(feeTo), 0, "Fee recipient should have 0 FJPGCoins");
        assertEq(feeTo.balance, 0.02 ether, "Fee recipient should have 0.02 ether");
    }

    function test_sell() public {
        vm.startPrank(user1);
        address coinAddress = factory.newCoin(coinName, coinSymbol);
        factory.buy{ value: 2 ether }(coinAddress);
        factory.sell(coinAddress, 100_000_000 * 1e18);
        vm.stopPrank();

        FJC coin = FJC(coinAddress);

        assertEq(
            coin.balanceOf(user1), 255977527380591821538147077, "User should have 255977527380591821538147077 FJPGCoins"
        );
        assertEq(coin.balanceOf(owner), 0, "Owner should have 0 FJPGCoins");
        assertEq(address(factory).balance, 1.023820226935650558 ether, "Factory should have 1.023820226935650558 ether");
        assertEq(coin.balanceOf(feeTo), 0, "Fee recipient should have 0 FJPGCoins");
        assertEq(feeTo.balance, 0.029561797730643494 ether, "Fee recipient should have  0.029561797730643494 ether");
    }

    function testSellAll() public {
        vm.startPrank(user1);
        address coinAddress = factory.newCoin(coinName, coinSymbol);
        factory.buy{ value: 1 ether }(coinAddress);

        uint256 coinBalance = FJC(coinAddress).balanceOf(user1);

        factory.sell(coinAddress, coinBalance);
        vm.stopPrank();

        FJC coin = FJC(coinAddress);

        assertEq(coin.balanceOf(user1), 0, "User should have 0 FJPGCoins");
        assertEq(coin.balanceOf(owner), 0, "Owner should have 0 FJPGCoins");
        assertEq(address(factory).balance, 1, "Factory should have 1 wei");
        assertEq(coin.balanceOf(feeTo), 0, "Fee recipient should have 0 FJPGCoins");
        assertEq(feeTo.balance, 0.019899999999999999 ether, "Fee recipient should have  0.019899999999999999 ether");
    }

    function test_createToken() public {
        // Impersonate user1
        vm.prank(user1);
        address coinAddress = factory.newCoin(coinName, coinSymbol);

        // Assertions
        assertTrue(coinAddress != address(0), "Token address should not be zero");

        // Check token details
        FJC coin = FJC(coinAddress);
        assertEq(coin.name(), coinName, "Coin name should match");
        assertEq(coin.symbol(), coinSymbol, "Coin symbol should match");
        assertEq(coin.totalSupply(), 0, "Coin total supply should be 1b");

        // Get the token info from the factory
        (
            address storedCoinAddress,
            address creator,
            address poolAddress,
            uint256 ethReserve,
            uint256 coinsSold,
            bool isGraduated
        ) = factory.coins(coinAddress);

        // Verify token info in the factory
        assertEq(storedCoinAddress, coinAddress, "Stored coin address should match");
        assertEq(creator, user1, "Creator should match");
        assertEq(poolAddress, address(0), "Pool address should be zero initially");
        assertEq(ethReserve, 0, "Initial ETH collected should be 0");
        assertEq(coinsSold, 0, "Coins sold should be 0");
        assertFalse(isGraduated, "Coin should not be graduated initially");

        // Check token balance
        assertEq(coin.balanceOf(user1), 0, "User1 should receive 0 coins");
    }

    function test_createTokenAirdrop() public {
        address[] memory airdropRecipients = new address[](4);
        airdropRecipients[0] = user1;
        airdropRecipients[1] = user2;
        airdropRecipients[2] = user3;
        airdropRecipients[3] = user4;

        vm.startPrank(user1);
        address coinAddress = factory.newCoinAirdrop{ value: 2 ether }(coinName, coinSymbol, airdropRecipients);
        vm.stopPrank();

        // Check token balance
        assertEq(
            FJC(coinAddress).balanceOf(user1), 235_977_527.380591821538147077 ether, "User1 should receive 40m tokens"
        );
        assertEq(FJC(coinAddress).balanceOf(user2), 40_000_000 ether, "User2 should receive 40m tokens");
        assertEq(FJC(coinAddress).balanceOf(user3), 40_000_000 ether, "User3 should receive 40m tokens");
        assertEq(FJC(coinAddress).balanceOf(user4), 40_000_000 ether, "User4 should receive 40m tokens");
    }

    function test_createTokenAirdropOverPayEth() public {
        address[] memory airdropRecipients = new address[](4);
        airdropRecipients[0] = user1;
        airdropRecipients[1] = user2;
        airdropRecipients[2] = user3;
        airdropRecipients[3] = user4;

        vm.startPrank(user1);
        factory.newCoinAirdrop{ value: 4 ether }(coinName, coinSymbol, airdropRecipients);
        vm.stopPrank();

        assertEq(address(factory).balance, 3.96 ether, "Factory should have 3.96 ether");
        assertEq(feeTo.balance, 0.04 ether, "Fee recipient should have 0.04 ether");
        assertEq(user1.balance, 96 ether, "User1 should have 96 ether");
    }

    function test_createTokenAirdropNoRecipients() public {
        vm.startPrank(user1);
        factory.newCoinAirdrop(coinName, coinSymbol, new address[](0));
        vm.stopPrank();

        assertEq(address(factory).balance, 0 ether, "Factory should have 0 ether");
        assertEq(feeTo.balance, 0 ether, "Fee recipient should have 0 ether");
        assertEq(user1.balance, 100 ether, "User1 should have 100 ether");
    }

    function test_notGraduateToken() public {
        vm.startPrank(user1);
        address coinAddress = factory.newCoin(coinName, coinSymbol);
        factory.buy{ value: 0.99 ether }(coinAddress);
        vm.stopPrank();

        (,,,,, bool isGraduated) = factory.coins(coinAddress);
        // check if token is not graduated
        assertEq(isGraduated, false, "Token should not be graduated");
    }

    function test_graduateTokenOnTenETH() public {
        vm.startPrank(user1);
        address coinAddress = factory.newCoin(coinName, coinSymbol);
        factory.buy{ value: 10 ether }(coinAddress);
        vm.stopPrank();

        (,,,,, bool isGraduated) = factory.coins(coinAddress);
        // check if token is not graduated
        assertEq(isGraduated, true, "Token should be graduated");
    }

    function test_graduateToken() public {
        vm.startPrank(user1);
        address coinAddress = factory.newCoin(coinName, coinSymbol);
        factory.buy{ value: 12 ether }(coinAddress);
        vm.stopPrank();

        (,,,,, bool isGraduated) = factory.coins(coinAddress);
        // check if token is graduated
        assertEq(isGraduated, true, "Token should be graduated");

        // assert that 0xdead owns the LP tokens
        address wethAddress = address(uniswapV2Router.WETH());
        address lpTokenAddress = uniswapV2Factory.getPair(coinAddress, wethAddress);
        assertEq(
            IERC20(lpTokenAddress).balanceOf(address(factory)), 0, "LP tokens should not be owned by factory address"
        );
        assertEq(
            IERC20(lpTokenAddress).balanceOf(address(0x000000000000000000000000000000000000dEaD)),
            43127717305695649348467,
            "LP tokens should be owned by 0xdead address"
        );

        // Assert
        // - it takes 5 ETH tdo get to graduate to Aerodrome
        // - 0.1 ETH is paid to Token Creator (Creator Incentive)
        // - 0.5 ETH is paid to FastJPEGFactory owner (Migration Fee)
    }

    function test_consecutiveBuys() public {
        vm.startPrank(user1);
        address coinAddress = factory.newCoin(coinName, coinSymbol);
        factory.buy{ value: 1 ether }(coinAddress);
        factory.buy{ value: 1 ether }(coinAddress);
        factory.buy{ value: 1 ether }(coinAddress);
        factory.buy{ value: 1 ether }(coinAddress);
        factory.buy{ value: 1 ether }(coinAddress);
        factory.buy{ value: 1 ether }(coinAddress);
        factory.buy{ value: 1 ether }(coinAddress);
        factory.buy{ value: 1 ether }(coinAddress);
        factory.buy{ value: 1 ether }(coinAddress);
        factory.buy{ value: 1 ether }(coinAddress);
        vm.stopPrank();

        assertEq(
            FJC(coinAddress).balanceOf(user1),
            795_989_949.685295963787583854 ether,
            "User1 should have 795_989_949 ether"
        ); // 357_770_876
    }
}
