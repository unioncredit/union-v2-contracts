//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {iOVM_L1BlockNumber} from "@eth-optimism/contracts/L2/predeploys/iOVM_L1BlockNumber.sol";
import {Lib_PredeployAddresses} from "@eth-optimism/contracts/libraries/constants/Lib_PredeployAddresses.sol";
import {Comptroller} from "./Comptroller.sol";

contract ComptrollerOp is Comptroller {
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
