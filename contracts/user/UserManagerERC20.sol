//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {SafeCastUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import {UserManager} from "./UserManager.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";

contract UserManagerERC20 is UserManager {
    using SafeCastUpgradeable for uint256;

    /**
     *  @dev Stake using ERC20 permit
     *  @param amount Amount
     *  @param deadline Timestamp for when the permit expires
     *  @param v secp256k1 signature part
     *  @param r secp256k1 signature part
     *  @param s secp256k1 signature part
     */
    function stakeWithERC20Permit(
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external whenNotPaused {
        IERC20Permit erc20Token = IERC20Permit(stakingToken);
        erc20Token.permit(msg.sender, address(this), amount, deadline, v, r, s);

        stake(amount.toUint96());
    }
}
