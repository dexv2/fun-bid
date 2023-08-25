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

    uint256 private constant MAX_AMOUNT_TO_FUND = 200e18;
    USDT private immutable i_usdt;

    constructor(USDT usdt) {
        i_usdt = usdt;
    }

    function requestUSDT() public {
        if (_balanceUSDT() == 0) {
            revert USDTFaucet__FaucetHasZeroBalance();
        }

        if (_balanceUSDT() < MAX_AMOUNT_TO_FUND) {
            i_usdt.transfer(msg.sender, _balanceUSDT());
        }
        else {
            i_usdt.transfer(msg.sender, MAX_AMOUNT_TO_FUND);
        }
    }

    function _balanceUSDT() private view returns (uint256) {
        return i_usdt.balanceOf(address(this));
    }

    function getBalanceUSDT() public view returns (uint256) {
        return _balanceUSDT();
    }

    function getUSDTAddress() public view returns (address) {
        return address(i_usdt);
    }
}
