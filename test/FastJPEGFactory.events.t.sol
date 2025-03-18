// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Test, console } from "forge-std/Test.sol";
import { FastJPEGFactory, FastJPEGToken } from "../src/FastJPEGFactory.sol";
import { IERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IUniswapV2Factory } from "../lib/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import { IUniswapV2Router02 } from "../lib/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import { WETH } from "../lib/solmate/src/tokens/WETH.sol";
import { AnvilFastJPEGFactory } from "../script/AnvilFastJPEGFactory.s.sol";

contract FastJPEGFactoryTest is Test {
    IUniswapV2Factory factory = IUniswapV2Factory(0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6);
    IUniswapV2Router02 router = IUniswapV2Router02(0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24);
    WETH weth = WETH(payable(0x4200000000000000000000000000000000000006));
    FastJPEGFactory fastJpegFactory;
    string public tokenName = "Fast JPEG Token";
    string public tokenSymbol = "FJPG";

    address public EXPECT_TOKEN_ADDRESS = 0xffD4505B3452Dc22f8473616d50503bA9E1710Ac;
    uint256 EXPECT_ONE_ETH_TOKEN_AMOUNT = 251_714_123.560836371277948843 ether;
    address public EXPECT_AIRDROP_TOKEN_ADDRESS = 0x8d2C17FAd02B7bb64139109c6533b7C2b9CADb81;
    uint256 EXPECT_AIRDROP_TOKEN_AMOUNT = 80_000_000.0 ether;
    // Test users
    address public fastJpegOwner;
    address public user1;
    address public user2;
    address public user3;
    address public user4;
    address public feeTo;

    // Events
    event TokenCreated(address indexed token, address indexed creator);
    event TokensBought(address indexed token, address indexed buyer, uint256 amount, uint256 ethSpent);
    event TokensSold(address indexed token, address indexed seller, uint256 amount, uint256 ethReceived);
    event AirdropIssued(address indexed token, address indexed recipient, uint256 amount);
    event TokenGraduated(address indexed token);

    function setUp() public {
        // Initialize test users with different addresses
        fastJpegOwner = address(this);
        user1 = vm.addr(1);
        user2 = vm.addr(2);
        user3 = vm.addr(3);
        user4 = vm.addr(4);
        feeTo = vm.addr(5);

        AnvilFastJPEGFactory script = new AnvilFastJPEGFactory();
        script.test();

        // Deploy FastJPEGFactory
        fastJpegFactory = new FastJPEGFactory(address(factory), address(router), feeTo);

        // Fund the test users with some ETH for transactions
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);
        vm.deal(user4, 100 ether);
        vm.deal(feeTo, 0 ether);
    }

    function test_TokenCreated_Event() public {
        vm.startPrank(user1);

        // Expect TokenCreated event
        vm.expectEmit(true, true, false, false);
        emit TokenCreated(EXPECT_TOKEN_ADDRESS, user1); // address(0) is a placeholder
        fastJpegFactory.createToken(tokenName, tokenSymbol);

        vm.stopPrank();
    }

    function test_TokensBought_Event() public {
        vm.startPrank(user1);

        // Create token first
        address tokenAddress = fastJpegFactory.createToken(tokenName, tokenSymbol);

        // Expect TokensBought event
        vm.expectEmit(true, true, false, false);
        emit TokensBought(tokenAddress, user1, EXPECT_ONE_ETH_TOKEN_AMOUNT, 1 ether); // Amount will be calculated by contract
        fastJpegFactory.buy{ value: 1 ether }(tokenAddress);

        vm.stopPrank();
    }

    function test_TokensSold_Event() public {
        vm.startPrank(user1);

        // Create and buy tokens first
        address tokenAddress = fastJpegFactory.createToken(tokenName, tokenSymbol);
        fastJpegFactory.buy{ value: 1 ether }(tokenAddress);

        // Get token instance
        FastJPEGToken token = FastJPEGToken(tokenAddress);

        // Approve factory to sell tokens
        token.approve(address(fastJpegFactory), token.balanceOf(user1));

        // Expect TokensSold event
        vm.expectEmit(true, true, false, false);
        emit TokensSold(tokenAddress, user1, token.balanceOf(user1), 0.9801 ether); // ETH amount will be calculated by contract
        fastJpegFactory.sell(tokenAddress, token.balanceOf(user1));

        vm.stopPrank();
    }

    function test_AirdropIssued_Event() public {
        vm.startPrank(user1);

        // Create array of recipients
        address[] memory recipients = new address[](2);
        recipients[0] = user2;
        recipients[1] = user3;

        // Verify AirdropIssued events for each recipient
        vm.expectEmit(true, true, false, false);
        emit AirdropIssued(EXPECT_TOKEN_ADDRESS, user2, EXPECT_AIRDROP_TOKEN_AMOUNT); // Amount will be calculated by contract

        vm.expectEmit(true, true, false, false);
        emit AirdropIssued(EXPECT_TOKEN_ADDRESS, user3, EXPECT_AIRDROP_TOKEN_AMOUNT); // Amount will be calculated by contract

        // Create token with airdrop
        fastJpegFactory.createTokenAirdrop{ value: 2 ether }(tokenName, tokenSymbol, recipients);

        vm.stopPrank();
    }

    function test_TokenGraduated_Event() public {
        vm.startPrank(user1);

        // Create token
        address tokenAddress = fastJpegFactory.createToken(tokenName, tokenSymbol);

        // Expect TokenGraduated event
        vm.expectEmit(true, false, false, false);
        emit TokenGraduated(EXPECT_TOKEN_ADDRESS);

        // Buy enough tokens to trigger graduation (10 ETH)
        fastJpegFactory.buy{ value: 10 ether }(tokenAddress);

        vm.stopPrank();
    }

    function test_AllEventsInSequence() public {
        vm.startPrank(user1);

        // 1. Create token
        vm.expectEmit(true, true, false, false);
        emit TokenCreated(EXPECT_TOKEN_ADDRESS, user1);
        address tokenAddress = fastJpegFactory.createToken(tokenName, tokenSymbol);

        // 2. Buy tokens
        vm.expectEmit(true, true, false, false);
        emit TokensBought(tokenAddress, user1, EXPECT_ONE_ETH_TOKEN_AMOUNT, 1 ether);
        fastJpegFactory.buy{ value: 1 ether }(tokenAddress);

        // 3. Sell tokens
        FastJPEGToken token = FastJPEGToken(tokenAddress);
        token.approve(address(fastJpegFactory), token.balanceOf(user1));
        vm.expectEmit(true, true, false, false);
        emit TokensSold(tokenAddress, user1, token.balanceOf(user1), 0.9801 ether);
        fastJpegFactory.sell(tokenAddress, token.balanceOf(user1));

        // 4. Create token with airdrop
        address[] memory recipients = new address[](2);
        recipients[0] = user2;
        recipients[1] = user3;
        vm.expectEmit(true, true, false, false);
        emit AirdropIssued(EXPECT_AIRDROP_TOKEN_ADDRESS, user2, EXPECT_AIRDROP_TOKEN_AMOUNT);
        vm.expectEmit(true, true, false, false);
        emit AirdropIssued(EXPECT_AIRDROP_TOKEN_ADDRESS, user3, EXPECT_AIRDROP_TOKEN_AMOUNT);
        fastJpegFactory.createTokenAirdrop{ value: 2 ether }(tokenName, tokenSymbol, recipients);

        // 5. Graduate token

        vm.expectEmit(true, false, false, false);
        emit TokenGraduated(EXPECT_AIRDROP_TOKEN_ADDRESS);

        fastJpegFactory.buy{ value: 10 ether }(EXPECT_AIRDROP_TOKEN_ADDRESS);

        vm.stopPrank();
    }
}
