// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployAuctionFactory} from "../../script/DeployAuctionFactory.s.sol";
import {AuctionFactory} from "../../src/AuctionFactory.sol";
import {HundredDollarAuction} from "../../src/HundredDollarAuction.sol";
import {USDTFaucet} from "../../src/USDTFaucet.sol";
import {USDT} from "../../src/USDT.sol";
import {MockBidderContract} from "../mocks/MockBidderContract.sol";
import {MockAuctioneerContract} from "../mocks/MockAuctioneerContract.sol";
import {MockFailedTransfer} from "../mocks/MockFailedTransfer.sol";
import {MockFailedTransferFrom} from "../mocks/MockFailedTransferFrom.sol";

// Auction Contract balance should be 0 after the auction ends
contract AuctionFactoryTest is Test {
    AuctionFactory factory;
    USDTFaucet faucet;
    USDT usdt;
    HundredDollarAuction auction;

    address public AUCTIONEER = makeAddr("auctioneer");
    uint256 private constant AMOUNT_DEPOSIT = 10e18;

    function setUp() public {
        DeployAuctionFactory deployer = new DeployAuctionFactory();
        (factory, usdt, faucet) = deployer.run();

        // fund users to test
        vm.prank(AUCTIONEER, AUCTIONEER);
        faucet.requestUSDT();
    }

    function testCannotBeAnAuctioneerIfNotEOA() public {
        vm.startPrank(AUCTIONEER, AUCTIONEER);
        MockAuctioneerContract mockAuctioneerContract = new MockAuctioneerContract();
        usdt.approve(address(mockAuctioneerContract), AMOUNT_DEPOSIT);
        vm.expectRevert(
            AuctionFactory.AuctionFactory__NotEOA.selector
        );
        mockAuctioneerContract.openAuction(address(factory), address(usdt));
        vm.stopPrank();
    }
}