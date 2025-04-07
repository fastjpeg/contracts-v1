/**
 * .########....###.....######..########.......##.########..########..######..
 * .##.........##.##...##....##....##..........##.##.....##.##.......##....##.
 * .##........##...##..##..........##..........##.##.....##.##.......##.......
 * .######...##.....##..######.....##..........##.########..######...##...####
 * .##.......#########.......##....##....##....##.##........##.......##....##.
 * .##.......##.....##.##....##....##....##....##.##........##.......##....##.
 * .##.......##.....##..######.....##.....######..##........########..######..
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// import { console } from "forge-std/console.sol";
import { FJC } from "./FJC.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "../lib/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "../lib/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

///----------------------------------------------------------------------------------------------------------------
/// Events
///----------------------------------------------------------------------------------------------------------------
library FastJPEGFactoryError {
    error AirdropPercentageTooHigh();
    error AirdropPercentageMustBeZero();
    error CoinGraduated();
    error MustSendETH();
    error MaxSupplyReached();
    error InvalidRecipientAddress();
    error FailedToSendETH();
    error FailedToSendFee();
    error CoinAlreadyGraduated();
    error InsufficientBalance();
    error InvalidAmount();
    error InsufficientReserve();
    error CoinNotFound();
    error InsufficientCoinsOut();
    error InsufficientEthOut();
}

/**
 * @title FastJPEGFactory
 * @dev A factory contract for creating and managing Fast JPEG Coins (FJC)
 * Implements a bonding curve mechanism for token pricing and a graduation system
 * to transition tokens to Uniswap V2 liquidity pools.
 */
