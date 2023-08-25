// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {Script} from "forge-std/Script.sol";
import {AuctionFactory} from "../src/AuctionFactory.sol";
import {USDT} from "../src/USDT.sol";
import {USDTFaucet} from "../src/USDTFaucet.sol";

contract DeployAuctionFactory is Script {
    function run() public returns (AuctionFactory, USDT, USDTFaucet) {
        uint256 faucetFundAmount = 1_000_000_000_000e18;
        vm.startBroadcast();
        USDT usdt = new USDT();
        USDTFaucet faucet = new USDTFaucet(usdt);
        AuctionFactory factory = new AuctionFactory(usdt, address(faucet));

        usdt.mint(address(faucet), faucetFundAmount);
        usdt.transferOwnership(address(factory));
        vm.stopBroadcast();

        return (factory, usdt, faucet);
    }
}
