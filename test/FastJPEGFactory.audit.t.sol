// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test, console } from "forge-std/Test.sol";
import { FastJPEGFactory, FJC } from "../src/FastJPEGFactory.sol";
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
        creator = vm.addr(1);
        user1 = vm.addr(2);
        user2 = vm.addr(3);
        user3 = vm.addr(4);
        user4 = vm.addr(5);
        feeTo = vm.addr(6);

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
        vm.deal(feeTo, 0 ether);
    }

    function test_anyoneCanBurnOtherPersonsCoins() public {
        vm.startPrank(user1);
        address coinAddress = factory.newCoin{ value: 1 ether }("TestCoin", "TEST", metadataHash);
        vm.stopPrank();

        FJC coin = FJC(coinAddress);

        uint256 user1Balance = 244486369570289904451196604;
        assertEq(coin.balanceOf(user1), user1Balance, "User should have 244486369570289904451196604 FJPGCoins");

        vm.startPrank(user2);

        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), user2));

        coin.burn(user1, user1Balance);
        vm.stopPrank();

        assertEq(coin.balanceOf(user1), user1Balance, "User should have 244486369570289904451196604 FJPGCoins");
    }
}
