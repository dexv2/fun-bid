// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract USDTest is ERC20, Ownable {
    error USDTest__NotZeroAddress();
    error USDTest__MustBeMoreThanZero();

    constructor() ERC20("USDTest", "USDT") {}

    function mint(address to, uint256 amount) public onlyOwner returns (bool) {
        if (to == address(0)) {
            revert USDTest__NotZeroAddress();
        }
        if (amount == 0) {
            revert USDTest__MustBeMoreThanZero();
        }
        _mint(to, amount);
        return true;
    }
}
