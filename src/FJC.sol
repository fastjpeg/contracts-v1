// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console } from "forge-std/console.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Capped.sol";

contract FJC is ERC20, Ownable, ERC20Capped {
    constructor(string memory name, string memory symbol)
        ERC20(name, symbol)
        ERC20Capped(1_000_000_000 * 1e18)
        Ownable(msg.sender)
    {
        // Initialize with zero supply, tokens will be minted as needed
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Capped) {
        super._update(from, to, value);
    }
}
