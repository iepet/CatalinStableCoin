//SPDX-License-Identifier: MIT

pragma solidity ^0.8.26; 

import {Test} from "forge-std/Test.sol";
import {CatalanStableCoin} from "src/CatalanStableCoin.sol";
import {CATSEngine} from "src/CATSEngine.sol";
import {DeployCAT} from "script/DeployCAT.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {console} from "forge-std/console.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract CATSEngineTest is Test {
    DeployCAT deployCAT;
    CatalanStableCoin cat;
    CATSEngine engine;
    HelperConfig config;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address wbtc;
    address weth;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    modifier depositedCollateral(){
       vm.startPrank(USER);
       ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
       engine.depositCollateral(weth, AMOUNT_COLLATERAL);
       vm.stopPrank();
       _;
    }


    function setUp()  public {
        deployCAT = new DeployCAT();
        (cat, engine, config) = deployCAT.run();
        (ethUsdPriceFeed,btcUsdPriceFeed,weth,wbtc,)=config.networkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    /////////// CONSTRUCTOR TESTS///////////
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;
    
    function  testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert( CATSEngine.CATSEngine__ArrayLengthMismatch.selector);
        new CATSEngine(tokenAddresses, priceFeedAddresses,address(cat));

    }

    /////////// PRICE TESTS///////////

    function testGetUsdValue() view public {
        uint256 ethAmount = 15e18;
        console.log("Testing i am here sdfjklashdflajshdfashf ashdf alshf aslfh aslkfhaslkdfhalskdfhalsk dfhalskd fhalsdfhalsdfhalskdfaskld fasldfhalskhdfkasdhf");
        //15e18 *2000/ETH = 30000e18 
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = engine.getGoldValue(weth, ethAmount);
        console.log("actual Usd", actualUsd);
        assertEq(expectedUsd, actualUsd);
    }

    function testGetTokenAmountFromGoldGram () public{
        uint256 goldAmount = 100 ether;
        //If i have 100 gold grams, and 2000 gold grams 1 eth, then i should have 0.05 eth
        uint256 expectedWeth = 0.05 ether;

        uint256 actualWeth = engine.getTokenAmountFromGoldGrams(weth, goldAmount);
        assertEq(expectedWeth, actualWeth);

    }

    ///////// Deposit Collateral TESTS //////////

    function testRevertsIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        vm.expectRevert(CATSEngine.CATSEngine__MustBeGreaterThanZero.selector);
        engine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock randToken = new ERC20Mock("RAN", "RAN", USER, 100e18);
        vm.startPrank(USER);
        vm.expectRevert(abi.encodeWithSelector(CATSEngine.CATSEngine__NotAllowedToken.selector, address(randToken)));
        engine.depositCollateral(address(randToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testCanDepositedCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInGold) = engine.getAccountInformation(USER);
        uint256 expectedDepositedAmount = engine.getTokenAmountFromGoldGrams(weth, collateralValueInGold);
        assertEq(totalDscMinted, 0);
        assertEq(expectedDepositedAmount, AMOUNT_COLLATERAL);
    }

    

}

