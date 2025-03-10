// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {console} from "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract FastJPEGToken is ERC20, Ownable {
    using Math for uint256;

    uint256 public constant PRE_LAUNCH_MAX_SUPPLY = 800_000_000 * 10**18; // 800M tokens with 18 decimals
    uint256 public constant MAX_ETH = 5 ether; // 5 ETH to purchase all tokens
    uint256 public constant FEE_PERCENTAGE = 1; // 1% fee
    
    // Tracks total ETH collected from purchases
    uint256 private _reserveBalance;
    // track total tokens sold
    uint256 private _totalTokensSold;
    bool private _isLaunched = false;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    /**
     * @dev Buy tokens using ETH
     */
    function buy() external payable {
        require(!_isLaunched, "Token has been launched, buys disabled");
        require(msg.value > 0, "Must send ETH");
        
        require(_totalTokensSold < PRE_LAUNCH_MAX_SUPPLY, "Max supply reached");
        // Calculate tokens to mint based on the bonding curve
        uint256 tokensToMint = calculatePurchaseAmount(msg.value, _totalTokensSold);
        
        console.log("tokensToMint", tokensToMint);

        uint256 ethNeeded = msg.value;
        
        // Ensure we don't exceed max supply
        if (_totalTokensSold + tokensToMint > PRE_LAUNCH_MAX_SUPPLY) {
            tokensToMint = PRE_LAUNCH_MAX_SUPPLY - _totalTokensSold;
            
            // Calculate actual ETH needed and refund excess
            ethNeeded = calculatePriceForTokens(tokensToMint, _totalTokensSold);
            if (msg.value > ethNeeded) {
                payable(msg.sender).transfer(msg.value - ethNeeded);
            }
        }
        
        // Calculate 1% fee
        uint256 fee = (ethNeeded * FEE_PERCENTAGE) / 100;
        uint256 ethAfterFee = ethNeeded - fee;
        
        // Send fee to owner
        payable(owner()).transfer(fee);
        
        // Update reserve balance with the ETH used (after fee)
        _reserveBalance += ethAfterFee;
        
        // Mint tokens to the buyer
        _mint(msg.sender, tokensToMint);

        // Update total tokens sold
        _totalTokensSold += tokensToMint;
    }

    /**
     * @dev Sell tokens to get ETH back
     * @param tokenAmount Amount of tokens to sell
     */
    function sell(uint256 tokenAmount) external {
        require(!_isLaunched, "Token has been launched, sells disabled");
        require(tokenAmount > 0, "Amount must be positive");
        require(balanceOf(msg.sender) >= tokenAmount, "Insufficient balance");
        
        uint256 currentSupply = totalSupply();
        
        // Calculate ETH to return based on the bonding curve
        uint256 ethToReturn = calculateSaleReturn(tokenAmount, currentSupply);
        require(ethToReturn <= _reserveBalance, "Insufficient reserve");
        
        // Calculate 1% fee
        uint256 fee = (ethToReturn * FEE_PERCENTAGE) / 100;
        uint256 ethAfterFee = ethToReturn - fee;
        
        // Burn tokens
        _burn(msg.sender, tokenAmount);
        
        // Update reserve balance
        _reserveBalance -= ethToReturn;
        
        // Send fee to owner
        payable(owner()).transfer(fee);
        
        // Send ETH to seller (after fee)
        payable(msg.sender).transfer(ethAfterFee);

        // Update total tokens sold
        _totalTokensSold -= tokenAmount;
    }
    
    /**
     * @dev Calculate how many tokens to mint for a given ETH amount
     * @param ethAmount Amount of ETH sent
     * @param currentSupply Current total supply
     * @return Amount of tokens to mint
     */
    function calculatePurchaseAmount(uint256 ethAmount, uint256 currentSupply) public pure returns (uint256) {
        // For a quadratic curve: T = sqrt((E * PRE_LAUNCH_MAX_SUPPLY²) / MAX_ETH + currentSupply²) - currentSupply
        
        // Calculate: (E * PRE_LAUNCH_MAX_SUPPLY²) / MAX_ETH
        uint256 numerator = ethAmount * (PRE_LAUNCH_MAX_SUPPLY ** 2);
        uint256 term1 = numerator / MAX_ETH;
        
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
        // For a quadratic curve: E = (MAX_ETH * ((currentSupply + T)² - currentSupply²)) / PRE_LAUNCH_MAX_SUPPLY²
        
        uint256 newSupply = currentSupply + tokenAmount;
        
        // Calculate: (currentSupply + T)² - currentSupply²
        uint256 newSupplySquared = newSupply ** 2;
        uint256 currentSupplySquared = currentSupply ** 2;
        uint256 supplyDeltaSquared = newSupplySquared - currentSupplySquared;
        
        // Calculate: (MAX_ETH * supplyDeltaSquared) / PRE_LAUNCH_MAX_SUPPLY²
        uint256 numerator = MAX_ETH * supplyDeltaSquared;
        uint256 denominator = PRE_LAUNCH_MAX_SUPPLY ** 2;
        
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
     * @dev Get current price per token in ETH
     * @return Current price in ETH for 1 token
     */
    function getCurrentPrice() public view returns (uint256) {
        uint256 currentSupply = totalSupply();
        
        // For a quadratic curve, the marginal price is the derivative: p = (2 * MAX_ETH * currentSupply) / PRE_LAUNCH_MAX_SUPPLY²
        uint256 numerator = 2 * MAX_ETH * currentSupply;
        uint256 denominator = PRE_LAUNCH_MAX_SUPPLY ** 2;
        
        return numerator / denominator;
    }
    
    /**
     * @dev Get the current reserve balance
     * @return Reserve balance in ETH
     */
    function getReserveBalance() external view returns (uint256) {
        return _reserveBalance;
    }
    
    /**
     * @dev Launch the token, disabling buys and sells
     * Only owner can call this function
     */
    function launchToken() external onlyOwner {
        _isLaunched = true;
    }
    
    /**
     * @dev Check if token has been launched
     * @return True if token has been launched
     */
    function isLaunched() external view returns (bool) {
        return _isLaunched;
    }
}