//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {MarketRegistry} from "../market/MarketRegistry.sol";

contract MarketRegistryMock is MarketRegistry {
    constructor() {
        //admin = msg.sender;
    }
}
