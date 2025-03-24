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
import "../lib/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "../lib/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

/**
 * @title FastJPEGFactory
 * @dev A factory contract for creating and managing Fast JPEG Coins (FJC)
 * Implements a bonding curve mechanism for token pricing and a graduation system
 * to transition tokens to Uniswap V2 liquidity pools.
 */
contract FastJPEGFactory is Ownable {
    address public constant BURN_ADDRESS = address(0x000000000000000000000000000000000000dEaD);
    uint256 public constant UNDERGRADUATE_SUPPLY = 800_000_000 * 1e18; // 800M coins with 18 decimals
    uint256 public constant GRADUATE_SUPPLY = 200_000_000 * 1e18; // 200M coins with 18 decimals
    uint256 public constant AIRDROP_SUPPLY = 200_000_000 * 1e18; // 200 million coins

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
    event BuyCoin(address indexed coin, address indexed buyer, uint256 amount, uint256 ethSpent);
    event SellCoin(address indexed coin, address indexed seller, uint256 amount, uint256 ethReceived);
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
    function newCoin(string memory name, string memory symbol, uint256 metadataHash) public payable returns (address) {
        address[] memory emptyRecipients = new address[](0);
        return newCoinAirdrop(name, symbol, emptyRecipients, metadataHash);
    }

    /**
     * @dev Launches a new coin with the specified name and symbol
     * @param name The name of the coin
     * @param symbol The symbol of the coin
     * @param airdropRecipients Optional array of addresses to airdrop coins to (if msg.value >= 2 ETH)
     * @param metadataHash The metadataHash of the metadata submitted to the coin keccak256(toHex(metadata))
     * @return Address of the newly created coin
     */
    function newCoinAirdrop(
        string memory name,
        string memory symbol,
        address[] memory airdropRecipients,
        uint256 metadataHash
    ) public payable returns (address) {
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
        if (msg.value > 0) {
            _buy(address(coin), airdropRecipients);
        }

        emit NewCoin(address(coin), msg.sender);
        return address(coin);
    }

    /**
     * @dev Buy coins using ETH without airdrop
     * @param coinAddress Address of the coin to buy
     */
    function buy(address coinAddress) external payable {
        address[] memory emptyRecipients = new address[](0);
        _buy(coinAddress, emptyRecipients);
    }

    /**
     * @dev Internal function to buy coins using ETH
     * @param coinAddress Address of the coin to buy
     * @param airdropRecipients Optional array of addresses to airdrop coins to
     */
    function _buy(address coinAddress, address[] memory airdropRecipients) internal {
        CoinInfo storage coinInfo = _getCoinInfo(coinAddress);
        require(!coinInfo.isGraduated, "Coin been graduated, buys disabled");
        require(msg.value > 0, "Must send ETH");
        require(coinInfo.coinsSold < UNDERGRADUATE_SUPPLY, "Max supply reached");

        uint256 totalEthRaised = coinInfo.ethReserve + msg.value;
        uint256 purchaseEthBeforeFee = Math.min(msg.value, GRADUATE_ETH);
        uint256 refundEth = totalEthRaised - purchaseEthBeforeFee;

        uint256 coinsToMint = calculatePurchaseAmount(purchaseEthBeforeFee, coinInfo.coinsSold);

        // Check if minting would exceed max supply and cap if necessary
        if (coinInfo.coinsSold + coinsToMint > UNDERGRADUATE_SUPPLY) {
            coinsToMint = UNDERGRADUATE_SUPPLY - coinInfo.coinsSold;
        }

        uint256 totalCoins = coinInfo.coinsSold + coinsToMint;
        uint256 airdropCoins = 0;
        uint256 fee = (purchaseEthBeforeFee * UNDERGRADUATE_FEE_BPS) / BPS_DENOMINATOR;

        if (totalCoins < UNDERGRADUATE_SUPPLY) {
            uint256 purchaseEth = purchaseEthBeforeFee - fee;
            coinsToMint = calculatePurchaseAmount(purchaseEth, coinInfo.coinsSold);

            // Check again after fee calculation
            if (coinInfo.coinsSold + coinsToMint > UNDERGRADUATE_SUPPLY) {
                coinsToMint = UNDERGRADUATE_SUPPLY - coinInfo.coinsSold;
            }
        }

        if (coinsToMint > 0 && airdropRecipients.length > 0) {
            airdropCoins = Math.min(coinsToMint, AIRDROP_SUPPLY);
            uint256 coinsPerRecipient = airdropRecipients.length > 0 ? airdropCoins / airdropRecipients.length : 0;
            coinInfo.coinsSold += airdropCoins;

            for (uint256 i = 0; i < airdropRecipients.length; i++) {
                require(airdropRecipients[i] != address(0), "Invalid recipient address");
                FJC(coinAddress).mint(airdropRecipients[i], coinsPerRecipient);
                emit AirdropCoin(coinAddress, airdropRecipients[i], coinsPerRecipient);
            }
        }

        uint256 remainingCoins = coinsToMint - airdropCoins;

        if (remainingCoins > 0) {
            FJC(coinAddress).mint(msg.sender, remainingCoins);
            coinInfo.coinsSold += remainingCoins;
        }

        if (totalEthRaised >= GRADUATE_ETH) {
            (bool successBuyer,) = msg.sender.call{ value: refundEth }("");
            require(successBuyer, "Failed to send Ether");
            coinInfo.ethReserve = GRADUATE_ETH;
            _graduateCoin(coinAddress, fee);
        } else {
            (bool successFeeTo,) = feeTo.call{ value: fee }("");
            require(successFeeTo, "Failed to send Ether");
            coinInfo.ethReserve += purchaseEthBeforeFee - fee; // Subtract fee from reserve balance
        }

        emit BuyCoin(coinAddress, msg.sender, coinsToMint, purchaseEthBeforeFee);
    }

    /**
     * @dev Sell coins to get ETH back based on the bonding curve
     * @param coinAddress Address of the coin to sell
     * @param coinAmount Amount of coins to sell
     */
    function sell(address coinAddress, uint256 coinAmount) external {
        CoinInfo storage coinInfo = _getCoinInfo(coinAddress);
        require(!coinInfo.isGraduated, "Coin graduated, sells disabled");
        require(coinAmount > 0, "Amount must be positive");
        require(FJC(coinAddress).balanceOf(msg.sender) >= coinAmount, "Insufficient balance");

        uint256 currentSupply = FJC(coinAddress).totalSupply();

        // Calculate ETH to return based on the bonding curve
        uint256 returnEthBeforeFee = calculateSaleReturn(coinAmount, currentSupply);

        // Calculate 1% fee
        uint256 fee = (returnEthBeforeFee * UNDERGRADUATE_FEE_BPS) / BPS_DENOMINATOR;
        uint256 returnEth = returnEthBeforeFee - fee;

        require(returnEth <= coinInfo.ethReserve, "Insufficient reserve");

        // Burn coins
        FJC(coinAddress).burn(msg.sender, coinAmount);

        // Update reserve balance
        coinInfo.ethReserve -= returnEth;

        // Send fee to feeTo
        (bool successFeeTo,) = feeTo.call{ value: fee }("");
        require(successFeeTo, "Failed to send Ether");

        // Send ETH to seller (after fee)
        (bool successSeller,) = msg.sender.call{ value: returnEth }("");
        require(successSeller, "Failed to send Ether");

        // Update total coins sold
        coinInfo.coinsSold -= coinAmount;
        emit SellCoin(coinAddress, msg.sender, coinAmount, returnEth);
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
        require(!coinInfo.isGraduated, "Coin already graduated");
        coinInfo.isGraduated = true;

        //mint graduation supply factory
        FJC(coinAddress).mint(address(this), GRADUATE_SUPPLY);

        uint256 ownerFee = GRADUATION_FEE + fee;
        // pay feeTo GRADUATION_FEE
        (bool successFeeTo,) = feeTo.call{ value: ownerFee }("");
        require(successFeeTo, "Failed to send Ether");
        // pay creator CREATOR_REWARD_FEE
        (bool successCreator,) = coinInfo.creator.call{ value: CREATOR_REWARD_FEE }("");
        require(successCreator, "Failed to send Ether");
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
        IERC20(lpCoinAddress).transfer(BURN_ADDRESS, liquidity);

        // Transfer ownership to null address
        FJC(coinAddress).renounceOwnership();
        emit GraduateCoin(coinAddress);
    }

    /**
     * @dev Helper function to retrieve coin info and validate its existence
     * @param coinAddress Address of the coin to retrieve info for
     * @return CoinInfo struct for the specified coin
     */
    function _getCoinInfo(address coinAddress) internal view returns (CoinInfo storage) {
        CoinInfo storage coinInfo = coins[coinAddress];
        require(coinInfo.coinAddress != address(0), "Coin not found");
        return coinInfo;
    }

    /**
     * @dev Function to receive ETH
     * Required for router.addLiquidityETH to work
     */
    receive() external payable { }
}
