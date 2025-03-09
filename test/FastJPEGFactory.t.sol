// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/FastJPEGFactory.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../lib/contracts/contracts/factories/PoolFactory.sol";
import "../lib/contracts/contracts/Router.sol";

abstract contract MockPoolFactory is PoolFactory {
    address public lastPool;

    function createPool(address tokenA, address tokenB, bool stable) external virtual override returns (address pool) {
        lastPool = address(this);
        return lastPool;
    }
}

abstract contract MockRouter is Router {
    function addLiquidityETH(
        address token,
        bool stable,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable virtual override returns (uint amountToken, uint amountETH, uint liquidity) {
        return (amountTokenDesired, msg.value, amountTokenDesired * msg.value);
    }
}

contract FastJPEGFactoryTest is Test {
    FastJPEGFactory public factory;
    MockPoolFactory public poolFactory;
    MockRouter public router;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        poolFactory = new MockPoolFactory();
        router = new MockRouter();
        factory = new FastJPEGFactory(address(poolFactory), address(router));
        owner = factory.owner();
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }

    function test_TokenLaunch() public {
        address token = factory.launchToken("Test Token", "TEST");
        
        // Verify token supply and initial state
        assertEq(ERC20(token).totalSupply(), 1_000_000_000 * 10**18, "Incorrect total supply");
        
        FastJPEGFactory.TokenInfo memory info = factory.launchedTokens(token);
        assertEq(info.tokensRemaining, 800_000_000 * 10**18, "Incorrect bonding supply");
        assertEq(info.ethCollected, 0, "Initial ETH collected should be 0");
        assertFalse(info.isPromoted, "Should not be promoted initially");
    }

    function test_BondingCurvePrice() public {
        address token = factory.launchToken("Test Token", "TEST");
        
        // Test initial price
        uint256 smallAmount = 1000 * 10**18;
        uint256 initialPrice = factory.calculatePrice(token, smallAmount);
        assertGt(initialPrice, 0, "Initial price should be greater than 0");
        
        // Test price increase
        vm.startPrank(user1);
        factory.buyTokens{value: initialPrice}(token, smallAmount);
        vm.stopPrank();
        
        uint256 laterPrice = factory.calculatePrice(token, smallAmount);
        assertGt(laterPrice, initialPrice, "Price should increase exponentially");
    }

    function test_AirdropMechanics() public {
        address token = factory.launchToken("Test Token", "TEST");
        uint256 airdropAmount = 1000 * 10**18;
        
        vm.startPrank(user1);
        uint256 initialBalance = ERC20(token).balanceOf(user1);
        factory.claimAirdrop(token, airdropAmount);
        uint256 finalBalance = ERC20(token).balanceOf(user1);
        
        // Verify 1% fee was taken
        uint256 expectedNet = (airdropAmount * (10000 - factory.AIRDROP_FEE_BPS())) / 10000;
        assertEq(finalBalance - initialBalance, expectedNet, "Incorrect airdrop amount after fee");
        
        // Verify FastJPEGLauncher received fee
        uint256 launcherBalance = ERC20(token).balanceOf(owner);
        assertEq(launcherBalance, airdropAmount * factory.AIRDROP_FEE_BPS() / 10000, "Incorrect launcher fee");
        vm.stopPrank();
    }

    function test_TradingFees() public {
        address token = factory.launchToken("Test Token", "TEST");
        uint256 amount = 1000 * 10**18;
        uint256 price = factory.calculatePrice(token, amount);
        
        uint256 initialOwnerBalance = owner.balance;
        
        vm.startPrank(user1);
        factory.buyTokens{value: price}(token, amount);
        vm.stopPrank();
        
        // Verify 1% trading fee was sent to FastJPEGLauncher
        uint256 expectedFee = (price * factory.TRADE_FEE_BPS()) / 10000;
        assertEq(owner.balance - initialOwnerBalance, expectedFee, "Incorrect trading fee");
    }

    function test_AerodromePromotion() public {
        address token = factory.launchToken("Test Token", "TEST");
        
        // Buy enough tokens to reach Aerodrome threshold
        vm.startPrank(user1);
        uint256 amount = 100000 * 10**18;
        uint256 totalSpent = 0;
        
        while (totalSpent < factory.AERODROME_THRESHOLD()) {
            uint256 price = factory.calculatePrice(token, amount);
            factory.buyTokens{value: price}(token, amount);
            totalSpent += price;
        }
        vm.stopPrank();
        
        // Verify promotion occurred
        FastJPEGFactory.TokenInfo memory info = factory.launchedTokens(token);
        assertTrue(info.isPromoted, "Token should be promoted");
        assertEq(info.poolAddress, address(poolFactory), "Pool should be created");
        
        // Verify fees
        uint256 expectedPromotionFee = factory.PROMOTION_FEE();
        uint256 expectedLiquidityLock = factory.LIQUIDITY_LOCK();
        
        // Check promotion fee was paid
        assertEq(owner.balance, expectedPromotionFee, "Incorrect promotion fee");
    }

    function test_KingOfHillThreshold() public {
        address token = factory.launchToken("Test Token", "TEST");
        
        vm.startPrank(user1);
        uint256 amount = 50000 * 10**18;
        uint256 totalSpent = 0;
        
        while (totalSpent < factory.KING_OF_HILL_THRESHOLD()) {
            uint256 price = factory.calculatePrice(token, amount);
            factory.buyTokens{value: price}(token, amount);
            totalSpent += price;
        }
        vm.stopPrank();
        
        FastJPEGFactory.TokenInfo memory info = factory.launchedTokens(token);
        assertGe(info.ethCollected, factory.KING_OF_HILL_THRESHOLD(), "Should reach King of Hill threshold");
    }

    function test_MaxAirdropLimit() public {
        address token = factory.launchToken("Test Token", "TEST");
        
        vm.startPrank(user1);
        uint256 amount = 10000 * 10**18;
        uint256 totalAirdropped = 0;
        
        // Try to exceed airdrop limit
        vm.expectRevert("Airdrop limit reached");
        while (totalAirdropped <= factory.MAX_AIRDROP_ETH()) {
            factory.claimAirdrop(token, amount);
            totalAirdropped += factory.calculatePrice(token, amount);
        }
        vm.stopPrank();
    }

    function test_BondingVaultPurchase() public {
        address token = factory.launchToken("Test Token", "TEST");
        uint256 amount = 1000 * 10**18;
        uint256 price = factory.calculatePrice(token, amount);
        
        vm.startPrank(user1);
        uint256 initialBalance = ERC20(token).balanceOf(user1);
        factory.buyTokens{value: price}(token, amount);
        uint256 finalBalance = ERC20(token).balanceOf(user1);
        
        assertEq(finalBalance - initialBalance, amount, "Incorrect tokens received from bonding vault");
        vm.stopPrank();
    }

    receive() external payable {}
} 