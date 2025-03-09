// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {console} from "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../lib/contracts/contracts/interfaces/factories/IPoolFactory.sol";
import "../lib/contracts/contracts/interfaces/IRouter.sol";
import "../lib/contracts/contracts/interfaces/IPool.sol";

// Custom ERC20 implementation that can be instantiated
contract FastJPEGToken is ERC20 {
    constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }
    
    // Added function to allow minting tokens to specific addresses
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract FastJPEGFactory is Ownable {
    // Constants
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 * 10**18; // 1 billion tokens
    uint256 public constant BONDING_SUPPLY = 800_000_000 * 10**18; // 800 million tokens
    uint256 public constant AIRDROP_SUPPLY = 160_000_000 * 10**18; // 160 million tokens
    uint256 public constant AERODROME_THRESHOLD = 5 ether;
    uint256 public constant KING_OF_HILL_THRESHOLD = 3 ether;
    uint256 public constant MAX_AIRDROP_ETH = 1 ether;
    uint256 public constant PROMOTION_FEE = 0.5 ether;
    uint256 public constant LIQUIDITY_LOCK = 0.8 ether;
    uint256 public constant TRADE_FEE_BPS = 100; // 1% = 100 BPS
    uint256 public constant AIRDROP_FEE_BPS = 100; // 1% = 100 BPS
    uint256 public constant BPS_DENOMINATOR = 10000; // 100% = 10000 BPS
    uint256 public constant BASE_PRICE = 0.0001 ether;
    uint256 public constant PRICE_MULTIPLIER = 115;

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
    event TokensSold(address indexed token, address indexed seller, uint256 amount, uint256 ethReceived);
    event TokenPromoted(address indexed token, address indexed pool);
    event AirdropIssued(address indexed token, address indexed recipient, uint256 amount);
    event LiquidityLocked(address indexed token, address indexed pool, uint256 tokenAmount, uint256 ethAmount, uint256 liquidity);

    constructor(address _poolFactory, address _router) Ownable() {
        // require(_poolFactory != address(0), "Invalid pool factory");
        // require(_router != address(0), "Invalid router");
        poolFactory = IPoolFactory(_poolFactory);
        router = IRouter(_router);
        _transferOwnership(msg.sender);
    }

    /**
     * @dev Launches a new token with the specified name and symbol without airdrop recipients
     * @param name The name of the token
     * @param symbol The symbol of the token
     */
    function launchToken(string memory name, string memory symbol) public payable returns (address) {
        address[] memory emptyRecipients = new address[](0);
        return launchTokenAirdrop(name, symbol, emptyRecipients);
    }

    /**
     * @dev Launches a new token with the specified name and symbol
     * @param name The name of the token
     * @param symbol The symbol of the token
     * @param airdropRecipients Optional array of addresses to airdrop tokens to (if msg.value >= 1 ETH)
     */
    function launchTokenAirdrop(string memory name, string memory symbol, address[] memory airdropRecipients) public payable returns (address) {
        // Deploy new token - only mint bonding supply to contract initially
        FastJPEGToken newToken = new FastJPEGToken(name, symbol, BONDING_SUPPLY);
        
        // Initialize token info
        TokenInfo storage tokenInfo = launchedTokens[address(newToken)];
        tokenInfo.tokenAddress = address(newToken);
        tokenInfo.tokensRemaining = BONDING_SUPPLY;
        tokenInfo.ethCollected = 0;
        tokenInfo.isPromoted = false;
        tokenInfo.airdropEthUsed = 0;


        // If user sent 1 ETH and provided recipients, perform airdrop
        if (msg.value >= 1 ether && airdropRecipients.length > 0) {
            uint256 airdropAmount = 1 ether;
            
            // Calculate fee for airdrop (using TRADE_FEE_BPS)
            uint256 airdropFee = (airdropAmount * TRADE_FEE_BPS) / BPS_DENOMINATOR;
            uint256 netAirdropAmount = airdropAmount - airdropFee;
            
            // Send fee to contract owner
            payable(owner()).transfer(airdropFee);
            
            // Record the net amount used for airdrop
            tokenInfo.airdropEthUsed = netAirdropAmount;
            
            // Calculate tokens to distribute from the airdrop supply (AIRDROP_SUPPLY)
            uint256 tokensToDistribute = AIRDROP_SUPPLY;
            
            // Distribute tokens evenly among recipients by minting directly to them
            uint256 tokensPerRecipient = tokensToDistribute / airdropRecipients.length;
            for (uint256 i = 0; i < airdropRecipients.length; i++) {
                require(airdropRecipients[i] != address(0), "Invalid recipient address");
                newToken.mint(airdropRecipients[i], tokensPerRecipient);
                emit AirdropIssued(address(newToken), airdropRecipients[i], tokensPerRecipient);
            }
            
            // Refund excess ETH if any
            if (msg.value > 1 ether) {
                payable(msg.sender).transfer(msg.value - 1 ether);
            }
        } else if (msg.value > 0) {
            // Refund any ETH if no airdrop performed
            payable(msg.sender).transfer(msg.value);
        }

        emit TokenLaunched(address(newToken), msg.sender);
        return address(newToken);
    }

    /**
     * @dev Calculates the price for buying tokens based on the bonding curve
     * @param tokenAddress The address of the token
     * @param amount The amount of tokens to buy
     * @return The price in ETH
     */
    function calculateBuyPrice(address tokenAddress, uint256 amount) public view returns (uint256) {
        TokenInfo storage tokenInfo = launchedTokens[tokenAddress];
        require(tokenInfo.tokenAddress != address(0), "Token not found");
        require(amount <= tokenInfo.tokensRemaining, "Insufficient tokens remaining");

        // Calculate price based on exponential bonding curve
        // Price = BASE_PRICE * (PRICE_MULTIPLIER/100)^(soldTokens/1e18)
        uint256 soldTokens = BONDING_SUPPLY - tokenInfo.tokensRemaining;
        uint256 newSoldTokens = soldTokens + amount;
        
        uint256 currentPrice = BASE_PRICE * (PRICE_MULTIPLIER ** (soldTokens / 1e18)) / (100 ** (soldTokens / 1e18));
        uint256 newPrice = BASE_PRICE * (PRICE_MULTIPLIER ** (newSoldTokens / 1e18)) / (100 ** (newSoldTokens / 1e18));
        return ((currentPrice + newPrice) * amount) / 2;
    }

    /**
     * @dev Calculates the sell price for tokens based on the bonding curve
     * @param tokenAddress The address of the token
     * @param amount The amount of tokens to sell
     * @return The amount of ETH to receive
     */
    function calculateSellPrice(address tokenAddress, uint256 amount) public view returns (uint256) {
        TokenInfo storage tokenInfo = launchedTokens[tokenAddress];
        require(tokenInfo.tokenAddress != address(0), "Token not found");
        
        uint256 soldTokens = BONDING_SUPPLY - tokenInfo.tokensRemaining;
        require(amount <= soldTokens, "Cannot sell more than bought");
        
        uint256 newSoldTokens = soldTokens - amount;
        
        uint256 currentPrice = BASE_PRICE * (PRICE_MULTIPLIER ** (soldTokens / 1e18)) / (100 ** (soldTokens / 1e18));
        uint256 newPrice = BASE_PRICE * (PRICE_MULTIPLIER ** (newSoldTokens / 1e18)) / (100 ** (newSoldTokens / 1e18));
        return ((currentPrice + newPrice) * amount) / 2;
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

        uint256 price = calculateBuyPrice(tokenAddress, amount);
        require(msg.value >= price, "Insufficient ETH sent");

        // Calculate trade fee using BPS
        uint256 tradeFee = (price * TRADE_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netPrice = price - tradeFee;

        // Update state
        tokenInfo.tokensRemaining -= amount;
        tokenInfo.ethCollected += netPrice;
        tokenInfo.contributions[msg.sender] += amount;

        // Transfer tokens
        ERC20(tokenAddress).transfer(msg.sender, amount);

        // Transfer trade fee to FastJPEGLauncher
        payable(owner()).transfer(tradeFee);

        // Refund excess ETH
        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }

        emit TokensBought(tokenAddress, msg.sender, amount, price);
        
        // Auto-promote token if threshold is reached and not already promoted
        if (tokenInfo.ethCollected >= AERODROME_THRESHOLD && !tokenInfo.isPromoted) {
            _promoteToken(tokenAddress);
        }
    }

    /**
     * @dev Sells tokens back to the bonding curve
     * @param tokenAddress The address of the token to sell
     * @param amount The amount of tokens to sell
     */
    function sellTokens(address tokenAddress, uint256 amount) external {
        TokenInfo storage tokenInfo = launchedTokens[tokenAddress];
        require(tokenInfo.tokenAddress != address(0), "Token not found");
        require(tokenInfo.contributions[msg.sender] >= amount, "Insufficient tokens owned");
        
        uint256 sellPrice = calculateSellPrice(tokenAddress, amount);
        
        // Calculate trade fee using BPS
        uint256 tradeFee = (sellPrice * TRADE_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netSellPrice = sellPrice - tradeFee;
        
        // Update state
        tokenInfo.tokensRemaining += amount;
        tokenInfo.ethCollected -= netSellPrice;
        tokenInfo.contributions[msg.sender] -= amount;
        
        // Transfer tokens from user to contract
        require(ERC20(tokenAddress).transferFrom(msg.sender, address(this), amount), "Token transfer failed");
        
        // Transfer ETH to user
        payable(msg.sender).transfer(netSellPrice);
        
        // Transfer trade fee to owner
        payable(owner()).transfer(tradeFee);
        
        emit TokensSold(tokenAddress, msg.sender, amount, netSellPrice);
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

        _promoteToken(tokenAddress);
    }
    
    /**
     * @dev Internal function to promote a token to Aerodrome
     * @param tokenAddress The address of the token to promote
     */
    function _promoteToken(address tokenAddress) internal {
        TokenInfo storage tokenInfo = launchedTokens[tokenAddress];
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

    // Function to receive ETH
    receive() external payable {}
} 