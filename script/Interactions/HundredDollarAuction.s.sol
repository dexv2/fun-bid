// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {HundredDollarAuction} from "../../src/HundredDollarAuction.sol";
import {USDT} from "../../src/USDT.sol";

contract JoinAuction is Script {
    function execute(
        address auction,
        uint256 amountToBid,
        address usdt,
        address account
    ) public {
        vm.startBroadcast(account);
        USDT(usdt).approve(address(auction), amountToBid);
        HundredDollarAuction(auction).joinAuction(amountToBid);
        vm.stopBroadcast();

        console.log(account, "joined with bid amount:", amountToBid);
    }
}

contract OutbidAuction is Script {
    function execute(
        address auction,
        uint256 bidIncrement,
        address usdt,
        address account
    ) public {
        vm.startBroadcast(account);
        USDT(usdt).approve(address(auction), bidIncrement);
        HundredDollarAuction(auction).outbid(bidIncrement);
        vm.stopBroadcast();

        console.log(account, "outbid with amount:", bidIncrement);
    }
}

contract ForfeitAuction is Script {
    function execute(
        address auction,
        address account
    ) public {
        vm.startBroadcast(account);
        HundredDollarAuction(auction).forfeit();
        vm.stopBroadcast();

        console.log(account, "forfeited");
    }
}

contract CancelAuction is Script {
    function execute(
        address auction,
        address account
    ) public {
        vm.startBroadcast(account);
        HundredDollarAuction(auction).cancelAuction();
        vm.stopBroadcast();

        console.log(account, "cancelled the auction");
    }
}

contract EndAuction is Script {
    function execute(
        address auction,
        address account
    ) public {
        vm.startBroadcast(account);
        HundredDollarAuction(auction).endAuction();
        vm.stopBroadcast();

        console.log(account, "ended the auction");
    }
}

contract WithdrawAuction is Script {
    function execute(
        address auction,
        address account
    ) public {
        vm.startBroadcast(account);
        HundredDollarAuction(auction).withdraw();
        vm.stopBroadcast();

        console.log(account, "withdrawn their winning amount");
    }
}
