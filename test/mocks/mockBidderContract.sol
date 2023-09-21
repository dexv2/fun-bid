// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

interface HundredDollarAuction {
    function joinAuction(uint256 amountToBid) external;
}

interface USDT {
    function approve(address spender, uint256 amount) external;
    function transferFrom(address from, address to, uint256 amount) external;
}

contract Bidder {
    function joinAuction(HundredDollarAuction auction, USDT usdt, uint256 amountToBid) external {
        usdt.transferFrom(msg.sender, address(this), amountToBid);
        usdt.approve(address(auction), amountToBid);
        auction.joinAuction(amountToBid);
    }
}
