// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {USDTest} from "./USDTest.sol";

/**
 * @title USDTestFaucet
 * @author Vermont Phil Paguiligan
 * @notice This contract funds users to use the HundredDollarAuction contract as Bidder of Auctioneer
 */
contract USDTestFaucet {
    error USDTestFaucet__FaucetHasZeroBalance();

    uint256 private constant MAX_AMOUNT_TO_FUND = 100e18;
    USDTest private immutable i_usdt;

    constructor(USDTest usdt) {
        i_usdt = usdt;
    }

    function requestUSDTest() public {
        if (_balanceUSDT() == 0) {
            revert USDTestFaucet__FaucetHasZeroBalance();
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
