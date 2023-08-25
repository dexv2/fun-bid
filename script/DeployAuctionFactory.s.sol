// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {Script} from "forge-std/Script.sol";
import {AuctionFactory} from "../src/AuctionFactory.sol";
import {USDTest} from "../src/USDTest.sol";
import {USDTestFaucet} from "../src/USDTestFaucet.sol";

contract DeployAuctionFactory is Script {
    function run() public returns (AuctionFactory, USDTest, USDTestFaucet) {
        uint256 faucetFundAmount = 1_000_000_000_000e18;
        vm.startBroadcast();
        USDTest usdt = new USDTest();
        USDTestFaucet faucet = new USDTestFaucet(usdt);
        AuctionFactory factory = new AuctionFactory(usdt, address(faucet));

        usdt.mint(address(faucet), faucetFundAmount);
        usdt.transferOwnership(address(factory));
        vm.stopBroadcast();

        return (factory, usdt, faucet);
    }
}