contract FastJPEGFactory is Ownable, ReentrancyGuard {
    address public constant BURN_ADDRESS = address(0x000000000000000000000000000000000000dEaD);
    uint256 public constant UNDERGRADUATE_SUPPLY = 800_000_000 * 1e18; // 800M coins with 18 decimals
    uint256 public constant GRADUATE_SUPPLY = 200_000_000 * 1e18; // 200M coins with 18 decimals

    // Remove fixed AIRDROP_SUPPLY and add max airdrop percentage
    uint256 public constant MAX_AIRDROP_PERCENTAGE_BPS = 10000; // 100% maximum airdrop

    uint256 public constant GRADUATE_ETH = 10 ether; // 10 ETH to graduate coin

    uint256 public constant UNDERGRADUATE_FEE_BPS = 100; // 1% fee
    uint256 public constant BPS_DENOMINATOR = 10000; // 100% = 10000 BPS

    uint256 public constant GRADUATION_FEE = 0.5 ether; // 0.5 ETH to graduate coin
    uint256 public constant CREATOR_REWARD_FEE = 0.1 ether; // 0.1 ETH to creator

    uint256 public constant AIRDROP_ETH = 2 ether; // 2 ETH to airdrop

    // Fee recipient address
    address public feeTo;

    // DEX
    IUniswapV2Factory public immutable poolFactory;
    IUniswapV2Router02 public immutable router;

    // State variables
    struct CoinInfo {
        address coinAddress;
        address creator;
        address poolAddress;
        uint256 ethReserve;
        uint256 coinsSold;
        uint256 metadataHash;
        bool isGraduated;
    }

    mapping(address => CoinInfo) public coins;

    // Events
    event NewCoin(address indexed coin, address indexed creator);
    event SwapCoin(address indexed sender, address indexed coin, uint256 amountA, uint256 amountB, uint256 volume);
    event AirdropCoin(address indexed coin, address indexed recipient, uint256 amount);
    event GraduateCoin(address indexed coin);

    /**
     * @dev Initializes the contract with the provided DEX factory, router, and fee recipient
     * @param _poolFactory Address of the Uniswap V2 Factory
     * @param _router Address of the Uniswap V2 Router
     * @param _feeTo Address that will receive fees
     */
    constructor(address _poolFactory, address _router, address _feeTo) Ownable(msg.sender) {
        poolFactory = IUniswapV2Factory(_poolFactory);
        router = IUniswapV2Router02(_router);
        feeTo = _feeTo;
    }

    /**
     * @dev Updates the fee recipient address
     * @param _feeTo New fee recipient address
     */
    function setFeeTo(address _feeTo) external onlyOwner {
        feeTo = _feeTo;
    }

    /**
     * @dev Launches a new coin with the specified name and symbol without airdrop recipients
     * @param name The name of the coin
     * @param symbol The symbol of the coin
     * @param metadataHash The metadataHash of the metadata submitted to the coin keccak256(toHex(metadata))
     * @return Address of the newly created coin
     */
    function newCoin(string memory name, string memory symbol, uint256 metadataHash)
        external
        payable
        returns (address)
    {
        address[] memory emptyRecipients = new address[](0);
        return newCoinAirdrop(name, symbol, emptyRecipients, 0, metadataHash);
    }

    /**
     * @dev Launches a new coin with the specified name and symbol
     * @param name The name of the coin
     * @param symbol The symbol of the coin
     * @param airdropRecipients Optional array of addresses to airdrop coins to (if msg.value >= 2 ETH)
     * @param airdropPercentageBps Percentage of undergraduate supply to airdrop in basis points (100 = 1%)
     * @param metadataHash The metadataHash of the metadata submitted to the coin keccak256(toHex(metadata))
     * @return Address of the newly created coin
     */
    function newCoinAirdrop(
        string memory name,
        string memory symbol,
        address[] memory airdropRecipients,
        uint256 airdropPercentageBps,
        uint256 metadataHash
    ) public payable returns (address) {
        if (airdropPercentageBps > MAX_AIRDROP_PERCENTAGE_BPS) {
            revert FastJPEGFactoryError.AirdropPercentageTooHigh();
        }
        // If there are no airdrop recipients, the airdrop percentage must be 0
        if (airdropRecipients.length == 0) {
            if (airdropPercentageBps != 0) {
                revert FastJPEGFactoryError.AirdropPercentageMustBeZero();
            }
        }

        // Deploy new coin - only mint bonding supply to contract initially
        FJC coin = new FJC(name, symbol);

        // Initialize coin info
        CoinInfo storage coinInfo = coins[address(coin)];
        coinInfo.coinAddress = address(coin);
        coinInfo.creator = msg.sender;
        coinInfo.ethReserve = 0;
        coinInfo.coinsSold = 0;
        coinInfo.isGraduated = false;
        coinInfo.metadataHash = metadataHash;
        emit NewCoin(address(coin), msg.sender);
        if (msg.value > 0) {
            _buy(address(coin), airdropRecipients, airdropPercentageBps, 0);
        }

        return address(coin);
    }

    /**
     * @dev Buy coins using ETH without airdrop, with slippage protection
     * @param coinAddress Address of the coin to buy
     * @param minCoinsOut Minimum amount of coins expected
     */
    function buy(address coinAddress, uint256 minCoinsOut) external payable nonReentrant {
        address[] memory emptyRecipients = new address[](0);
        _buy(coinAddress, emptyRecipients, 0, minCoinsOut);
    }

    /**
     * @dev Internal function to buy coins using ETH
     * @param coinAddress Address of the coin to buy
     * @param airdropRecipients Optional array of addresses to airdrop coins to
     * @param airdropPercentageBps Percentage of undergraduate supply to airdrop in basis points
     * @param minCoinsOut Minimum amount of coins expected for the buyer (msg.sender)
     */
    function _buy(
        address coinAddress,
        address[] memory airdropRecipients,
        uint256 airdropPercentageBps,
        uint256 minCoinsOut
    ) internal {
        CoinInfo storage coinInfo = _getCoinInfo(coinAddress);
        // --- Initial Checks ---
        if (coinInfo.isGraduated) revert FastJPEGFactoryError.CoinGraduated();
        if (msg.value == 0) revert FastJPEGFactoryError.MustSendETH();
        if (coinInfo.coinsSold >= UNDERGRADUATE_SUPPLY) revert FastJPEGFactoryError.MaxSupplyReached();

        // --- Calculate ETH amounts and potential refund ---
        uint256 purchaseEth = msg.value;
        uint256 refundEth = 0;
        if (coinInfo.ethReserve + msg.value > GRADUATE_ETH) {
            purchaseEth = GRADUATE_ETH - coinInfo.ethReserve;
            refundEth = msg.value - purchaseEth;
        }

        // --- Calculate fee and net ETH ---
        uint256 fee = (purchaseEth * UNDERGRADUATE_FEE_BPS) / BPS_DENOMINATOR;
        uint256 ethAfterFee = purchaseEth - fee;

        // --- Calculate potential coins and apply supply cap ---
        uint256 potentialNetCoins = calculatePurchaseAmount(ethAfterFee, coinInfo.coinsSold);
        uint256 remainingSupply = UNDERGRADUATE_SUPPLY - coinInfo.coinsSold;
        uint256 actualNetCoinsToMint = Math.min(potentialNetCoins, remainingSupply);

        // --- Handle Airdrop Distribution & Slippage Check ---
        (uint256 buyerCoins, uint256 airdroppedCoins) = _handleAirdrop(
            coinAddress,
            actualNetCoinsToMint,
            airdropRecipients,
            airdropPercentageBps,
            minCoinsOut // Pass buyer's minimum expectation
        );

        // Update coins sold state *after* airdrop minting is done in helper
        if (airdroppedCoins > 0) {
            coinInfo.coinsSold += airdroppedCoins;
        }

        // --- Mint Buyer's Coins ---
        if (buyerCoins > 0) {
            FJC(coinAddress).mint(msg.sender, buyerCoins);
            coinInfo.coinsSold += buyerCoins; // Update state for buyer coins
        }

        // --- Final State Update: Graduation or Fee Payment ---
        bool reachedGraduation = coinInfo.ethReserve + purchaseEth >= GRADUATE_ETH; // Check if the purchase *would* reach graduation

        if (reachedGraduation) {
            // Ensure reserve doesn't exceed GRADUATE_ETH before calling graduate
            // The purchaseEth might be less than msg.value if capped at GRADUATE_ETH
            coinInfo.ethReserve = GRADUATE_ETH;
            _graduateCoin(coinAddress, fee); // Fee passed to graduate function
        } else {
            // Send fee if not graduating
            (bool successFeeTo,) = feeTo.call{ value: fee }("");
            if (!successFeeTo) revert FastJPEGFactoryError.FailedToSendFee();
            coinInfo.ethReserve += ethAfterFee; // Update reserve only if not graduating
        }
        // --- Handle ETH Refund ---
        if (refundEth > 0) {
            (bool successRefund,) = msg.sender.call{ value: refundEth }("");
            if (!successRefund) revert FastJPEGFactoryError.FailedToSendETH();
        }

        emit SwapCoin(msg.sender, coinAddress, coinInfo.coinsSold, coinInfo.ethReserve, actualNetCoinsToMint);
    }

    /**
     * @dev Internal helper function to handle airdrop distribution and checks.
     * Mints coins to airdrop recipients directly.
     * @param coinAddress Address of the coin
     * @param totalNetCoins Total coins available for distribution (after fee, before airdrop split)
     * @param airdropRecipients Array of recipient addresses
     * @param airdropPercentageBps Percentage of undergraduate supply for airdrop
     * @param minBuyerCoinsOut Minimum coins the buyer (caller of _buy) expects to receive
     * @return buyerCoins Amount of coins allocated to the buyer
     * @return airdropCoinsDistributed Total amount of coins successfully airdropped
     */
    function _handleAirdrop(
        address coinAddress,
        uint256 totalNetCoins,
        address[] memory airdropRecipients,
        uint256 airdropPercentageBps,
        uint256 minBuyerCoinsOut
    ) internal returns (uint256 buyerCoins, uint256 airdropCoinsDistributed) {
        // Check if airdrop is feasible/requested
        if (totalNetCoins == 0 || airdropRecipients.length == 0 || airdropPercentageBps == 0) {
            // No airdrop possible or requested, all coins go to buyer
            if (totalNetCoins < minBuyerCoinsOut) {
                revert FastJPEGFactoryError.InsufficientCoinsOut();
            }
            return (totalNetCoins, 0);
        }

        uint256 maxAirdropAmount = (UNDERGRADUATE_SUPPLY * airdropPercentageBps) / BPS_DENOMINATOR;
        uint256 potentialAirdropCoins = Math.min(totalNetCoins, maxAirdropAmount);
        uint256 coinsPerRecipient = potentialAirdropCoins / airdropRecipients.length; // Integer division

        if (coinsPerRecipient == 0) {
            // Not enough coins to distribute even 1 per recipient, all coins go to buyer
            if (totalNetCoins < minBuyerCoinsOut) {
                revert FastJPEGFactoryError.InsufficientCoinsOut();
            }
            return (totalNetCoins, 0);
        }

        // Calculate actual airdrop amount and remaining buyer coins
        airdropCoinsDistributed = coinsPerRecipient * airdropRecipients.length;
        buyerCoins = totalNetCoins - airdropCoinsDistributed;

        // Check slippage for the buyer's portion *after* airdrop allocation
        if (buyerCoins < minBuyerCoinsOut) {
            revert FastJPEGFactoryError.InsufficientCoinsOut();
        }

        // Perform the airdrop minting
        for (uint256 i = 0; i < airdropRecipients.length; i++) {
            if (airdropRecipients[i] == address(0)) {
                revert FastJPEGFactoryError.InvalidRecipientAddress();
            }
            FJC(coinAddress).mint(airdropRecipients[i], coinsPerRecipient);
            emit AirdropCoin(coinAddress, airdropRecipients[i], coinsPerRecipient);
            // Note: coinsSold state is updated in the main _buy function after this helper returns
        }

        return (buyerCoins, airdropCoinsDistributed);
    }

    /**
     * @dev Sell coins to get ETH back based on the bonding curve, with slippage protection
     * @param coinAddress Address of the coin to sell
     * @param coinAmount Amount of coins to sell
     * @param minEthOut Minimum amount of ETH expected
     */
    function sell(address coinAddress, uint256 coinAmount, uint256 minEthOut) external nonReentrant {
        // Added minEthOut parameter
        CoinInfo storage coinInfo = _getCoinInfo(coinAddress);
        if (coinInfo.isGraduated) {
            revert FastJPEGFactoryError.CoinGraduated();
        }
        if (coinAmount == 0) {
            revert FastJPEGFactoryError.InvalidAmount();
        }
        if (FJC(coinAddress).balanceOf(msg.sender) < coinAmount) {
            revert FastJPEGFactoryError.InsufficientBalance();
        }

        uint256 currentSupply = FJC(coinAddress).totalSupply();
        if (coinAmount > currentSupply) {
            // This shouldn't happen if balance check passes, but good to have.
            revert FastJPEGFactoryError.InsufficientBalance();
        }

        // Calculate ETH to return based on the bonding curve
        uint256 returnEthBeforeFee = calculateSaleReturn(coinAmount, currentSupply);

        // Calculate 1% fee
        uint256 fee = (returnEthBeforeFee * UNDERGRADUATE_FEE_BPS) / BPS_DENOMINATOR;
        uint256 returnEth = returnEthBeforeFee - fee;

        if (returnEth < minEthOut) {
            // Check slippage
            revert FastJPEGFactoryError.InsufficientEthOut();
        }

        if (returnEth > coinInfo.ethReserve) {
            revert FastJPEGFactoryError.InsufficientReserve();
        }

        // Update total coins sold - subtract the amount being sold
        coinInfo.coinsSold -= coinAmount;

        // Update reserve balance *before* sending ETH
        coinInfo.ethReserve -= returnEthBeforeFee;

        // Send fee to feeTo
        (bool successFeeTo,) = feeTo.call{ value: fee }("");
        if (!successFeeTo) {
            // Revert state changes if fee transfer fails
            coinInfo.ethReserve += returnEth; // Add back returnEth
            coinInfo.coinsSold += coinAmount; // Restore coinsSold
            // Attempt to refund the fee to the contract (complex, might require feeTo cooperation or state flags)
            // Reverting here is simpler but leaves fee potentially lost if feeTo received it.
            revert FastJPEGFactoryError.FailedToSendFee();
        }

        // Burn coins *after* state updates and fee transfer, *before* sending ETH to seller
        // This follows Checks-Effects-Interactions pattern more closely
        FJC(coinAddress).burn(msg.sender, coinAmount);

        // Send ETH to seller (after fee)
        (bool successSeller,) = msg.sender.call{ value: returnEth }("");
        if (!successSeller) {
            // If ETH transfer to seller fails, we have already deducted fee and ETH from reserve, and burned tokens.
            // This state is complex to revert fully. The ETH remains in the contract.
            // Ideally, handle this potential failure scenario based on desired contract behavior (e.g., allow withdrawal later?).
            // For now, we revert, which might lock the fee and burned tokens state if not handled carefully upstream.
            // Revert state changes if seller transfer fails
            // Note: This revert might not be ideal as the fee has been sent.
            // Consider alternative recovery mechanisms if needed.
            coinInfo.ethReserve += returnEth; // Add back returnEth sent to seller (which failed)
            coinInfo.coinsSold += coinAmount; // Restore coinsSold
            // Attempt to refund the fee to the contract (complex, might require feeTo cooperation or state flags)
            // Reverting here is simpler but leaves fee potentially lost if feeTo received it.
            revert FastJPEGFactoryError.FailedToSendETH();
        }

        emit SwapCoin(msg.sender, coinAddress, coinInfo.coinsSold, coinInfo.ethReserve, coinAmount);
    }

    /**
     * @dev Calculate how many coins to mint for a given ETH amount using a quadratic bonding curve
     * @param ethAmount Amount of ETH sent
     * @param currentSupply Current total supply
     * @return Amount of coins to mint
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
        uint256 newCoinSupply = Math.sqrt(sumUnderRoot);

        return newCoinSupply > currentSupply ? newCoinSupply - currentSupply : 0;
    }

    /**
     * @dev Calculate how much ETH is needed to purchase a specific coin amount
     * @param coinAmount Amount of coins to purchase
     * @param currentSupply Current total supply
     * @return Amount of ETH needed
     */
    function calculatePriceForCoins(uint256 coinAmount, uint256 currentSupply) public pure returns (uint256) {
        // For a quadratic curve: E = (GRADUATE_ETH * ((currentSupply + T)² - currentSupply²)) / UNDERGRADUATE_SUPPLY²

        uint256 newSupply = currentSupply + coinAmount;

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
     * @dev Calculate how much ETH to return when selling coins
     * @param coinAmount Amount of coins to sell
     * @param currentSupply Current total supply
     * @return Amount of ETH to return
     */
    function calculateSaleReturn(uint256 coinAmount, uint256 currentSupply) public pure returns (uint256) {
        // Uses the same formula as calculatePriceForCoins but in reverse
        return calculatePriceForCoins(coinAmount, currentSupply - coinAmount);
    }

    /**
     * @dev Internal function to graduate a coin to Uniswap V2
     * Mints graduation supply, pays fees, and adds liquidity to DEX
     * @param coinAddress The address of the coin to graduate
     * @param fee The amount of ETH to graduate the coin
     */
    function _graduateCoin(address coinAddress, uint256 fee) internal {
        CoinInfo storage coinInfo = coins[coinAddress];
        if (coinInfo.isGraduated) {
            revert FastJPEGFactoryError.CoinAlreadyGraduated();
        }

        uint256 ownerFee = GRADUATION_FEE + fee;
        // pay feeTo GRADUATION_FEE
        (bool successFeeTo,) = feeTo.call{ value: ownerFee }("");
        if (!successFeeTo) {
            revert FastJPEGFactoryError.FailedToSendETH();
        }
        // pay creator CREATOR_REWARD_FEE
        (bool successCreator,) = coinInfo.creator.call{ value: CREATOR_REWARD_FEE }("");
        if (!successCreator) {
            revert FastJPEGFactoryError.FailedToSendETH();
        }

        //mint graduation supply factory
        FJC(coinAddress).mint(address(this), GRADUATE_SUPPLY);

        // remaining ETH used for liquidity
        uint256 liquidityEthAfterFee = coinInfo.ethReserve - ownerFee - CREATOR_REWARD_FEE;

        // Allow dex to reach in and pull coins
        FJC(coinAddress).approve(address(router), GRADUATE_SUPPLY);

        // Add liquidity to Uniswap V2
        (,, uint256 liquidity) = router.addLiquidityETH{ value: liquidityEthAfterFee }(
            coinAddress,
            GRADUATE_SUPPLY,
            GRADUATE_SUPPLY, // min coin amount
            liquidityEthAfterFee, // min ETH amount
            address(this), // recipient of the liquidity coins.
            block.timestamp + 1800 // 30 minutes deadline
        );

        // Burn the liquidity provider coins that are returned
        address wethAddress = address(router.WETH());
        address lpCoinAddress = poolFactory.getPair(coinAddress, wethAddress);
        IERC20(lpCoinAddress).approve(address(router), liquidity);
        SafeERC20.safeTransfer(IERC20(lpCoinAddress), BURN_ADDRESS, liquidity);

        // Transfer ownership to null address
        FJC(coinAddress).renounceOwnership();
        coinInfo.isGraduated = true;
        emit GraduateCoin(coinAddress);
    }

    /**
     * @dev Helper function to retrieve coin info and validate its existence
     * @param coinAddress Address of the coin to retrieve info for
     * @return CoinInfo struct for the specified coin
     */
    function _getCoinInfo(address coinAddress) internal view returns (CoinInfo storage) {
        CoinInfo storage coinInfo = coins[coinAddress];
        if (coinInfo.coinAddress == address(0)) {
            revert FastJPEGFactoryError.CoinNotFound();
        }
        return coinInfo;
    }

    /**
     * @dev Function to receive ETH
     * Required for router.addLiquidityETH to work
     */
    receive() external payable { }
}
