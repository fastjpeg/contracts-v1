// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {console} from "forge-std/console.sol";
import { FastJPEGToken } from "./FastJPEGToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../lib/contracts/contracts/interfaces/factories/IPoolFactory.sol";
import "../lib/contracts/contracts/interfaces/IRouter.sol";
import "../lib/contracts/contracts/interfaces/IPool.sol";

contract FastJPEGFactory is Ownable {
    address public constant BURN_ADDRESS = address(0x000000000000000000000000000000000000dEaD);
    uint256 public constant UNDERGRADUATE_SUPPLY = 800_000_000 * 1e18; // 800M tokens with 18 decimals
    uint256 public constant GRADUATE_SUPPLY = 200_000_000 * 1e18; // 200M tokens with 18 decimals
    uint256 public constant AIRDROP_SUPPLY = 160_000_000 * 1e18; // 160 million tokens

    uint256 public constant GRADUATE_ETH = 10 ether; // 10 ETH to graduate token

    uint256 public constant UNDERGRADUATE_FEE_BPS = 100; // 1% fee
    uint256 public constant BPS_DENOMINATOR = 10000; // 100% = 10000 BPS

    uint256 public constant GRADUATION_FEE = 0.5 ether; // 0.5 ETH to graduate token
    uint256 public constant CREATOR_REWARD_FEE = 0.1 ether; // 0.1 ETH to creator

    uint256 public constant AIRDROP_ETH = 2 ether; // 2 ETH to airdrop
    
        // DEX
    IPoolFactory public immutable poolFactory;
    IRouter public immutable router;

    // State variables
    struct TokenInfo {
        address tokenAddress;
        address creator;
        address poolAddress;
        uint256 reserveBalance;
        uint256 tokensSold;
        bool isGraduated;
    }

    mapping(address => TokenInfo) public tokens;
    


    // Events
    event TokenCreated(address indexed token, address indexed creator);
    event TokensBought(address indexed token, address indexed buyer, uint256 amount, uint256 ethSpent);
    event TokensSold(address indexed token, address indexed seller, uint256 amount, uint256 ethReceived);
    event AirdropIssued(address indexed token, address indexed recipient, uint256 amount);
    event TokenGraduated(address indexed token);

    constructor(address _poolFactory, address _router) Ownable() {
        poolFactory = IPoolFactory(_poolFactory);
        router = IRouter(_router);
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
        tokenInfo.creator = msg.sender;
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
            if (msg.value > AIRDROP_ETH) {
                payable(msg.sender).transfer(msg.value - AIRDROP_ETH);
            }
        } else if (msg.value > 0) {
            // Refund any ETH if no airdrop performed
            payable(msg.sender).transfer(msg.value);
        }

        emit TokenCreated(address(newToken), msg.sender);
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
            fee = (purchaseEthBeforeFee * UNDERGRADUATE_FEE_BPS) / BPS_DENOMINATOR;
            purchaseEth = purchaseEthBeforeFee - fee;
        }


        // Send fee to owner
        payable(owner()).transfer(fee);
        
        // Update reserve balance with the ETH used (after fee)
        tokenInfo.reserveBalance += purchaseEth;
        
        // Mint tokens to the buyer
        FastJPEGToken(tokenAddress).mint(msg.sender, tokensToMint);

        tokenInfo.tokensSold += tokensToMint;

        if (tokenInfo.tokensSold >= UNDERGRADUATE_SUPPLY) {
            _graduateToken(tokenAddress);
        }
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
        require(!tokenInfo.isGraduated, "Token already graduated");
        tokenInfo.isGraduated = true;
        
        // uint256 totalSupply = ERC20(tokenAddress).totalSupply();
        // console.log("totalSupply", totalSupply);
        // console.log("tokenInfo.reserveBalance", tokenInfo.reserveBalance);
        // console.log("tokenInfo.tokensSold", tokenInfo.tokensSold);

        //mint graduation supply factory
        FastJPEGToken(tokenAddress).mint(address(this), GRADUATE_SUPPLY);
        
        // // Approve router to spend tokens
        // ERC20(tokenAddress).approve(address(router), GRADUATE_SUPPLY);
        // console.log("totalSupply", ERC20(tokenAddress).totalSupply());

        
        // pay owner GRADUATION_FEE
        payable(owner()).transfer(GRADUATION_FEE); 
        // pay creator CREATOR_REWARD_FEE
        payable(tokenInfo.creator).transfer(CREATOR_REWARD_FEE);
        // remaining ETH used for liquidity
        uint256 liquidityEthAfterFee = tokenInfo.reserveBalance - GRADUATION_FEE - CREATOR_REWARD_FEE;

        // // log balance of contract
        // console.log("balance of contract", address(this).balance);
        // console.log("liquidityEthAfterFee", liquidityEthAfterFee);

        // Allow dex to reach in and pull tokens
        FastJPEGToken(tokenAddress).approve(address(router), GRADUATE_SUPPLY);

    

        // Add liquidity to Aerodrome
        (,, uint256 liquidity) = router.addLiquidityETH{value: liquidityEthAfterFee}(
            tokenAddress,
            false, // volatile pool
            GRADUATE_SUPPLY,
            GRADUATE_SUPPLY, // min token amount
            liquidityEthAfterFee, // min ETH amount
            address(this), // liquidity tokens are locked in the contract
            block.timestamp + 1800 // 30 minutes deadline
        );

        // Burn the liquidity provider tokens that are returned
        address wethAddress = address(router.weth());
        address lpTokenAddress = poolFactory.getPool(tokenAddress, wethAddress, false);
        IERC20(lpTokenAddress).approve(address(router), liquidity);
        // THIS DOESNT WORK [FAIL: revert: ERC20: transfer to the zero address] testGraduateToken() (gas: 2061435)
        IERC20(lpTokenAddress).transfer(BURN_ADDRESS, liquidity);

        // // Tranfer ownership to null address
        FastJPEGToken(tokenAddress).renounceOwnership();
        emit TokenGraduated(tokenAddress);
    }

    function _tokenInfo(address tokenAddress) internal view returns (TokenInfo storage) {
        TokenInfo storage tokenInfo = tokens[tokenAddress];
        require(tokenInfo.tokenAddress != address(0), "Token not found");
        return tokenInfo;
    }

    // Function to receive ETH
    receive() external payable {}
}