// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {AuctionFactory} from "../../src/AuctionFactory.sol";
import {USDTFaucet} from "../../src/USDTFaucet.sol";
import {USDT} from "../../src/USDT.sol";
import {HundredDollarAuction} from "../../src/HundredDollarAuction.sol";

contract JoinAuction is Script {
    function execute(
        address auction,
        uint256 amountToBid
    ) public {
        vm.startBroadcast();
        HundredDollarAuction(auction).joinAuction(amountToBid);
        vm.stopBroadcast();

        console.log(msg.sender, "joined with bid amount:", amountToBid);
    }
}

contract OutbidAuction is Script {
    function execute(
        address auction,
        uint256 bidIncrement
    ) public {
        vm.startBroadcast();
        HundredDollarAuction(auction).outbid(bidIncrement);
        vm.stopBroadcast();

        console.log(msg.sender, "outbid with amount:", bidIncrement);
    }
}

contract ForfeitAuction is Script {
    function execute(
        address auction
    ) public {
        vm.startBroadcast();
        HundredDollarAuction(auction).forfeit();
        vm.stopBroadcast();

        console.log(msg.sender, "forfeited");
    }
}

contract CancelAuction is Script {
    function execute(
        address auction
    ) public {
        vm.startBroadcast();
        HundredDollarAuction(auction).cancelAuction();
        vm.stopBroadcast();

        console.log(msg.sender, "cancelled the auction");
    }
}

contract EndAuction is Script {
    function execute(
        address auction
    ) public {
        vm.startBroadcast();
        HundredDollarAuction(auction).endAuction();
        vm.stopBroadcast();

        console.log(msg.sender, "ended the auction");
    }
}

contract WithdrawAuction is Script {
    function execute(
        address auction
    ) public {
        vm.startBroadcast();
        HundredDollarAuction(auction).withdraw();
        vm.stopBroadcast();

        console.log(msg.sender, "withdrawn their winning amount");
    }
}
