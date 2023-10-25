// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployAuctionFactory} from "../../script/DeployAuctionFactory.s.sol";
import {HundredDollarAuction} from "../../src/HundredDollarAuction.sol";
import {AuctionFactory} from "../../src/AuctionFactory.sol";
import {USDT} from "../../src/USDT.sol";
import {Handler} from "./Handler.t.sol";

/**
 * Invariants:
 * 
 * State not yet ended:
 * Auction Contract balance should always be equal to total bids + auction price + deposit amount
 * 
 * State is ended:
 * Auction Contract balance should always be equal to total amount withdrawables
 */

contract InvariantsTest is StdInvariant, Test {
    DeployAuctionFactory deployer;
    AuctionFactory factory;
    HundredDollarAuction auction;
    USDT usdt;
    Handler handler;
    address public AUCTIONEER = makeAddr("auctioneer");
    uint256 private constant AMOUNT_DEPOSIT = 10e18;

    function setUp() public {
        deployer = new DeployAuctionFactory();
        (factory, usdt, ) = deployer.run();

        vm.prank(address(factory));
        usdt.mint(AUCTIONEER, AMOUNT_DEPOSIT);

        vm.startPrank(AUCTIONEER, AUCTIONEER);
        usdt.approve(address(factory), AMOUNT_DEPOSIT);
        auction = HundredDollarAuction(factory.openAuction());
        vm.stopPrank();

        handler = new Handler(factory, usdt, auction, AUCTIONEER);
        targetContract(address(handler));
    }

    function invariant_auctionBalanceShouldEqualTheDesiredAmount() public view {

    }
}