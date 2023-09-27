// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract USDT is ERC20, Ownable {
    error USDT__NotZeroAddress();
    error USDT__MustBeMoreThanZero();

    constructor() ERC20("USDTest", "USDT") {}

    function mint(address to, uint256 amount) public onlyOwner returns (bool) {
        if (to == address(0)) {
            revert USDT__NotZeroAddress();
        }
        if (amount == 0) {
            revert USDT__MustBeMoreThanZero();
        }
        _mint(to, amount);
        return true;
    }
}
