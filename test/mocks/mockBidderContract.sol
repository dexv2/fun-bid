// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

interface HundredDollarAuction {
    function joinAuction(uint256 amountToBid) external;
}

interface USDTFaucet {
    function requestUSDT() external;
}

interface USDT {
    function approve(address spender, uint256 amount) external;
}

contract Bidder {
    function joinAuction(HundredDollarAuction auction, uint256 amountToBid) external {
        auction.joinAuction(amountToBid);
    }

    function requestUSDT(USDTFaucet faucet) external {
        faucet.requestUSDT();
    }

    function approve(USDT usdt, address spender, uint256 amount) external {
        usdt.approve(spender, amount);
    }
}
