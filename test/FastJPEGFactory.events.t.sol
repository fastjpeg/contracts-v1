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
    string public coinName = "Fast JPEG coin";
    string public coinSymbol = "FJPG";

    address public EXPECT_COIN_ADDRESS = 0xffD4505B3452Dc22f8473616d50503bA9E1710Ac;
    uint256 EXPECT_ONE_ETH_COIN_AMOUNT = 251_714_123.560836371277948843 ether;
    address public EXPECT_AIRDROP_COIN_ADDRESS = 0x8d2C17FAd02B7bb64139109c6533b7C2b9CADb81;
    uint256 EXPECT_AIRDROP_COIN_AMOUNT = 80_000_000.0 ether;
    // Test users
    address public owner;
    address public user1;
    address public user2;
    address public user3;
    address public user4;
    address public feeTo;

    // Events
    event NewCoin(address indexed coin, address indexed creator);
    event BuyCoin(address indexed coin, address indexed buyer, uint256 amount, uint256 ethSpent);
    event SellCoin(address indexed coin, address indexed seller, uint256 amount, uint256 ethReceived);
    event AirdropCoin(address indexed coin, address indexed recipient, uint256 amount);
    event GraduateCoin(address indexed coin);

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

    function test_NewCoin_Event() public {
        vm.startPrank(user1);

        // Expect coinCreated event
        vm.expectEmit(true, true, false, false);
        emit NewCoin(EXPECT_COIN_ADDRESS, user1); // address(0) is a placeholder
        factory.newCoin(coinName, coinSymbol);

        vm.stopPrank();
    }

    function test_BuyCoin_Event() public {
        vm.startPrank(user1);

        // Create coin first
        address coinAddress = factory.newCoin(coinName, coinSymbol);

        // Expect coinsBought event
        vm.expectEmit(true, true, false, false);
        emit BuyCoin(coinAddress, user1, EXPECT_ONE_ETH_COIN_AMOUNT, 1 ether); // Amount will be calculated by contract
        factory.buy{ value: 1 ether }(coinAddress);

        vm.stopPrank();
    }

    function test_SellCoin_Event() public {
        vm.startPrank(user1);

        // Create and buy coins first
        address coinAddress = factory.newCoin(coinName, coinSymbol);
        factory.buy{ value: 1 ether }(coinAddress);

        // Get coin instance
        FJC coin = FJC(coinAddress);

        // Approve factory to sell coins
        coin.approve(address(factory), coin.balanceOf(user1));

        // Expect coinsSold event
        vm.expectEmit(true, true, false, false);
        emit SellCoin(coinAddress, user1, coin.balanceOf(user1), 0.9801 ether); // ETH amount will be calculated by contract
        factory.sell(coinAddress, coin.balanceOf(user1));

        vm.stopPrank();
    }

    function test_AirdropCoin_Event() public {
        vm.startPrank(user1);

        // Create array of recipients
        address[] memory recipients = new address[](2);
        recipients[0] = user2;
        recipients[1] = user3;

        // Verify AirdropIssued events for each recipient
        vm.expectEmit(true, true, false, false);
        emit AirdropCoin(EXPECT_COIN_ADDRESS, user2, EXPECT_AIRDROP_COIN_AMOUNT); // Amount will be calculated by contract

        vm.expectEmit(true, true, false, false);
        emit AirdropCoin(EXPECT_COIN_ADDRESS, user3, EXPECT_AIRDROP_COIN_AMOUNT); // Amount will be calculated by contract

        // Create coin with airdrop
        factory.newCoinAirdrop{ value: 2 ether }(coinName, coinSymbol, recipients);

        vm.stopPrank();
    }

    function test_GraduateCoin_Event() public {
        vm.startPrank(user1);

        // Create coin
        address coinAddress = factory.newCoin(coinName, coinSymbol);

        // Expect coinGraduated event
        vm.expectEmit(true, false, false, false);
        emit GraduateCoin(EXPECT_COIN_ADDRESS);

        // Buy enough coins to trigger graduation (10 ETH)
        factory.buy{ value: 10 ether }(coinAddress);

        vm.stopPrank();
    }

    function test_AllEventsInSequence() public {
        vm.startPrank(user1);

        // 1. Create coin
        vm.expectEmit(true, true, false, false);
        emit NewCoin(EXPECT_COIN_ADDRESS, user1);
        address coinAddress = factory.newCoin(coinName, coinSymbol);

        // 2. Buy coins
        vm.expectEmit(true, true, false, false);
        emit BuyCoin(coinAddress, user1, EXPECT_ONE_ETH_COIN_AMOUNT, 1 ether);
        factory.buy{ value: 1 ether }(coinAddress);

        // 3. Sell coins
        FJC coin = FJC(coinAddress);
        coin.approve(address(factory), coin.balanceOf(user1));
        vm.expectEmit(true, true, false, false);
        emit SellCoin(coinAddress, user1, coin.balanceOf(user1), 0.9801 ether);
        factory.sell(coinAddress, coin.balanceOf(user1));

        // 4. Create coin with airdrop
        address[] memory recipients = new address[](2);
        recipients[0] = user2;
        recipients[1] = user3;
        vm.expectEmit(true, true, false, false);
        emit AirdropCoin(EXPECT_AIRDROP_COIN_ADDRESS, user2, EXPECT_AIRDROP_COIN_AMOUNT);
        vm.expectEmit(true, true, false, false);
        emit AirdropCoin(EXPECT_AIRDROP_COIN_ADDRESS, user3, EXPECT_AIRDROP_COIN_AMOUNT);
        factory.newCoinAirdrop{ value: 2 ether }(coinName, coinSymbol, recipients);

        // 5. Graduate coin

        vm.expectEmit(true, false, false, false);
        emit GraduateCoin(EXPECT_AIRDROP_COIN_ADDRESS);

        factory.buy{ value: 10 ether }(EXPECT_AIRDROP_COIN_ADDRESS);

        vm.stopPrank();
    }
}
