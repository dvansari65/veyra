// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice Transfers supported, non-rebasing ERC-20s; rejects observable transfer taxes and short delivery.
/// @dev Balance reporting itself is trusted. Arbitrarily malicious/rebasing tokens are not supported.
library ExactTransfer {
    using SafeERC20 for IERC20;
    error InexactTransfer();

    function pull(IERC20 token, address from, address to, uint256 amount) internal {
        if (amount == 0) return;
        uint256 beforeFrom = token.balanceOf(from);
        uint256 beforeTo = token.balanceOf(to);
        token.safeTransferFrom(from, to, amount);
        if (token.balanceOf(from) + amount != beforeFrom || token.balanceOf(to) != beforeTo + amount) {
            revert InexactTransfer();
        }
    }

    function push(IERC20 token, address to, uint256 amount) internal {
        if (amount == 0) return;
        uint256 beforeFrom = token.balanceOf(address(this));
        uint256 beforeTo = token.balanceOf(to);
        token.safeTransfer(to, amount);
        if (token.balanceOf(address(this)) + amount != beforeFrom || token.balanceOf(to) != beforeTo + amount)
        {
            revert InexactTransfer();
        }
    }
}
