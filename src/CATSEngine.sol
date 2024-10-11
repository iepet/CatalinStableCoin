//SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.26;

import {CatalanStableCoin} from "./CatalanStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
/**
 * @title CATSEngine
 * @author Tepei
 * The system is designed to be as minimal as posible, design to be 1 token == 1 gold gram
 * This stable coin has
 * - Exogenous Collateral
 * - Gold Gram Pegged
 * - Algoritmically Stable
 * - The CAT system should always be overcollateralized. At no point, should all collateral <= thevalue of all CATs
 * @notice This contract holds the whole logic of the stablecoin, following UpdraftCyfrin course
 */

contract CATSEngine is ReentrancyGuard {
    ///////////////// ERRORS ///////////////////
    error CATSEngine__MustBeGreaterThanZero();
    error CATSEngine__ArrayLengthMismatch();
    error CATSEngine__NotAllowedToken();
    error CATSEngine__TransferFailed();
    error CATSEngine__BreakHealthFactor();  
    error CATSEngine__MintFailed();
    error CATSEngine__BreakHealthFactorOK();
    error CATSEngine__HealthFactorNotImproved();

    ///////////////// STATE VARILABLES ///////////////////
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; //200% overcollateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1;
    uint256 private constant LIQUIDATION_BONUS = 10; //10% bonus

    mapping(address token => address priceFeed) private s_priceFeeds; //token To price feed
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited; //user to token to amount
    mapping(address user => uint256 amountCatMinted) private s_CATMinted; //user to amount of CAT minted
    address[] private s_collateralTokens;

    CatalanStableCoin private immutable i_catToken;

    ///////////////// EVENTS ///////////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(address indexed redeemedFrom,address indexed redeemedTo, address token, uint256  amount);

    ///////////////// MODIFIERS ///////////////////
    modifier moreThanzero(uint256 _amount) {
        if (_amount == 0) {
            revert CATSEngine__MustBeGreaterThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert CATSEngine__NotAllowedToken();
        }
        _;
    }

    ///////////////// FUNCTIONS ///////////////////
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address catAddress) {
        //Gold price feeds
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert CATSEngine__ArrayLengthMismatch();
        }
        //For example ETH/GOLD, BTC/GOLD, etc
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]); 
        }
        i_catToken = CatalanStableCoin(catAddress);
    }

    ///////////// External functions /////////////

    /**
     * @notice Deposit collateral and mint CAT
     * @param tokenCollateraladdress The address of the token to be deposited as collateral
     * @param amountCollateral The amount of collateral to be deposited
     * @param amountCATtoMint The amount of CAT to mint
     */
    function depositCollateralAndMintCat(address tokenCollateraladdress, uint256 amountCollateral, uint256 amountCATtoMint) external {
        depositCollateral(tokenCollateraladdress, amountCollateral);
        mintCat(amountCATtoMint);
    }

    /**
     * @notice Deposit collateral to mint CAT
     * @param tokenCollateralAddress The address of the token to be deposited as collateral
     * @param amountCollateral The amount of collateral to be deposited
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanzero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert CATSEngine__TransferFailed();
        }
    }

    /*
    * @notice Redeem collateral and burn CAT
    * @param tokenCollateralAddress The address of the token to be redeemed
    * @param amountCollateral The amount of collateral to be redeemed
    * 
     */
    function redeemCollateralForCat(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToBurn )
     external 
     {
        burnCat(amountDscToBurn);
        redeemCollateral(tokenCollateralAddress, amountCollateral); 
        //Redeem collateral already checks health factor
     }

    // in order to reedem collateral:
    // 1. check if health factor is over 1 after collateral is pulled
    // DRY: Don't repeat yourself
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanzero(amountCollateral)
        nonReentrant
     {
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);
        _revertIfHealthFactorIsBrokeN(msg.sender);
     }

    /**
     * @notice Mint CAT tokens
     * @param amountCatToMint The amount of CAT to mint
     * @notice The CAT system should always be overcollateralized. So collateral >= minimum threshold
     */
    function mintCat(uint256 amountCatToMint) public moreThanzero(amountCatToMint) nonReentrant {
        s_CATMinted[msg.sender] += amountCatToMint;
        i_catToken.mint(msg.sender, amountCatToMint);
        _revertIfHealthFactorIsBrokeN(msg.sender);
        bool minted = i_catToken.mint(msg.sender, amountCatToMint);
        if (!minted) {
            revert CATSEngine__MintFailed();
        }

    }

    function burnCat(uint256 amount)
        public
        moreThanzero(amount)
    {
        _brunCat(amount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBrokeN(msg.sender); 
    }


    //If someone is almost undercollateralized, we will pay you to liquidize
    /**
     * @notice Liquidate a user's collateral
     * @param collateral The address of the collateral to be liquidated
     * @param user The address of the user that broke the health factor
     * @param debtToCover The amount of debt to cover
     * @notice The CAT system should always be overcollateralized. So collateral >= minimum threshold, if we are at 100% collateral or less, the system wouldnt work
     * since we could not incentivize liquidators
     */
    function liquidate(address collateral, address user, uint256 debtToCover) 
    external
    moreThanzero(debtToCover)
    nonReentrant 
    {
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert CATSEngine__BreakHealthFactorOK();
        }
        // We want to burn their CAT "debt" and take their collateral
        //Example User: 140 GoldGrams of Eth,  100 oldGrams of CAT
        //debtto cover  = 100 goldgrams
        //100 of CAT  = ?? ETH?
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromGoldGrams(collateral, debtToCover);
        //And give them a 10% bonus to incentivize liquidators
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        _redeemCollateral(collateral, (tokenAmountFromDebtCovered + bonusCollateral), user, msg.sender);
        _brunCat(debtToCover, user, msg.sender);

        uint256 endingUserHeatlhFactor = _healthFactor(user);
        if (endingUserHeatlhFactor <= startingUserHealthFactor){
            revert CATSEngine__HealthFactorNotImproved();
        }
        _revertIfHealthFactorIsBrokeN(msg.sender);

    }
    // To prevenet collateral to tank and CAT to be worth more than collateral, we will liquidate when collateral tanks
    function getHealthFactor() external {}

    ///////////// Private and Internal functions /////////////
    
    /**
     * @notice Burns CAT and redeems collateral
     * @param amountCatToBurn The amount of CAT to burn
     * @param onBehalfOf On behalf of whom the CAT is being burned
     * @param catFrom from whom the CAT is being burned
     */
    function _brunCat(uint256 amountCatToBurn, address onBehalfOf, address catFrom) private {
        s_CATMinted[onBehalfOf] -= amountCatToBurn;
        bool success = i_catToken.transferFrom(catFrom, address(this), amountCatToBurn);
        if (!success) {
            revert CATSEngine__TransferFailed();
        }
        i_catToken.burn(amountCatToBurn);
    }


    function _redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral, address from, address to)private {
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from,to, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if(!success){
            revert CATSEngine__TransferFailed();
        }
    }

    function _getAccountInformation(address user)
        internal
        view
        returns (uint256 totalCatMinted, uint256 collateralValueInGoldGram)
    {
        totalCatMinted = s_CATMinted[user];
        collateralValueInGoldGram = getAccountCollateralValue(user);
    }

    /**
     * @notice Returns how close a user is to liquidation, if a user goes below 1 then gets liquidated
     */
    function _healthFactor(address user) internal view returns (uint256) {
        (uint256 totalCatMinted, uint256 collateralValueInGoldGram) = _getAccountInformation(user);
        uint256 collateralAdjustedForThreshold = (collateralValueInGoldGram * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;

        //with the 50% threshold, menas that we need to have double the collateral than the value of the CAT for minting
        //meaning for each CAT whe need to have 2 gold grams worth of collateral, either BTC or ETH
        return (collateralAdjustedForThreshold*PRECISION/totalCatMinted); //if this is less than 1 you get liquidated

    }

    /**
     * @notice revert if health factor is broken = user has not enough collateral
     * @param user The address of the user
     */
    function _revertIfHealthFactorIsBrokeN(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert CATSEngine__BreakHealthFactor();
        }

    }

    ///////////// Public and External View Functions /////////////

    function getTokenAmountFromGoldGrams(address token, uint256  GoldGramAmountInWe)
    public
    view
    returns (uint256){
        //Example price of ETH (token)
        //GoldGram/ETH ETH?
        //2000GoldGrams/ETH, if we have 1000Goldgrams we have 0.5 eth
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price, , , ) = priceFeed.latestRoundData();
        // (1000$e18*1e18)/($2000e8*1e10) 
        return (GoldGramAmountInWe*PRECISION)/uint256(price)*ADDITIONAL_FEED_PRECISION;
        
    }

    /**
     * @notice loops through all the collateral and returns the total value in gold grams
     * @param user The address of the user
     */
    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInGoldGram) {
        for (uint256 i = 0; i<s_collateralTokens.length; i++){
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInGoldGram +=   getGoldValue(token, amount);
        }
    }

    function getGoldValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price, , , ) = priceFeed.latestRoundData();
        //1ETH = $1000
        //The Returned value from CL will be 1000*1e8
        return (uint256(price)* ADDITIONAL_FEED_PRECISION )* amount / PRECISION; // (1000 * 1e8 * 1e10)= 1000 * 1e18 and all divided by 1e18
    }

}
