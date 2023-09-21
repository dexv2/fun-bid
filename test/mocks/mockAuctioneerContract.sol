// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

interface AuctionFactory {
    function openAuction() external returns (address);
}

interface USDT {
    function approve(address spender, uint256 amount) external;
    function transferFrom(address from, address to, uint256 amount) external;
}

contract MockAuctioneerContract {
    function openAuction(address factory, address usdt) external returns (address) {
        uint256 depositAmount = 10e18;
        USDT(usdt).transferFrom(msg.sender, address(this), depositAmount);
        USDT(usdt).approve(address(factory), depositAmount);
        return AuctionFactory(factory).openAuction();
    }
}
