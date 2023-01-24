//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {UserManagerERC20} from "./UserManagerERC20.sol";

contract UserManagerOp is UserManagerERC20 {
    using SafeERC20 for IERC20;

    /**
     *  @dev Register member with a fee and send the fee to the Comptroller
     *  @param newMember New member address
     */
    function registerMember(address newMember) public override whenNotPaused {
        _validateNewMember(newMember);

        IERC20(unionToken).safeTransferFrom(msg.sender, address(comptroller), newMemberFee);

        emit LogRegisterMember(msg.sender, newMember);
    }
}
