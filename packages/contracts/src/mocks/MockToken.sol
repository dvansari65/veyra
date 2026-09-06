// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice TEST ONLY: unrestricted minting, no relation to real USDC or wrapped HYPE.
contract MockToken is ERC20 {
    uint8 private immutable tokenDecimals;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        tokenDecimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return tokenDecimals;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
