//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {SafeCastUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import {UserManager} from "./UserManager.sol";
import {IDai} from "../interfaces/IDai.sol";

contract UserManagerDAI is UserManager {
    using SafeCastUpgradeable for uint256;

    /**
     *  @dev Stake using DAI permit
     *  @param amount Amount to stake
     *  @param nonce Nonce
     *  @param expiry Timestamp for when the permit expires
     *  @param v secp256k1 signature part
     *  @param r secp256k1 signature part
     *  @param s secp256k1 signature part
     */
    function stakeWithPermit(
        uint256 amount,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external whenNotPaused {
        IDai erc20Token = IDai(stakingToken);
        erc20Token.permit(msg.sender, address(this), nonce, expiry, true, v, r, s);

        stake(amount.toUint96());
    }
}
