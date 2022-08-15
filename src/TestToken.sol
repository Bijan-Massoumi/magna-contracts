// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor(
        address to,
        address contractAllowance,
        uint256 amount
    ) ERC20("test", "test") {
        _mint(to, amount);
        approve(contractAllowance, amount);
    }
}
