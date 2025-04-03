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
    uint256 public metadataHash = 0x8d97ddbf14571f9c4d122267efd3359632909d858bea23f0ee1a539493bed805;

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
    event BuyCoin(address indexed sender, address indexed coin, uint256 amountA, uint256 amountB, uint256 volume);
    event SellCoin(address indexed sender, address indexed coin, uint256 amountA, uint256 amountB, uint256 volume);
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

    /**
     * @notice Tests that the NewCoin event is emitted when a new coin is created
     * @dev Verifies the event parameters match the expected coin address and creator
     */
    function test_NewCoin_Event() public {
        vm.startPrank(user1);

        // Expect NewCoin event
        vm.expectEmit(true, true, false, false);
        emit NewCoin(EXPECT_COIN_ADDRESS, user1);
        factory.newCoin(coinName, coinSymbol, metadataHash);

        vm.stopPrank();
    }

    /**
     * @notice Tests that the BuyCoin event is emitted when coins are purchased
     * @dev Verifies the event parameters match the expected coin address, buyer, amount, and ETH spent
     */
    function test_BuyCoin_Event() public {
        vm.startPrank(user1);

        // Create coin first
        address coinAddress = factory.newCoin(coinName, coinSymbol, metadataHash);

        // Expect BuyCoin event
        vm.expectEmit(true, true, false, false);
        emit BuyCoin(user1, coinAddress, 1000, 1 ether, 1 ether);
        factory.buy{ value: 1 ether }(coinAddress, 0);

        vm.stopPrank();
    }


    /**
     * @notice Tests that the BuyCoin event is emitted when coins are purchased
     * @dev Verifies the event parameters match the expected coin address, buyer, amount, and ETH spent
     */
    function test_SellCoin_Event() public {
         vm.startPrank(user1);

        // Create and buy coins first
        address coinAddress = factory.newCoin(coinName, coinSymbol, metadataHash);
        factory.buy{ value: 1 ether }(coinAddress, 0);

        // Get coin instance
        FJC coin = FJC(coinAddress);

        // Approve factory to sell coins
        coin.approve(address(factory), coin.balanceOf(user1));

        // Expect SellCoin event
        vm.expectEmit(true, true, false, false);
        emit SellCoin(user1, coinAddress, 1000, 1 ether, 1 ether);
        factory.sell(coinAddress, coin.balanceOf(user1), 0.9801 ether);

        vm.stopPrank();
    }

    /**
     * @notice Tests that the AirdropCoin event is emitted for each recipient during an airdrop
     * @dev Verifies the event parameters match the expected coin address, recipient, and amount
     */
    function test_AirdropCoin_Event() public {
        vm.startPrank(user1);

        // Create array of recipients
        address[] memory recipients = new address[](2);
        recipients[0] = user2;
        recipients[1] = user3;

        // Verify AirdropCoin events for each recipient
        vm.expectEmit(true, true, false, false);
        emit AirdropCoin(EXPECT_COIN_ADDRESS, user2, EXPECT_AIRDROP_COIN_AMOUNT);

        vm.expectEmit(true, true, false, false);
        emit AirdropCoin(EXPECT_COIN_ADDRESS, user3, EXPECT_AIRDROP_COIN_AMOUNT);

        // Create coin with airdrop
        factory.newCoinAirdrop{ value: 2 ether }(coinName, coinSymbol, recipients, 2000, metadataHash);

        vm.stopPrank();
    }

    /**
     * @notice Tests that the GraduateCoin event is emitted when a coin graduates
     * @dev Verifies the event parameters match the expected coin address
     */
    function test_GraduateCoin_Event() public {
        vm.startPrank(user1);

        // Create coin
        address coinAddress = factory.newCoin(coinName, coinSymbol, metadataHash);

        // Expect GraduateCoin event
        vm.expectEmit(true, false, false, false);
        emit GraduateCoin(EXPECT_COIN_ADDRESS);

        // Buy enough coins to trigger graduation (10 ETH)
        factory.buy{ value: 10 ether }(coinAddress, 0);

        vm.stopPrank();
    }

    /**
     * @notice Tests all events in sequence through a complete lifecycle
     * @dev Creates a coin, buys coins, sells coins, creates a coin with airdrop, and graduates a coin
     */
    function test_AllEventsInSequence() public {
        vm.startPrank(user1);

        // 1. Create coin
        vm.expectEmit(true, true, false, false);
        emit NewCoin(EXPECT_COIN_ADDRESS, user1);
        address coinAddress = factory.newCoin(coinName, coinSymbol, metadataHash);

        // 2. Buy coins
        vm.expectEmit(true, true, false, false);
        emit BuyCoin(user1, coinAddress, EXPECT_ONE_ETH_COIN_AMOUNT, 1 ether, 1 ether);
        factory.buy{ value: 1 ether }(coinAddress, 0);

        // 3. Sell coins
        FJC coin = FJC(coinAddress);
        coin.approve(address(factory), coin.balanceOf(user1));
        vm.expectEmit(true, true, false, false);
        emit SellCoin(user1, coinAddress, coin.balanceOf(user1), 0.9801 ether, 0.9801 ether);
        factory.sell(coinAddress, coin.balanceOf(user1), 0.9801 ether);

        // 4. Create coin with airdrop
        address[] memory recipients = new address[](2);
        recipients[0] = user2;
        recipients[1] = user3;
        vm.expectEmit(true, true, false, false);
        emit AirdropCoin(EXPECT_AIRDROP_COIN_ADDRESS, user2, EXPECT_AIRDROP_COIN_AMOUNT);
        vm.expectEmit(true, true, false, false);
        emit AirdropCoin(EXPECT_AIRDROP_COIN_ADDRESS, user3, EXPECT_AIRDROP_COIN_AMOUNT);
        factory.newCoinAirdrop{ value: 2 ether }(coinName, coinSymbol, recipients, 2000, metadataHash);

        // 5. Graduate coin
        vm.expectEmit(true, false, false, false);
        emit GraduateCoin(EXPECT_AIRDROP_COIN_ADDRESS);
        factory.buy{ value: 10 ether }(EXPECT_AIRDROP_COIN_ADDRESS, 0);

        vm.stopPrank();
    }
}
