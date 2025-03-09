// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@aerodrome/contracts/interfaces/factories/IPoolFactory.sol";
import "@aerodrome/contracts/interfaces/IRouter.sol";
import "@aerodrome/contracts/interfaces/IPool.sol";

// Custom ERC20 implementation that can be instantiated
contract FastJPEGToken is ERC20 {
    constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }
}

contract FastJPEGLauncher is Ownable {
    // Constants
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 * 10**18; // 1 billion tokens
    uint256 public constant BONDING_SUPPLY = 800_000_000 * 10**18; // 800 million tokens
    uint256 public constant AERODROME_THRESHOLD = 5 ether;
    uint256 public constant KING_OF_HILL_THRESHOLD = 2.5 ether;
    uint256 public constant MAX_AIRDROP_ETH = 1 ether;
    uint256 public constant PROMOTION_FEE = 0.5 ether;
    uint256 public constant LIQUIDITY_LOCK = 0.5 ether;
    uint256 public constant CURVE_EXPONENT = 2; // Quadratic curve

    // Aerodrome contracts
    IPoolFactory public immutable poolFactory;
    IRouter public immutable router;

    // State variables
    struct TokenInfo {
        address tokenAddress;
        uint256 ethCollected;
        uint256 tokensRemaining;
        bool isPromoted;
        mapping(address => uint256) contributions;
        uint256 airdropEthUsed;
        address poolAddress;
    }

    mapping(address => TokenInfo) public launchedTokens;
    
    // Events
    event TokenLaunched(address indexed token, address indexed creator);
    event TokensBought(address indexed token, address indexed buyer, uint256 amount, uint256 ethSpent);
    event TokenPromoted(address indexed token, address indexed pool);
    event AirdropClaimed(address indexed token, address indexed recipient, uint256 amount);
    event LiquidityLocked(address indexed token, address indexed pool, uint256 tokenAmount, uint256 ethAmount, uint256 liquidity);

    constructor(address _poolFactory, address _router) Ownable(msg.sender) {
        poolFactory = IPoolFactory(_poolFactory);
        router = IRouter(_router);
    }

    /**
     * @dev Launches a new token with the specified name and symbol
     * @param name The name of the token
     * @param symbol The symbol of the token
     */
    function launchToken(string memory name, string memory symbol) external returns (address) {
        // Deploy new token
        FastJPEGToken newToken = new FastJPEGToken(name, symbol, TOTAL_SUPPLY);
        
        // Initialize token info
        TokenInfo storage tokenInfo = launchedTokens[address(newToken)];
        tokenInfo.tokenAddress = address(newToken);
        tokenInfo.tokensRemaining = BONDING_SUPPLY;
        tokenInfo.ethCollected = 0;
        tokenInfo.isPromoted = false;
        tokenInfo.airdropEthUsed = 0;

        emit TokenLaunched(address(newToken), msg.sender);
        return address(newToken);
    }

    /**
     * @dev Calculates the price for buying tokens based on the bonding curve
     * @param tokenAddress The address of the token
     * @param amount The amount of tokens to buy
     * @return The price in ETH
     */
    function calculatePrice(address tokenAddress, uint256 amount) public view returns (uint256) {
        TokenInfo storage tokenInfo = launchedTokens[tokenAddress];
        require(tokenInfo.tokenAddress != address(0), "Token not found");
        require(amount <= tokenInfo.tokensRemaining, "Insufficient tokens remaining");

        // Calculate price based on quadratic bonding curve
        // Price = (current_eth + new_eth)^2 - current_eth^2
        uint256 currentEth = tokenInfo.ethCollected;
        uint256 soldTokens = BONDING_SUPPLY - tokenInfo.tokensRemaining;
        uint256 newEth = (((soldTokens + amount) * currentEth) / soldTokens) ** CURVE_EXPONENT;
        
        return newEth - (currentEth ** CURVE_EXPONENT);
    }

    /**
     * @dev Buys tokens from the bonding curve
     * @param tokenAddress The address of the token to buy
     * @param amount The amount of tokens to buy
     */
    function buyTokens(address tokenAddress, uint256 amount) external payable {
        TokenInfo storage tokenInfo = launchedTokens[tokenAddress];
        require(tokenInfo.tokenAddress != address(0), "Token not found");
        require(amount <= tokenInfo.tokensRemaining, "Insufficient tokens remaining");

        uint256 price = calculatePrice(tokenAddress, amount);
        require(msg.value >= price, "Insufficient ETH sent");

        // Update state
        tokenInfo.tokensRemaining -= amount;
        tokenInfo.ethCollected += price;
        tokenInfo.contributions[msg.sender] += amount;

        // Transfer tokens
        ERC20(tokenAddress).transfer(msg.sender, amount);

        // Refund excess ETH
        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }

        emit TokensBought(tokenAddress, msg.sender, amount, price);
    }

    /**
     * @dev Promotes a token to Aerodrome if requirements are met
     * @param tokenAddress The address of the token to promote
     */
    function promoteToken(address tokenAddress) external {
        TokenInfo storage tokenInfo = launchedTokens[tokenAddress];
        require(tokenInfo.tokenAddress != address(0), "Token not found");
        require(!tokenInfo.isPromoted, "Token already promoted");
        require(tokenInfo.ethCollected >= AERODROME_THRESHOLD, "Insufficient ETH collected");

        tokenInfo.isPromoted = true;

        // Transfer promotion fee to contract owner
        payable(owner()).transfer(PROMOTION_FEE);

        // Create pool on Aerodrome
        address poolAddress = poolFactory.createPool(tokenAddress, address(0), false); // false for volatile pool
        tokenInfo.poolAddress = poolAddress;

        // Calculate liquidity amounts
        uint256 tokenAmount = TOTAL_SUPPLY / 100; // 1% of total supply for initial liquidity
        uint256 ethAmount = LIQUIDITY_LOCK;

        // Approve router to spend tokens
        ERC20(tokenAddress).approve(address(router), tokenAmount);

        // Add liquidity to Aerodrome
        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = router.addLiquidityETH{value: ethAmount}(
            tokenAddress,
            false, // volatile pool
            tokenAmount,
            tokenAmount, // min token amount
            ethAmount, // min ETH amount
            address(this), // liquidity tokens are locked in the contract
            block.timestamp + 1800 // 30 minutes deadline
        );

        emit TokenPromoted(tokenAddress, poolAddress);
        emit LiquidityLocked(tokenAddress, poolAddress, amountToken, amountETH, liquidity);
    }

    /**
     * @dev Claims airdrop tokens for the caller
     * @param tokenAddress The address of the token
     * @param amount The amount of tokens to claim
     */
    function claimAirdrop(address tokenAddress, uint256 amount) external {
        TokenInfo storage tokenInfo = launchedTokens[tokenAddress];
        require(tokenInfo.tokenAddress != address(0), "Token not found");
        require(tokenInfo.airdropEthUsed < MAX_AIRDROP_ETH, "Airdrop limit reached");

        uint256 price = calculatePrice(tokenAddress, amount);
        require(tokenInfo.airdropEthUsed + price <= MAX_AIRDROP_ETH, "Exceeds airdrop limit");

        // Update state
        tokenInfo.tokensRemaining -= amount;
        tokenInfo.airdropEthUsed += price;
        tokenInfo.contributions[msg.sender] += amount;

        // Transfer tokens
        ERC20(tokenAddress).transfer(msg.sender, amount);

        emit AirdropClaimed(tokenAddress, msg.sender, amount);
    }

    // Function to receive ETH
    receive() external payable {}
} 