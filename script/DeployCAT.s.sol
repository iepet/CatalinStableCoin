//SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {CatalanStableCoin} from "src/CatalanStableCoin.sol";
import {CATSEngine} from "src/CATSEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";


contract DeployCAT is Script {
    address [] public tokenAddresses;
    address [] public priceFeedAddresses;

    function run() external returns (CatalanStableCoin, CATSEngine, HelperConfig){
        HelperConfig config = new HelperConfig();
        (address wethUsdPriceFeed,
        address wbtcUsdPriceFeed,
        address weth,
        address wbtc, 
        uint256 deployerKey) = config.networkConfig();

        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];

        vm.startBroadcast();
        CatalanStableCoin cat = new CatalanStableCoin();
        CATSEngine engine = new CATSEngine(tokenAddresses, priceFeedAddresses, address(cat));

        cat.transferOwnership(address(engine));
        vm.stopBroadcast();
        return(cat, engine, config);   

    }
}