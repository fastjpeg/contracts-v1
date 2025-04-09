// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test, console } from "forge-std/Test.sol";
import { FastJPEGFactory, FJC, FastJPEGFactoryError } from "../src/FastJPEGFactory.sol";
import { IERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IUniswapV2Factory } from "../lib/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import { IUniswapV2Router02 } from "../lib/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import { WETH } from "../lib/solmate/src/tokens/WETH.sol";
import { AnvilFastJPEGFactory } from "../script/AnvilFastJPEGFactory.s.sol";

contract FastJPEGFactoryAirdropTest is Test {
    IUniswapV2Factory uniswapV2Factory = IUniswapV2Factory(0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6);
    IUniswapV2Router02 uniswapV2Router = IUniswapV2Router02(0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24);
    WETH weth = WETH(payable(0x4200000000000000000000000000000000000006));
    FastJPEGFactory factory;
    string public coinName = "Fast JPEG coin";
    string public coinSymbol = "FJPG";
    uint256 public metadataHash = 0x8d97ddbf14571f9c4d122267efd3359632909d858bea23f0ee1a539493bed805;

    address public EXPECT_COIN_ADDRESS = 0xffD4505B3452Dc22f8473616d50503bA9E1710Ac;
    uint256 EXPECT_ONE_ETH_COIN_AMOUNT = 251_714_123.560836371277948843 ether;
    address public EXPECT_AIRDROP_COIN_ADDRESS = 0x8d2C17FAd02B7bb64139109c6533b7C2b9CADb81;
    uint256 EXPECT_AIRDROP_COIN_AMOUNT = 80_000_000.0 ether;
    // Test users
    address public owner;
    address public creator;
    address public feeTo;
    address public user1;
    address public user2;
    address public user3;
    address public user4;
    address public user5;

    // Events
    event NewCoin(address indexed coin, address indexed creator);
    event SwapCoin(address indexed sender, address indexed coin, uint256 amountA, uint256 amountB, uint256 volume);
    event AirdropCoin(address indexed coin, address indexed recipient, uint256 amount);
    event GraduateCoin(address indexed coin, address indexed pool);

    function setUp() public {
        // Initialize test users with different addresses
        owner = address(this);
        creator = vm.addr(1);
        feeTo = vm.addr(2);
        user1 = vm.addr(3);
        user2 = vm.addr(4);
        user3 = vm.addr(5);
        user4 = vm.addr(6);
        user5 = vm.addr(7);

        AnvilFastJPEGFactory script = new AnvilFastJPEGFactory();
        script.test();

        // Deploy FastJPEGFactory
        factory = new FastJPEGFactory(address(uniswapV2Factory), address(uniswapV2Router), feeTo);

        // Fund the test users with some ETH for transactions
        vm.deal(creator, 100 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);
        vm.deal(user4, 100 ether);
        vm.deal(user5, 100 ether);
        vm.deal(feeTo, 0 ether);
    }

    function test_createCoinWithoutAirdrop() public {
        vm.startPrank(creator);
        address coinAddress = factory.newCoin{ value: 1 ether }("TestCoin", "TEST", metadataHash);
        vm.stopPrank();

        (
            address coinAddress_,
            address creator_,
            address poolAddress_,
            uint256 ethReserve_,
            uint256 coinsSold_,
            uint256 metadataHash_,
            bool isGraduated_
        ) = factory.coins(coinAddress);
        FastJPEGFactory.CoinInfo memory coinInfo = FastJPEGFactory.CoinInfo({
            coinAddress: coinAddress_,
            creator: creator_,
            poolAddress: poolAddress_,
            ethReserve: ethReserve_,
            coinsSold: coinsSold_,
            metadataHash: metadataHash_,
            isGraduated: isGraduated_
        });
        assertEq(coinInfo.creator, creator);
        assertEq(coinInfo.isGraduated, false);

        FJC coin = FJC(coinAddress);
        // Creator should receive all minted coins
        uint256 creatorBalance = coin.balanceOf(creator);
        uint256 totalSupply = coin.totalSupply();
        assertEq(creatorBalance, totalSupply);
    }

    function test_createCoinWithAirdrop() public {
        address[] memory recipients = new address[](3);
        recipients[0] = user1;
        recipients[1] = user2;
        recipients[2] = user3;

        uint256 airdropPercentage = 1000; // 10%
        uint256 expectedAirdropAmount = (factory.UNDERGRADUATE_SUPPLY() * airdropPercentage) / factory.BPS_DENOMINATOR();

        vm.startPrank(creator);
        address coinAddress =
            factory.newCoinAirdrop{ value: 2 ether }("AirdropCoin", "AIR", recipients, airdropPercentage, metadataHash);
        vm.stopPrank();

        FJC coin = FJC(coinAddress);

        // Each recipient should have received equal share of the airdrop
        uint256 expectedPerRecipient = expectedAirdropAmount / recipients.length;
        assertApproxEqRel(coin.balanceOf(user1), expectedPerRecipient, 0.01e18); // Allow for small rounding differences
        assertApproxEqRel(coin.balanceOf(user2), expectedPerRecipient, 0.01e18);
        assertApproxEqRel(coin.balanceOf(user3), expectedPerRecipient, 0.01e18);

        // Creator should also have received coins
        assertTrue(coin.balanceOf(creator) > 0, "Creator should have received coins");
    }

    function test_maxAirdropPercentage() public {
        address[] memory recipients = new address[](2);
        recipients[0] = user1;
        recipients[1] = user2;

        // Use the maximum allowed percentage (80%)
        uint256 airdropPercentage = factory.MAX_AIRDROP_PERCENTAGE_BPS();

        vm.startPrank(creator);
        address coinAddress = factory.newCoinAirdrop{ value: 3 ether }(
            "MaxAirdropCoin", "MAX", recipients, airdropPercentage, metadataHash
        );
        vm.stopPrank();

        FJC coin = FJC(coinAddress);

        // Both recipients should have received equal share of the max airdrop amount
        assertEq(coin.balanceOf(user1), 211731406926901808227072752);
        assertEq(coin.balanceOf(user2), 211731406926901808227072752);
    }

    function test_airdropPercentageTooHigh() public {
        address[] memory recipients = new address[](1);
        recipients[0] = user1;

        // Try to use a percentage higher than the maximum (80%)
        uint256 airdropPercentage = factory.MAX_AIRDROP_PERCENTAGE_BPS() + 1;

        vm.startPrank(creator);
        vm.expectRevert(abi.encodeWithSelector(FastJPEGFactoryError.AirdropPercentageTooHigh.selector));
        factory.newCoinAirdrop{ value: 2 ether }("TooHighCoin", "HIGH", recipients, airdropPercentage, metadataHash);
        vm.stopPrank();
    }

    function test_airdropWithZeroPercentage() public {
        address[] memory recipients = new address[](2);
        recipients[0] = user1;
        recipients[1] = user2;

        // Use 0% for airdrop
        uint256 airdropPercentage = 0;

        vm.startPrank(creator);
        address coinAddress = factory.newCoinAirdrop{ value: 2 ether }(
            "ZeroAirdropCoin", "ZERO", recipients, airdropPercentage, metadataHash
        );
        vm.stopPrank();

        FJC coin = FJC(coinAddress);

        // Recipients should have received zero coins even though they were specified
        assertEq(coin.balanceOf(user1), 0);
        assertEq(coin.balanceOf(user2), 0);

        // Creator should have received all coins
        assertTrue(coin.balanceOf(creator) > 0, "Creator should have received coins");
    }

    function test_airdropWithEmptyRecipients() public {
        address[] memory recipients = new address[](0);

        // Use 50% for airdrop, but with empty recipients array
        uint256 airdropPercentage = 5000;

        vm.startPrank(creator);
        vm.expectRevert(abi.encodeWithSelector(FastJPEGFactoryError.AirdropPercentageMustBeZero.selector));
        factory.newCoinAirdrop{ value: 2 ether }(
            "EmptyAirdropCoin", "EMPTY", recipients, airdropPercentage, metadataHash
        );
        vm.stopPrank();
    }

    function test_airdropDistribution() public {
        // Test with varying number of recipients to ensure distribution is even
        address[] memory recipients = new address[](5);
        recipients[0] = user1;
        recipients[1] = user2;
        recipients[2] = user3;
        recipients[3] = user4;
        recipients[4] = user5;

        uint256 airdropPercentage = 2500; // 25%

        vm.startPrank(creator);
        address coinAddress = factory.newCoinAirdrop{ value: 2 ether }(
            "DistributionCoin", "DIST", recipients, airdropPercentage, metadataHash
        );
        vm.stopPrank();

        FJC coin = FJC(coinAddress);

        uint256 expectedAirdropAmount = (factory.UNDERGRADUATE_SUPPLY() * airdropPercentage) / factory.BPS_DENOMINATOR();
        uint256 expectedPerRecipient = expectedAirdropAmount / recipients.length;

        // Check that each recipient got the same amount
        assertApproxEqRel(coin.balanceOf(recipients[0]), expectedPerRecipient, 0.01e18);
        assertApproxEqRel(coin.balanceOf(recipients[1]), expectedPerRecipient, 0.01e18);
        assertApproxEqRel(coin.balanceOf(recipients[2]), expectedPerRecipient, 0.01e18);
        assertApproxEqRel(coin.balanceOf(recipients[3]), expectedPerRecipient, 0.01e18);
        assertApproxEqRel(coin.balanceOf(recipients[4]), expectedPerRecipient, 0.01e18);
    }

    function test_airdropWithMultipleBuys() public {
        // Test what happens when users buy after initial airdrop
        address[] memory recipients = new address[](1);
        recipients[0] = user1;

        uint256 airdropPercentage = 3000; // 30%

        vm.startPrank(creator);
        address coinAddress = factory.newCoinAirdrop{ value: 1 ether }(
            "MultiBuyCoin", "MULTI", recipients, airdropPercentage, metadataHash
        );
        vm.stopPrank();

        // Record user1's balance after airdrop
        FJC coin = FJC(coinAddress);
        uint256 user1BalanceAfterAirdrop = coin.balanceOf(user1);
        assertTrue(user1BalanceAfterAirdrop > 0, "User1 should have received airdrop");

        // Another user buys some coins
        vm.startPrank(user2);
        factory.buy{ value: 1 ether }(coinAddress, 0);
        vm.stopPrank();

        // User1's balance should not have changed after another user bought coins
        assertEq(coin.balanceOf(user1), user1BalanceAfterAirdrop);
        // User2 should have received some coins
        assertTrue(coin.balanceOf(user2) > 0, "User2 should have received coins from buying");
    }

    function test_airdropDistributionAllRecipientsSell() public {
        address[] memory recipients = new address[](5);
        recipients[0] = user1;
        recipients[1] = user2;
        recipients[2] = user3;
        recipients[3] = user4;
        recipients[4] = user5;

        uint256 airdropPercentage = 2500; // 25%

        vm.startPrank(creator);
        address coinAddress = factory.newCoinAirdrop{ value: 2 ether }(
            "DistributionCoin", "DIST", recipients, airdropPercentage, metadataHash
        );
        vm.stopPrank();

        FJC coin = FJC(coinAddress);

        uint256 expectedAirdropAmount = (factory.UNDERGRADUATE_SUPPLY() * airdropPercentage) / factory.BPS_DENOMINATOR();
        uint256 expectedPerRecipient = expectedAirdropAmount / recipients.length;

        // Check that each recipient got the same amount
        assertApproxEqRel(coin.balanceOf(recipients[0]), expectedPerRecipient, 0.01e18);
        assertApproxEqRel(coin.balanceOf(recipients[1]), expectedPerRecipient, 0.01e18);
        assertApproxEqRel(coin.balanceOf(recipients[2]), expectedPerRecipient, 0.01e18);
        assertApproxEqRel(coin.balanceOf(recipients[3]), expectedPerRecipient, 0.01e18);
        assertApproxEqRel(coin.balanceOf(recipients[4]), expectedPerRecipient, 0.01e18);

        vm.startPrank(creator);
        uint256 creatorBalance = coin.balanceOf(creator);
        factory.sell(coinAddress, creatorBalance, 0);
        assertEq(coin.balanceOf(creator), 0);
        vm.stopPrank();

        vm.startPrank(user1);
        uint256 user1Balance = coin.balanceOf(user1);
        factory.sell(coinAddress, user1Balance, 0);
        assertEq(coin.balanceOf(user1), 0);

        vm.stopPrank();
        vm.startPrank(user2);
        uint256 user2Balance = coin.balanceOf(user2);
        factory.sell(coinAddress, user2Balance, 0);
        assertEq(coin.balanceOf(user2), 0);
        vm.stopPrank();

        vm.startPrank(user3);
        uint256 user3Balance = coin.balanceOf(user3);
        factory.sell(coinAddress, user3Balance, 0);
        assertEq(coin.balanceOf(user3), 0);
        vm.stopPrank();

        vm.startPrank(user4);
        uint256 user4Balance = coin.balanceOf(user4);
        factory.sell(coinAddress, user4Balance, 0);
        assertEq(coin.balanceOf(user4), 0);
        vm.stopPrank();

        vm.startPrank(user5);
        uint256 user5Balance = coin.balanceOf(user5);
        factory.sell(coinAddress, user5Balance, 0);
        assertEq(coin.balanceOf(user5), 0);
        vm.stopPrank();

        (,,, uint256 ethReserve, uint256 coinsSold,,) = factory.coins(coinAddress);
        assertEq(coinsSold, 0, "Coins sold should be 0");
        assertEq(ethReserve, 1 wei, "ETH reserve should be 1 wei");

        assertEq(feeTo.balance, 0.039799999999999999 ether, "FeeTo should have 0.039799999999999999 ether");
    }
}
