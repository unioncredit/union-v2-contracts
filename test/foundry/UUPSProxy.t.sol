pragma solidity ^0.8.0;

import {TestWrapper} from "./TestWrapper.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract TestDelegate {
    function test() public view returns (string memory) {
        return "testing";
    }
}

contract TestUUPSProxy is TestWrapper {
    function testUUPSProxyDelegates() public {
        TestDelegate logic = new TestDelegate();
        ERC1967Proxy proxy = new ERC1967Proxy(address(logic), "");
        string memory resp = TestDelegate(address(proxy)).test();
        assertEq(resp, "testing");
    }
}
