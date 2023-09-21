// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

interface HundredDollarAuction {
    function joinAuction(uint256 amountToBid) external;
}

interface USDT {
    function approve(address spender, uint256 amount) external;
    function transferFrom(address from, address to, uint256 amount) external;
}

contract MockBidderContract {
    function joinAuction(address auction, address usdt, uint256 amountToBid) external {
        USDT(usdt).transferFrom(msg.sender, address(this), amountToBid);
        USDT(usdt).approve(address(auction), amountToBid);
        HundredDollarAuction(auction).joinAuction(amountToBid);
    }
}
