// SPDX-License-Identifier: MIT

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

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
/*
 * @title CatalanStableCoin
 * @author Iepet 
 * Collateral: Exogenous
 * Minting (Stability Mechanism): Decentralized (Algorithmic)
 * Value (Relative Stability): Anchored (Pegged to ???)
 * Collateral Type: wEth wBTC
 *
* This is the contract meant to be owned by DSCEngine. It is a ERC20 token that can be minted and burned by the
DSCEngine smart contract.
 */

contract CatalanStableCoin is ERC20, Ownable, ERC20Burnable {
    // version
    string public version = "0.0.1";

    // errors
    error CatalanStableCoin__MustBeGreaterThanZero();
    error CatalanStableCoin__BurnAmountExceedsBalance();
    error CatalanStableCoin__Not0Address();

    // constructor
    constructor() ERC20("CatalanStableCoin", "DSC") {}

    // external
    function mint(address _to, uint256 amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert CatalanStableCoin__Not0Address();
        }
        if (amount <= 0) {
            revert CatalanStableCoin__MustBeGreaterThanZero();
        }
        _mint(_to, amount);
        return true;
    }

    // public
    function burn(uint256 amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (amount <= 0) {
            revert CatalanStableCoin__MustBeGreaterThanZero();
        }
        if (balance <= amount) {
            revert CatalanStableCoin__BurnAmountExceedsBalance();
        }
        super.burn(amount);
    }

    // view & pure functions
}
