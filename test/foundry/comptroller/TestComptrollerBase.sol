pragma solidity ^0.8.0;

import {TestWrapper} from "../TestWrapper.sol";
import {Comptroller} from "union-v2-contracts/token/Comptroller.sol";

contract ComptrollerInternals is Comptroller {
    function getInflationIndex(
        uint256 effectiveAmount,
        uint256 inflationIndex,
        uint256 blockDelta
    ) public view returns (uint256) {
        return _getInflationIndex(effectiveAmount, inflationIndex, blockDelta);
    }

    function lookup(uint256 index) public pure returns (uint256) {
        return _lookup(index);
    }
}

contract TestComptrollerBase is TestWrapper {
    Comptroller public comptroller;
    ComptrollerInternals public comptrollerInternals;

    uint256 public halfDecayPoint = 1000000;

    function setUp() public virtual {
        address logic = address(new Comptroller());

        deployMocks();

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

    function deployComtrollerExposedInternals() public {
        address logic = address(new ComptrollerInternals());

        comptrollerInternals = ComptrollerInternals(
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
