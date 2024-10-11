//SPDX-License-Identifier: MIT 

pragma solidity ^0.8.26; 

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract HelperConfig is Script {
    struct  NetworkConfig{
        address wethUsdPriceFeed;
        address wbtcUsdPriceFeed;
        address weth;
        address wbtc;
        uint256 deployerKey;
    }

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 40000e8;
    uint256 public DEFAULT_ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    
    NetworkConfig public networkConfig;
    constructor(){
        if (block.chainid == 11155111){
            networkConfig = getSepoliasConfig();  
        }else{
            networkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliasConfig() public view returns(NetworkConfig memory){
        return NetworkConfig({
            wethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            wbtcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            weth: 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9,
            wbtc: 0xFF82bB6DB46Ad45F017e2Dfb478102C7671B13b3,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory){
    
        vm.startBroadcast();
        MockV3Aggregator wethUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        ERC20Mock wethMock = new ERC20Mock("Wrapped Ether", "WETH",msg.sender,1000e8);
        MockV3Aggregator wbtcUsdPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);
        ERC20Mock wbtcMock = new ERC20Mock("Wrapped Bitcoin", "WBTC",msg.sender,1000e8);
        vm.stopBroadcast();

        return NetworkConfig({
            wethUsdPriceFeed: address(wethUsdPriceFeed),
            wbtcUsdPriceFeed: address(wbtcUsdPriceFeed),
            weth: address(wethMock),
            wbtc: address(wbtcMock),
            deployerKey: DEFAULT_ANVIL_KEY
        });
    }
}