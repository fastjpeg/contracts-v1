// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Test, console } from "forge-std/Test.sol";
import { FastJPEGFactory, FJC, FastJPEGFactoryError } from "../src/FastJPEGFactory.sol";
import { IERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IUniswapV2Factory } from "../lib/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import { IUniswapV2Router02 } from "../lib/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import { IUniswapV2Pair } from "../lib/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import { WETH } from "../lib/solmate/src/tokens/WETH.sol";
import { AnvilFastJPEGFactory } from "../script/AnvilFastJPEGFactory.s.sol";

/**
 * @title FastJPEGFactoryTest
 * @dev Test contract for FastJPEGFactory functionality
 */
contract FastJPEGFactoryTest is Test {
    IUniswapV2Factory uniswapV2Factory = IUniswapV2Factory(0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6);
    IUniswapV2Router02 uniswapV2Router = IUniswapV2Router02(0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24);
    WETH weth = WETH(payable(0x4200000000000000000000000000000000000006));
    FastJPEGFactory factory;
    string public coinName = "Fast JPEG Coin";
    string public coinSymbol = "FJPG";
    uint256 public testMetadataHash = 0x8d97ddbf14571f9c4d122267efd3359632909d858bea23f0ee1a539493bed805;

    // Test users
    address public owner;
    address public user1;
    address public user2;
    address public user3;
    address public user4;
    address public feeTo;

    /**
     * @dev Setup function executed before each test
     */
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

    /**
     * @dev Tests that the factory's fee recipient is properly set
     */
    function test_factory() public view {
        assertNotEq(factory.feeTo(), address(0), "Factory feeTo should not be zero");
    }

    /**
     * @dev Tests that the router's WETH address is correctly configured
     */
    function test_router() public view {
        assertEq(address(uniswapV2Router.WETH()), address(weth), "Wrapped WETH should be correct");
    }

    /**
     * @dev Tests the coin purchase amount calculation for various ETH inputs
     */
    function test_calculatePurchaseAmount() public view {
        uint256 coinsToMint2Ether = factory.calculatePurchaseAmount(2 ether, 0);
        assertEq(coinsToMint2Ether, 347_497_794.210455493463372314 ether);

        uint256 coinsToMint4Ether = factory.calculatePurchaseAmount(4 ether, 0);
        assertEq(coinsToMint4Ether, 491_436_093.467160947542732555 ether);

        uint256 coinsToMint6Ether = factory.calculatePurchaseAmount(6 ether, 0);
        assertEq(coinsToMint6Ether, 601_883_835.090622969968018676 ether);

        uint256 coinsToMint8Ether = factory.calculatePurchaseAmount(8 ether, 0);
        assertEq(coinsToMint8Ether, 694_995_588.420910986926744629 ether);

        uint256 coinsToMint10Ether = factory.calculatePurchaseAmount(10 ether, 0);
        assertEq(coinsToMint10Ether, 777_028_689.885811344588480714 ether);

        uint256 coinsToMint106Ether = factory.calculatePurchaseAmount(10.6 ether, 0);
        assertEq(coinsToMint106Ether, 800_000_000 ether);
    }

    /**
     * @dev Tests the ETH return calculation when selling coins
     */
    function test_calculateSaleReturn() public view {
        uint256 priceFor100Coins = factory.calculateSaleReturn(100_000_000 * 1e18, 400_000_000 * 1e18);
        assertEq(priceFor100Coins, 1.159375000000000000 ether);

        uint256 priceFor200Coins = factory.calculateSaleReturn(200_000_000 * 1e18, 400_000_000 * 1e18);
        assertEq(priceFor200Coins, 1.987500000000000000 ether);

        uint256 priceFor300Coins = factory.calculateSaleReturn(800_000_000 * 1e18, 800_000_000 * 1e18);
        assertEq(priceFor300Coins, 10.6 ether);
    }

    /**
     * @dev Tests buying coins with ETH
     */
    function test_buy() public {
        vm.startPrank(user1);
        address coinAddress = factory.newCoin(coinName, coinSymbol, testMetadataHash);
        factory.buy{ value: 2 ether }(coinAddress, 0);
        vm.stopPrank();

        FJC coin = FJC(coinAddress);

        assertEq(
            coin.balanceOf(user1), 345755939661664749132741421, "User should have 345755939661664749132741421 FJPGCoins"
        );
        assertEq(coin.balanceOf(owner), 0, "Owner should have 0 FJPGCoins");
        assertEq(address(factory).balance, 1.98 ether, "Factory should have 1.98 ether");
        assertEq(coin.balanceOf(feeTo), 0, "Fee recipient should have 0 FJPGCoins");
        assertEq(feeTo.balance, 0.02 ether, "Fee recipient should have 0.02 ether");
    }

    /**
     * @dev Tests selling a portion of coins for ETH
     */
    function test_sell() public {
        vm.startPrank(user1);
        address coinAddress = factory.newCoin(coinName, coinSymbol, testMetadataHash);
        factory.buy{ value: 2 ether }(coinAddress, 0);
        factory.sell(coinAddress, 100_000_000 * 1e18, 0.4801 ether);
        vm.stopPrank();

        FJC coin = FJC(coinAddress);

        assertEq(
            coin.balanceOf(user1), 245755939661664749132741421, "User should have 245755939661664749132741421 FJPGCoins"
        );
        assertEq(coin.balanceOf(owner), 0, "Owner should have 0 FJPGCoins");
        assertEq(address(factory).balance, 1000308449870735519, "Factory should have 1000308449870735519");
        assertEq(coin.balanceOf(feeTo), 0, "Fee recipient should have 0 FJPGCoins");
        assertEq(feeTo.balance, 29796915501292644, "Fee recipient should have 29796915501292644");
    }

    /**
     * @dev Tests selling all coins for ETH
     */
    function testSellAll() public {
        vm.startPrank(user1);
        address coinAddress = factory.newCoin(coinName, coinSymbol, testMetadataHash);
        factory.buy{ value: 1 ether }(coinAddress, 0);

        uint256 coinBalance = FJC(coinAddress).balanceOf(user1);

        factory.sell(coinAddress, coinBalance, 0.9801 ether);
        vm.stopPrank();

        FJC coin = FJC(coinAddress);

        assertEq(coin.balanceOf(user1), 0, "User should have 0 FJPGCoins");
        assertEq(coin.balanceOf(owner), 0, "Owner should have 0 FJPGCoins");
        assertEq(address(factory).balance, 1, "Factory should have 1 wei");
        assertEq(coin.balanceOf(feeTo), 0, "Fee recipient should have 0 FJPGCoins");
        assertEq(feeTo.balance, 0.019899999999999999 ether, "Fee recipient should have  0.019899999999999999 ether");
    }

    /**
     * @dev Tests token creation and initial state
     */
    function test_createToken() public {
        // Impersonate user1
        vm.prank(user1);
        address coinAddress = factory.newCoin(coinName, coinSymbol, testMetadataHash);

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
            uint256 metadataHash,
            bool isGraduated
        ) = factory.coins(coinAddress);

        // Verify token info in the factory
        assertEq(storedCoinAddress, coinAddress, "Stored coin address should match");
        assertEq(creator, user1, "Creator should match");
        assertEq(poolAddress, address(0), "Pool address should be zero initially");
        assertEq(ethReserve, 0, "Initial ETH collected should be 0");
        assertEq(coinsSold, 0, "Coins sold should be 0");
        assertEq(metadataHash, testMetadataHash, "Metadata testMetadataHash should match");
        assertFalse(isGraduated, "Coin should not be graduated initially");

        // Check token balance
        assertEq(coin.balanceOf(user1), 0, "User1 should receive 0 coins");
    }

    /**
     * @dev Tests token creation with airdrop to multiple recipients
     */
    function test_createTokenAirdrop() public {
        address[] memory airdropRecipients = new address[](4);
        airdropRecipients[0] = user1;
        airdropRecipients[1] = user2;
        airdropRecipients[2] = user3;
        airdropRecipients[3] = user4;

        vm.startPrank(user1);
        address coinAddress =
            factory.newCoinAirdrop{ value: 2 ether }(coinName, coinSymbol, airdropRecipients, 2500, testMetadataHash);
        vm.stopPrank();

        // Check token balance
        assertEq(
            FJC(coinAddress).balanceOf(user1),
            195755939661664749132741421,
            "User1 should receive 195755939661664749132741421 tokens"
        );
        assertEq(FJC(coinAddress).balanceOf(user2), 50_000_000 ether, "User2 should receive 50m tokens");
        assertEq(FJC(coinAddress).balanceOf(user3), 50_000_000 ether, "User3 should receive 50m tokens");
        assertEq(FJC(coinAddress).balanceOf(user4), 50_000_000 ether, "User4 should receive 50m tokens");
    }

    /**
     * @dev Tests token creation with airdrop when overpaying ETH
     */
    function test_createTokenAirdropOverPayEth() public {
        address[] memory airdropRecipients = new address[](4);
        airdropRecipients[0] = user1;
        airdropRecipients[1] = user2;
        airdropRecipients[2] = user3;
        airdropRecipients[3] = user4;

        vm.startPrank(user1);
        factory.newCoinAirdrop{ value: 4 ether }(coinName, coinSymbol, airdropRecipients, 2000, testMetadataHash);
        vm.stopPrank();

        assertEq(address(factory).balance, 3.96 ether, "Factory should have 3.96 ether");
        assertEq(feeTo.balance, 0.04 ether, "Fee recipient should have 0.04 ether");
        assertEq(user1.balance, 96 ether, "User1 should have 96 ether");
    }

    /**
     * @dev Tests token creation with empty airdrop recipients list
     */
    function test_createTokenAirdropNoRecipients() public {
        vm.startPrank(user1);
        factory.newCoinAirdrop(coinName, coinSymbol, new address[](0), 0, testMetadataHash);
        vm.stopPrank();

        assertEq(address(factory).balance, 0 ether, "Factory should have 0 ether");
        assertEq(feeTo.balance, 0 ether, "Fee recipient should have 0 ether");
        assertEq(user1.balance, 100 ether, "User1 should have 100 ether");
    }

    // expect error if recieptos is 0 and percentage is not 0
    function test_createTokenAirdropNoRecipientsAndPercentageNot0() public {
        vm.expectRevert(abi.encodeWithSelector(FastJPEGFactoryError.AirdropPercentageMustBeZero.selector));
        factory.newCoinAirdrop(coinName, coinSymbol, new address[](0), 1000, testMetadataHash);
    }

    /**
     * @dev Tests token creation with airdrop when airdrop percentage is 100%
     */
    function test_createTokenAirdrop100Percent() public {
        address[] memory airdropRecipients = new address[](4);
        airdropRecipients[0] = user1;
        airdropRecipients[1] = user2;
        airdropRecipients[2] = user3;
        airdropRecipients[3] = user4;

        vm.startPrank(user1);
        factory.newCoinAirdrop(coinName, coinSymbol, airdropRecipients, 10000, testMetadataHash);
        vm.stopPrank();

        assertEq(address(factory).balance, 0 ether, "Factory should have 0 ether");
        assertEq(feeTo.balance, 0 ether, "Fee recipient should have 0 ether");
        assertEq(user1.balance, 100 ether, "User1 should have 100 ether");
    }

    /**
     * @dev Tests that a token doesn't graduate when ETH threshold isn't met
     */
    function test_notGraduateToken() public {
        vm.startPrank(user1);
        address coinAddress = factory.newCoin(coinName, coinSymbol, testMetadataHash);
        factory.buy{ value: 0.99 ether }(coinAddress, 0);
        vm.stopPrank();

        (,,,,,, bool isGraduated) = factory.coins(coinAddress);
        // check if token is not graduated
        assertEq(isGraduated, false, "Token should not be graduated");
    }

    /**
     * @dev Tests token graduation when exactly 10 ETH is reached
     */
    function test_graduateTokenOnTenETH() public {
        vm.startPrank(user1);
        address coinAddress = factory.newCoin(coinName, coinSymbol, testMetadataHash);
        factory.buy{ value: 10.8 ether }(coinAddress, 0);
        vm.stopPrank();

        (,,,,,, bool isGraduated) = factory.coins(coinAddress);
        // check if token is not graduated
        assertEq(isGraduated, true, "Token should be graduated");
    }

    /**
     * @dev Tests token graduation and LP token distribution
     */
    function test_graduateToken() public {
        vm.startPrank(user1);
        address coinAddress = factory.newCoin(coinName, coinSymbol, testMetadataHash);
        factory.buy{ value: 12 ether }(coinAddress, 0);
        vm.stopPrank();

        (,,,,,, bool isGraduated) = factory.coins(coinAddress);
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
            44721359549995793927183,
            "LP tokens should be owned by 0xdead address"
        );

        // Assert
        // - it takes 5 ETH tdo get to graduate to Aerodrome
        // - 0.1 ETH is paid to Token Creator (Creator Incentive)
        // - 0.5 ETH is paid to FastJPEGFactory owner (Migration Fee)
    }

    function test_graduateToken_VeirfyLiquiityPool() public {
        vm.startPrank(user1);
        address coinAddress = factory.newCoin(coinName, coinSymbol, testMetadataHash);
        factory.buy{ value: 100 ether }(coinAddress, 0);
        vm.stopPrank();

        (,,,,,, bool isGraduated) = factory.coins(coinAddress);
        assertEq(isGraduated, true, "Token should be graduated");

        (,, address poolAddress, uint256 ethReserve, uint256 coinsSold,,) = factory.coins(coinAddress);

        assertEq(ethReserve, 10.6 ether, "ETH reserve should be 10.6 ether");
        assertEq(coinsSold, 800_000_000 ether, "Coins sold should be 800_000_000 ether");

        IUniswapV2Pair pair = IUniswapV2Pair(poolAddress);
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        assertEq(reserve0, 10 ether, "WETH reserve should be 10 ether");
        assertEq(reserve1, 200_000_000 ether, "Coin reserve should be 200_000_000 ether");
    }

    /**
     * @dev Tests multiple consecutive buy operations
     */
    function test_consecutiveBuys() public {
        vm.startPrank(user1);
        address coinAddress = factory.newCoin(coinName, coinSymbol, testMetadataHash);
        factory.buy{ value: 1 ether }(coinAddress, 0);
        factory.buy{ value: 1 ether }(coinAddress, 0);
        factory.buy{ value: 1 ether }(coinAddress, 0);
        factory.buy{ value: 1 ether }(coinAddress, 0);
        factory.buy{ value: 1 ether }(coinAddress, 0);
        factory.buy{ value: 1 ether }(coinAddress, 0);
        factory.buy{ value: 1 ether }(coinAddress, 0);
        factory.buy{ value: 1 ether }(coinAddress, 0);
        factory.buy{ value: 1 ether }(coinAddress, 0);
        factory.buy{ value: 1 ether }(coinAddress, 0);
        vm.stopPrank();

        assertEq(
            FJC(coinAddress).balanceOf(user1),
            773133784707798016160633606,
            "User1 should have 773133784707798016160633606"
        );
    }

    function test_fiveBuysThenSellEverything() public {
        vm.startPrank(user1);
        address coinAddress = factory.newCoin(coinName, coinSymbol, testMetadataHash);
        factory.buy{ value: 1 ether }(coinAddress, 0);
        factory.buy{ value: 1 ether }(coinAddress, 0);
        factory.buy{ value: 1 ether }(coinAddress, 0);
        factory.buy{ value: 1 ether }(coinAddress, 0);
        factory.buy{ value: 1 ether }(coinAddress, 0);

        uint256 coinBalance = FJC(coinAddress).balanceOf(user1);
        console.log("coinBalance", coinBalance);
        factory.sell(coinAddress, coinBalance, 0 ether);
        vm.stopPrank();

        assertEq(FJC(coinAddress).balanceOf(user1), 0 ether, "User1 should have 0 ether");

        // Check that the factory's ETH reserve for this coin is 0
        (,,, uint256 ethReserve, uint256 coinsSold,, bool isGraduated) = factory.coins(coinAddress);
        assertEq(ethReserve, 1 wei, "Factory should have 1 wei reserve for the coin (Jeevans Gift)");
        assertEq(coinsSold, 0, "Factory should have 0 coins sold");
        assertFalse(isGraduated, "Coin should not be graduated");
    }

    function test_CalculateEthToGraduateBeforeFee() public view {
        assertEq(factory.calcualteEthToGraduateBeforeFee(1 ether), 1.010101010101010101 ether);
        assertEq(factory.calcualteEthToGraduateBeforeFee(10.6 ether), 10.707070707070707070 ether);
    }
}
