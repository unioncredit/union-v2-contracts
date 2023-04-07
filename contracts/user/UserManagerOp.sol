//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {iOVM_L1BlockNumber} from "@eth-optimism/contracts/L2/predeploys/iOVM_L1BlockNumber.sol";
import {Lib_PredeployAddresses} from "@eth-optimism/contracts/libraries/constants/Lib_PredeployAddresses.sol";
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

    /**
     *  @dev Function to retrieve L1 block number
     *  Use L1 block time to get a consistent behavior between L1 and L2
     */
    function getBlockNumber() internal view override returns (uint256) {
        return
            iOVM_L1BlockNumber(
                Lib_PredeployAddresses.L1_BLOCK_NUMBER // located at 0x4200000000000000000000000000000000000013
            ).getL1BlockNumber();
    }
}
