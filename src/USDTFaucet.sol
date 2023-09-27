// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {USDT} from "./USDT.sol";

/**
 * @title USDTFaucet
 * @author Vermont Phil Paguiligan
 * @notice This contract funds users to use the HundredDollarAuction contract as Bidder of Auctioneer
 */
contract USDTFaucet {
    error USDTFaucet__FaucetHasZeroBalance();

    uint256 private constant REQUEST_AMOUNT = 200e18;
    USDT private immutable i_usdt;

    constructor(address usdt) {
        i_usdt = USDT(usdt);
    }

    function requestUSDT() public {
        if (_faucetBalanceUSDT() == 0) {
            revert USDTFaucet__FaucetHasZeroBalance();
        }

        if (_faucetBalanceUSDT() < REQUEST_AMOUNT) {
            i_usdt.transfer(msg.sender, _faucetBalanceUSDT());
        }
        else {
            i_usdt.transfer(msg.sender, REQUEST_AMOUNT);
        }
    }

    function _faucetBalanceUSDT() private view returns (uint256) {
        return i_usdt.balanceOf(address(this));
    }

    function getFaucetBalanceUSDT() public view returns (uint256) {
        return _faucetBalanceUSDT();
    }

    function getUSDTAddress() public view returns (address) {
        return address(i_usdt);
    }

    function getRequestAmount() public pure returns (uint256) {
        return REQUEST_AMOUNT;
    }
}
