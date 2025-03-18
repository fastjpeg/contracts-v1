// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console } from "forge-std/console.sol";
import { FastJPEGToken } from "./FastJPEGToken.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import "../lib/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "../lib/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

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

    // Fee recipient address
    address public feeTo;

    // DEX
    IUniswapV2Factory public immutable poolFactory;
    IUniswapV2Router02 public immutable router;

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

    constructor(address _poolFactory, address _router, address _feeTo) Ownable(msg.sender) {
        poolFactory = IUniswapV2Factory(_poolFactory);
        router = IUniswapV2Router02(_router);
        feeTo = _feeTo;
    }

    function setFeeTo(address _feeTo) external onlyOwner {
        feeTo = _feeTo;
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
     * @param airdropRecipients Optional array of addresses to airdrop tokens to (if msg.value >= 2 ETH)
     */
    function createTokenAirdrop(string memory name, string memory symbol, address[] memory airdropRecipients)
        public
        payable
        returns (address)
    {
        // Deploy new token - only mint bonding supply to contract initially
        FastJPEGToken newToken = new FastJPEGToken(name, symbol);

        // Initialize token info
        TokenInfo storage tokenInfo = tokens[address(newToken)];
        tokenInfo.tokenAddress = address(newToken);
        tokenInfo.creator = msg.sender;
        tokenInfo.reserveBalance = 0;
        tokenInfo.tokensSold = 0;
        tokenInfo.isGraduated = false;

        if (msg.value > 0) {
            _buy(address(newToken), airdropRecipients);
        }

        emit TokenCreated(address(newToken), msg.sender);
        return address(newToken);
    }

    function buy(address tokenAddress) external payable {
        address[] memory emptyRecipients = new address[](0);
        _buy(tokenAddress, emptyRecipients);
    }

    /**
     * @dev Buy tokens using ETH
     */
    function _buy(address tokenAddress, address[] memory airdropRecipients) internal {
        TokenInfo storage tokenInfo = _tokenInfo(tokenAddress);
        require(!tokenInfo.isGraduated, "Token been graduated, buys disabled");
        require(msg.value > 0, "Must send ETH");
        require(tokenInfo.tokensSold < UNDERGRADUATE_SUPPLY, "Max supply reached");

        uint256 totalEthRaised = tokenInfo.reserveBalance + msg.value;
        uint256 purchaseEthBeforeFee = Math.min(totalEthRaised, GRADUATE_ETH);
        uint256 refundEth = totalEthRaised - purchaseEthBeforeFee;

        uint256 tokensToMint = calculatePurchaseAmount(purchaseEthBeforeFee, tokenInfo.tokensSold);
        uint256 totalTokensSold = tokenInfo.tokensSold + tokensToMint;
        uint256 airdropTokens = 0;
        uint256 fee = (purchaseEthBeforeFee * UNDERGRADUATE_FEE_BPS) / BPS_DENOMINATOR;

        if (totalTokensSold < UNDERGRADUATE_SUPPLY) {
            uint256 purchaseEth = purchaseEthBeforeFee - fee;
            tokensToMint = calculatePurchaseAmount(purchaseEth, tokenInfo.tokensSold);
        }

        if (tokensToMint > 0 && airdropRecipients.length > 0) {
            airdropTokens = Math.min(tokensToMint, AIRDROP_SUPPLY);
            uint256 tokensPerRecipient = airdropTokens / airdropRecipients.length;
            tokenInfo.tokensSold += airdropTokens;

            for (uint256 i = 0; i < airdropRecipients.length; i++) {
                require(airdropRecipients[i] != address(0), "Invalid recipient address");
                FastJPEGToken(tokenAddress).mint(airdropRecipients[i], tokensPerRecipient);
                emit AirdropIssued(tokenAddress, airdropRecipients[i], tokensPerRecipient);
            }
        }

        uint256 remainingTokens = tokensToMint - airdropTokens;

        if (remainingTokens > 0) {
            FastJPEGToken(tokenAddress).mint(msg.sender, remainingTokens);
            tokenInfo.tokensSold += remainingTokens;
        }

        if (totalEthRaised > GRADUATE_ETH) {
            (bool successBuyer,) = msg.sender.call{ value: refundEth }("");
            require(successBuyer, "Failed to send Ether");
            tokenInfo.reserveBalance = GRADUATE_ETH;
            _graduateToken(tokenAddress, fee);
        } else {
            (bool successFeeTo,) = feeTo.call{ value: fee }("");
            require(successFeeTo, "Failed to send Ether");
            tokenInfo.reserveBalance += purchaseEthBeforeFee;
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

        // Send fee to feeTo
        (bool successFeeTo,) = feeTo.call{ value: fee }("");
        require(successFeeTo, "Failed to send Ether");

        // Send ETH to seller (after fee)
        (bool successSeller,) = msg.sender.call{ value: returnEth }("");
        require(successSeller, "Failed to send Ether");

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
     * @param fee The amount of ETH to graduate the token
     */
    function _graduateToken(address tokenAddress, uint256 fee) internal {
        TokenInfo storage tokenInfo = tokens[tokenAddress];
        require(!tokenInfo.isGraduated, "Token already graduated");
        tokenInfo.isGraduated = true;

        //mint graduation supply factory
        FastJPEGToken(tokenAddress).mint(address(this), GRADUATE_SUPPLY);

        uint256 ownerFee = GRADUATION_FEE + fee;
        // pay feeTo GRADUATION_FEE
        (bool successFeeTo,) = feeTo.call{ value: ownerFee }("");
        require(successFeeTo, "Failed to send Ether");
        // pay creator CREATOR_REWARD_FEE
        (bool successCreator,) = tokenInfo.creator.call{ value: CREATOR_REWARD_FEE }("");
        require(successCreator, "Failed to send Ether");
        // remaining ETH used for liquidity
        uint256 liquidityEthAfterFee = tokenInfo.reserveBalance - ownerFee - CREATOR_REWARD_FEE;

        // Allow dex to reach in and pull tokens
        FastJPEGToken(tokenAddress).approve(address(router), GRADUATE_SUPPLY);

        // Add liquidity to Aerodrome
        (,, uint256 liquidity) = router.addLiquidityETH{ value: liquidityEthAfterFee }(
            tokenAddress,
            GRADUATE_SUPPLY,
            GRADUATE_SUPPLY, // min token amount
            liquidityEthAfterFee, // min ETH amount
            address(this), // recipient of the liquidity tokens.
            block.timestamp + 1800 // 30 minutes deadline
        );

        // Burn the liquidity provider tokens that are re:turned
        address wethAddress = address(router.WETH());
        address lpTokenAddress = poolFactory.getPair(tokenAddress, wethAddress);
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
    receive() external payable { }
}
