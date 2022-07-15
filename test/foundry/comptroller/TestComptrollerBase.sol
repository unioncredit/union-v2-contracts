pragma solidity ^0.8.0;

import {TestWrapper} from "../TestWrapper.sol";
import {Comptroller} from "union-v1.5-contracts/token/Comptroller.sol";

contract TestComptrollerBase is TestWrapper {
    Comptroller public comptroller;

    function setUp() public virtual {
        address logic = address(new Comptroller());

        deployMocks();

        uint256 halfDecayPoint = 1_000_000 ether;

        comptroller = Comptroller(
            deployProxy(
                logic,
                abi.encodeWithSignature(
                    "__Comptroller_init(address,address,uint256)",
                    unionTokenMock,
                    marketRegistryMock,
                    halfDecayPoint
                )
            )
        );
    }
}
