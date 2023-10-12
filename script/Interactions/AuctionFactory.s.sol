// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {AuctionFactory} from "../../src/AuctionFactory.sol";
import {USDTFaucet} from "../../src/USDTFaucet.sol";
import {USDT} from "../../src/USDT.sol";

contract FactoryOpenAuction is Script {
    function execute(
        address mostRecentDeployedFactory,
        address mostRecentDeployedFaucet,
        address mostRecentDeployedUSDT
    ) public returns (address) {
        uint256 amountDeposit = 10e18;

        vm.startBroadcast();
        USDTFaucet(mostRecentDeployedFaucet).requestUSDT();
        USDT(mostRecentDeployedUSDT).approve(mostRecentDeployedFactory, amountDeposit);
        address auction = AuctionFactory(mostRecentDeployedFactory).openAuction();
        vm.stopBroadcast();

        console.log("Auction deployed at address:", auction);
        return auction;
    }

    function run() external {
        address mostRecentDeployedFactory = DevOpsTools.get_most_recent_deployment(
            "AuctionFactory", 
            block.chainid
        );
        address mostRecentDeployedFaucet = DevOpsTools.get_most_recent_deployment(
            "USDTFaucet", 
            block.chainid
        );
        address mostRecentDeployedUSDT = DevOpsTools.get_most_recent_deployment(
            "USDT", 
            block.chainid
        );

        execute(
            mostRecentDeployedFactory,
            mostRecentDeployedFaucet,
            mostRecentDeployedUSDT
        );
    }
}
