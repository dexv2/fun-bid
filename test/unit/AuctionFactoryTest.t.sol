// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployAuctionFactory} from "../../script/DeployAuctionFactory.s.sol";
import {AuctionFactory} from "../../src/AuctionFactory.sol";
import {USDTFaucet} from "../../src/USDTFaucet.sol";
import {USDT} from "../../src/USDT.sol";
import {MockAuctioneerContract} from "../mocks/MockAuctioneerContract.sol";
import {MockFailedTransferFrom} from "../mocks/MockFailedTransferFrom.sol";
import {MockFailedMint} from "../mocks/MockFailedMint.sol";

contract AuctionFactoryTest is Test {
    AuctionFactory factory;
    USDTFaucet faucet;
    USDT usdt;

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

    function testRevertsIfTransferFromFails() public {
        uint256 faucetFundAmount = 1_000_000_000_000e18;
        MockFailedTransferFrom mockUsdt = new MockFailedTransferFrom();
        USDTFaucet mockFaucet = new USDTFaucet(address(mockUsdt));
        AuctionFactory mockFactory = new AuctionFactory(address(mockUsdt), address(mockFaucet));

        mockUsdt.mint(address(mockFaucet), faucetFundAmount);
        mockUsdt.transferOwnership(address(mockFactory));

        vm.startPrank(AUCTIONEER, AUCTIONEER);
        mockFaucet.requestUSDT();

        mockUsdt.approve(address(mockFactory), AMOUNT_DEPOSIT);
        
        vm.expectRevert(
            AuctionFactory.AuctionFactory__TransferFromFailed.selector
        );
        mockFactory.openAuction();
        vm.stopPrank();
    }

    function testRevertsIfMintFails() public {
        uint256 faucetFundAmount = 1_000_000_000_000e18;
        MockFailedMint mockUsdt = new MockFailedMint();
        USDTFaucet mockFaucet = new USDTFaucet(address(mockUsdt));
        AuctionFactory mockFactory = new AuctionFactory(address(mockUsdt), address(mockFaucet));

        mockUsdt.mint(address(mockFaucet), faucetFundAmount);
        mockUsdt.transferOwnership(address(mockFactory));

        vm.startPrank(AUCTIONEER, AUCTIONEER);
        mockFaucet.requestUSDT();

        mockUsdt.approve(address(mockFactory), AMOUNT_DEPOSIT);

        vm.expectRevert(
            AuctionFactory.AuctionFactory__MintFailed.selector
        );
        mockFactory.openAuction();
        vm.stopPrank();
    }
}