pragma solidity ^0.8.0;

import {TestWrapper} from "./TestWrapper.sol";
import {UUPSProxy} from "union-v1.5-contracts/UUPSProxy.sol";

contract TestDelegate {
    function test() public view returns (string memory) {
        return "testing";
    }
}

contract TestUUPSProxy is TestWrapper {
    function testUUPSProxyDelegates() public {
        TestDelegate logic = new TestDelegate();
        UUPSProxy proxy = new UUPSProxy(address(logic), address(0), "");
        string memory resp = TestDelegate(address(proxy)).test();
        assertEq(resp, "testing");
    }
}
