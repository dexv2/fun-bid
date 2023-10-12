// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployAuctionFactory} from "../../script/DeployAuctionFactory.s.sol";
import {FactoryOpenAuction} from "../../script/Interactions/AuctionFactory.s.sol";
import {JoinAuction, OutbidAuction, ForfeitAuction, CancelAuction, EndAuction, WithdrawAuction} from "../../script/Interactions/HundredDollarAuction.s.sol";
import {FaucetRequestUSDT} from "../../script/Interactions/USDTFaucet.s.sol";
import {HundredDollarAuction} from "../../src/HundredDollarAuction.sol";
import {AuctionFactory} from "../../src/AuctionFactory.sol";
import {USDTFaucet} from "../../src/USDTFaucet.sol";
import {USDT} from "../../src/USDT.sol";

contract HundredDollarAuctionTestIntegrations is Test {
    AuctionFactory factory;
    USDTFaucet faucet;
    USDT usdt;
    HundredDollarAuction auction;

    // We will set ALICE as first bidder
    address public ALICE = makeAddr("alice");
    // We will set BILLY as second bidder
    address public BILLY = makeAddr("billy");
    address public CINDY = makeAddr("cindy");
    address public AUCTIONEER = makeAddr("auctioneer");
    uint256 private constant AUCTION_PRICE = 100e18;
    uint256 private constant FIRST_BID_AMOUNT = 1e18;
    uint256 private constant SECOND_BID_AMOUNT = 5e18;
    uint256 private constant MINIMUM_BID_AMOUNT = 1e18;

    function setUp() public {
        DeployAuctionFactory deployer = new DeployAuctionFactory();
        (factory, usdt, faucet) = deployer.run();

        FaucetRequestUSDT requestUsdt = new FaucetRequestUSDT();
        FactoryOpenAuction openAuction = new FactoryOpenAuction();

        // fund users to test
        requestUsdt.execute(address(faucet), ALICE);
        requestUsdt.execute(address(faucet), BILLY);
        requestUsdt.execute(address(faucet), CINDY);
        requestUsdt.execute(address(faucet), AUCTIONEER);

        // create auction
        openAuction.execute(address(factory), address(faucet), address(usdt), AUCTIONEER);
    }
}
