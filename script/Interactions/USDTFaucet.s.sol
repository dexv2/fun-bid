// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {AuctionFactory} from "../../src/AuctionFactory.sol";
import {USDTFaucet} from "../../src/USDTFaucet.sol";
import {USDT} from "../../src/USDT.sol";

contract FaucetRequestUSDT is Script {
    function execute(address mostRecentDeployedFaucet, address account) public {
        vm.startBroadcast(account);
        USDTFaucet(mostRecentDeployedFaucet).requestUSDT();
        vm.stopBroadcast();

        console.log(account, "requested USDT");
    }

    function run() external {
        address mostRecentDeployedFaucet = DevOpsTools.get_most_recent_deployment(
            "USDTFaucet", 
            block.chainid
        );

        execute(mostRecentDeployedFaucet, msg.sender);
    }
}
