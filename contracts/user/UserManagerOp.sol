//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import {UserManagerERC20} from "./UserManagerERC20.sol";

contract UserManagerOp is UserManagerERC20 {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /**
     *  @dev Register member with a fee and send the fee to the Comptroller
     *  @param newMember New member address
     */
    function registerMember(address newMember) public override whenNotPaused {
        _validateNewMember(newMember);

        IERC20Upgradeable(unionToken).safeTransferFrom(msg.sender, address(comptroller), newMemberFee);

        emit LogRegisterMember(msg.sender, newMember);
    }
}
