// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {console} from "forge-std/console.sol";
import { FastJPEGToken } from "./FastJPEGToken.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import {IUniswapV2Factory} from "../lib/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "../lib/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";


contract FastJPEGFactory is Ownable {
    uint256 public constant UNDERGRADUATE_SUPPLY = 800_000_000 * 10**18; // 800M tokens with 18 decimals
    uint256 public constant GRADUATE_SUPPLY = 200_000_000 * 10**18; // 200M tokens with 18 decimals
    uint256 public constant AIRDROP_SUPPLY = 160_000_000 * 10**18; // 160 million tokens

    uint256 public constant GRADUATE_ETH = 5 ether; // 5 ETH to graduate token

    uint256 public constant UNDERGRADUATE_FEE_BPS = 100; // 1% fee
    uint256 public constant BPS_DENOMINATOR = 10000; // 100% = 10000 BPS

    uint256 public constant GRADUATION_FEE = 0.1 ether; // 0.1 ETH to graduate token
    uint256 public constant CREATOR_REWARD_FEE = 0.05 ether; // 0.05 ETH to creator

    uint256 public constant AIRDROP_ETH = 1 ether; // 1 ETH to airdrop
    
    // Aerodrome contracts
    IUniswapV2Factory public immutable factory;
    IUniswapV2Router02 public immutable router;

    // State variables
    struct TokenInfo {
        address tokenAddress;
        address poolAddress;
        uint256 reserveBalance;
        uint256 tokensSold;
        bool isGraduated;
    }

    mapping(address => TokenInfo) public tokens;
    
    // Events
    event TokenLaunched(address indexed token, address indexed creator);
    event TokensBought(address indexed token, address indexed buyer, uint256 amount, uint256 ethSpent);
    event TokensSold(address indexed token, address indexed seller, uint256 amount, uint256 ethReceived);
    event TokenPromoted(address indexed token, address indexed pool);
    event AirdropIssued(address indexed token, address indexed recipient, uint256 amount);
    event LiquidityLocked(address indexed token, address indexed pool, uint256 tokenAmount, uint256 ethAmount, uint256 liquidity);

    constructor(address _factory, address _router) Ownable() {
        factory = IUniswapV2Factory(_factory);
        router = IUniswapV2Router02(_router);
        _transferOwnership(msg.sender);
    }
    /**
     * @dev Launches a new token with the specified name and symbol without airdrop recipients
     * @param name The name of the token
     * @param symbol The symbol of the token
     */
    function createToken(string memory name, string memory symbol) public payable returns (address) {
        address[] memory emptyRecipients = new address[](0);
        return createTokenAirdrop(name, symbol, emptyRecipients);
    }

    /**
     * @dev Launches a new token with the specified name and symbol
     * @param name The name of the token
     * @param symbol The symbol of the token
     * @param airdropRecipients Optional array of addresses to airdrop tokens to (if msg.value >= 1 ETH)
     */
    function createTokenAirdrop(string memory name, string memory symbol, address[] memory airdropRecipients) public payable returns (address) {
        // Deploy new token - only mint bonding supply to contract initially
        FastJPEGToken newToken = new FastJPEGToken(name, symbol);
        
        // Initialize token info
        TokenInfo storage tokenInfo = tokens[address(newToken)];
        tokenInfo.tokenAddress = address(newToken);
        tokenInfo.reserveBalance = 0;
        tokenInfo.tokensSold = 0;
        tokenInfo.isGraduated = false;

        // If user sent 1 ETH and provided recipients, perform airdrop
        if (msg.value >= AIRDROP_ETH && airdropRecipients.length > 0) {
            uint256 fee = (AIRDROP_ETH * UNDERGRADUATE_FEE_BPS) / BPS_DENOMINATOR;
            
            // Send fee to contract owner
            payable(owner()).transfer(fee);
            
            // Distribute tokens evenly among recipients by minting directly to them
            uint256 tokensPerRecipient = AIRDROP_SUPPLY / airdropRecipients.length;
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
     * @dev Buy tokens using ETH
     */
    function buy(address tokenAddress) external payable {
        TokenInfo storage tokenInfo = _tokenInfo(tokenAddress);
        require(!tokenInfo.isGraduated, "Token been graduated, buys disabled");
        require(msg.value > 0, "Must send ETH");
        
        require(tokenInfo.tokensSold < UNDERGRADUATE_SUPPLY, "Max supply reached");

        uint256 purchaseEthBeforeFee = msg.value;

        // Calculate 1% fee
        uint256 fee = (purchaseEthBeforeFee * UNDERGRADUATE_FEE_BPS) / BPS_DENOMINATOR;
        uint256 purchaseEth = purchaseEthBeforeFee - fee;

        // Calculate tokens to mint based on the bonding curve
        uint256 tokensToMint = calculatePurchaseAmount(purchaseEth, tokenInfo.tokensSold);
        
        // Ensure we don't exceed max supply
        if (tokenInfo.tokensSold + tokensToMint > UNDERGRADUATE_SUPPLY) {
            tokensToMint = UNDERGRADUATE_SUPPLY - tokenInfo.tokensSold;
            
            // Calculate actual ETH needed and refund excess
            purchaseEthBeforeFee = calculatePriceForTokens(tokensToMint, tokenInfo.tokensSold);
            if (msg.value > purchaseEthBeforeFee) {
                payable(msg.sender).transfer(msg.value - purchaseEthBeforeFee);
            }
        }
        
        // Send fee to owner
        payable(owner()).transfer(fee);
        
        // Update reserve balance with the ETH used (after fee)
        tokenInfo.reserveBalance += purchaseEth;
        
        // Mint tokens to the buyer
        FastJPEGToken(tokenAddress).mint(msg.sender, tokensToMint);

        // Update total tokens sold
        tokenInfo.tokensSold += tokensToMint;
    }

    /**
     * @dev Sell tokens to get ETH back
     * @param tokenAmount Amount of tokens to sell
     */
    function sell(address tokenAddress, uint256 tokenAmount) external {
        TokenInfo storage tokenInfo = _tokenInfo(tokenAddress);
        require(!tokenInfo.isGraduated, "Token graduated, sells disabled");
        require(tokenAmount > 0, "Amount must be positive");
        require(FastJPEGToken(tokenAddress).balanceOf(msg.sender) >= tokenAmount, "Insufficient balance");
        
        uint256 currentSupply = FastJPEGToken(tokenAddress).totalSupply();
        
        // Calculate ETH to return based on the bonding curve
        uint256 returnEthBeforeFee = calculateSaleReturn(tokenAmount, currentSupply);

        // Calculate 1% fee
        uint256 fee = (returnEthBeforeFee * UNDERGRADUATE_FEE_BPS) / BPS_DENOMINATOR;
        uint256 returnEth = returnEthBeforeFee - fee;

        require(returnEth <= tokenInfo.reserveBalance, "Insufficient reserve");

        // Burn tokens
        FastJPEGToken(tokenAddress).burn(msg.sender, tokenAmount);
        
        // Update reserve balance
        tokenInfo.reserveBalance -= returnEth;
        
        // Send fee to owner
        payable(owner()).transfer(fee);
        
        // Send ETH to seller (after fee)
        payable(msg.sender).transfer(returnEth);

        // Update total tokens sold
        tokenInfo.tokensSold -= tokenAmount;
    }

        /**
     * @dev Calculate how many tokens to mint for a given ETH amount
     * @param ethAmount Amount of ETH sent
     * @param currentSupply Current total supply
     * @return Amount of tokens to mint
     */
    function calculatePurchaseAmount(uint256 ethAmount, uint256 currentSupply) public pure returns (uint256) {
        // For a quadratic curve: T = sqrt((E * UNDERGRADUATE_SUPPLY²) / GRADUATE_ETH + currentSupply²) - currentSupply

        // Calculate: (E * UNDERGRADUATE_SUPPLY²) / GRADUATE_ETH
        uint256 numerator = ethAmount * (UNDERGRADUATE_SUPPLY ** 2);
        uint256 term1 = numerator / GRADUATE_ETH;
        
        // Add currentSupply²
        uint256 term2 = currentSupply ** 2;
        uint256 sumUnderRoot = term1 + term2;
        
        // Take square root and subtract currentSupply
        uint256 newTotalSupply = Math.sqrt(sumUnderRoot);
        
        return newTotalSupply > currentSupply ? newTotalSupply - currentSupply : 0;
    }

    /**
     * @dev Calculate how much ETH is needed to purchase a specific token amount
     * @param tokenAmount Amount of tokens to purchase
     * @param currentSupply Current total supply
     * @return Amount of ETH needed
     */
    function calculatePriceForTokens(uint256 tokenAmount, uint256 currentSupply) public pure returns (uint256) {
        // For a quadratic curve: E = (GRADUATE_ETH * ((currentSupply + T)² - currentSupply²)) / UNDERGRADUATE_SUPPLY²
        
        uint256 newSupply = currentSupply + tokenAmount;
        
        // Calculate: (currentSupply + T)² - currentSupply²
        uint256 newSupplySquared = newSupply ** 2;
        uint256 currentSupplySquared = currentSupply ** 2;
        uint256 supplyDeltaSquared = newSupplySquared - currentSupplySquared;
        
        // Calculate: (GRADUATE_ETH * supplyDeltaSquared) / UNDERGRADUATE_SUPPLY²
        uint256 numerator = GRADUATE_ETH * supplyDeltaSquared;
        uint256 denominator = UNDERGRADUATE_SUPPLY ** 2;
        
        return numerator / denominator;
    }
    
        /**
     * @dev Calculate how much ETH to return when selling tokens
     * @param tokenAmount Amount of tokens to sell
     * @param currentSupply Current total supply
     * @return Amount of ETH to return
     */
    function calculateSaleReturn(uint256 tokenAmount, uint256 currentSupply) public pure returns (uint256) {
        // Uses the same formula as calculatePriceForTokens but in reverse
        return calculatePriceForTokens(tokenAmount, currentSupply - tokenAmount);
    }
    
    /**
     * @dev Internal function to graduate a token to Aerodrome
     * @param tokenAddress The address of the token to graduate
     */
    function _graduateToken(address tokenAddress) internal {
        TokenInfo storage tokenInfo = tokens[tokenAddress];
        // require(!tokenInfo.isGraudated, "Token already graduated");
        // tokenInfo.isGraudated = true;

        // // Transfer launch fee to contract owner
        // payable(owner()).transfer(LAUNCH_FEE);

        // // Create pool on Aerodrome
        // address poolAddress = poolFactory.createPool(tokenAddress, address(0), false); // false for volatile pool
        // tokenInfo.poolAddress = poolAddress;

        // // Calculate liquidity amounts
        // uint256 tokenAmount = TOTAL_SUPPLY / 100; // 1% of total supply for initial liquidity
        // uint256 ethAmount = LIQUIDITY_LOCK;

        // // Approve router to spend tokens
        // ERC20(tokenAddress).approve(address(router), tokenAmount);

        // // Add liquidity to Aerodrome
        // (uint256 amountToken, uint256 amountETH, uint256 liquidity) = router.addLiquidityETH{value: ethAmount}(
        //     tokenAddress,
        //     false, // volatile pool
        //     tokenAmount,
        //     tokenAmount, // min token amount
        //     ethAmount, // min ETH amount
        //     address(this), // liquidity tokens are locked in the contract
        //     block.timestamp + 1800 // 30 minutes deadline
        // );

        // emit TokenPromoted(tokenAddress, poolAddress);
        // emit LiquidityLocked(tokenAddress, poolAddress, amountToken, amountETH, liquidity);
    }

    function _tokenInfo(address tokenAddress) internal view returns (TokenInfo storage) {
        TokenInfo storage tokenInfo = tokens[tokenAddress];
        require(tokenInfo.tokenAddress != address(0), "Token not found");
        return tokenInfo;
    }

    // Function to receive ETH
    receive() external payable {}
}