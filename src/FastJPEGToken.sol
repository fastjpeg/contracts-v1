// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console } from "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";

contract FastJPEGToken is ERC20, Ownable, ERC20Capped {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) ERC20Capped(1_000_000_000 * 1e18) {
        // Initialize with zero supply, tokens will be minted as needed
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
    // Override _mint to satisfy both ERC20 and ERC20Capped

    function _mint(address account, uint256 amount) internal override(ERC20, ERC20Capped) {
        super._mint(account, amount);
    }
}
