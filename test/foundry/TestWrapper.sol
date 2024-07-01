pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AssetManagerMock} from "union-v2-contracts/mocks/AssetManagerMock.sol";
import {AdapterMock} from "union-v2-contracts/mocks/AdapterMock.sol";
import {UnionTokenMock} from "union-v2-contracts/mocks/UnionTokenMock.sol";
import {FaucetERC20} from "union-v2-contracts/mocks/FaucetERC20.sol";
import {ComptrollerMock} from "union-v2-contracts/mocks/ComptrollerMock.sol";
import {UTokenMock} from "union-v2-contracts/mocks/UTokenMock.sol";
import {MarketRegistryMock} from "union-v2-contracts/mocks/MarketRegistryMock.sol";
import {UserManagerMock} from "union-v2-contracts/mocks/UserManagerMock.sol";
import {FixedInterestRateModelMock} from "union-v2-contracts/mocks/FixedInterestRateModelMock.sol";
import {console} from "forge-std/console.sol";

contract TestWrapper is Test {
    AssetManagerMock public assetManagerMock;
    AdapterMock public adapterMock;
    UnionTokenMock public unionTokenMock;
    FaucetERC20 public erc20Mock;
    ComptrollerMock public comptrollerMock;
    UTokenMock public uTokenMock;
    MarketRegistryMock public marketRegistryMock;
    UserManagerMock public userManagerMock;
    FixedInterestRateModelMock public interestRateMock;
    uint8 public tokenDecimals = uint8(vm.envOr("DECIMALS", uint256(18)));
    uint256 public UNIT = 10 ** tokenDecimals;

    // constructor() {
    //     tokenDecimals = uint8(vm.envOr("DECIMALS", uint256(18)));
    //     UNIT = 10 ** tokenDecimals;
    //     console.log("DECIMALS: %s, UNIT: %s", tokenDecimals, UNIT);
    // }

    function deployProxy(address implementation, bytes memory signature) public returns (address) {
        ERC1967Proxy proxy = new ERC1967Proxy(implementation, signature);
        return address(proxy);
    }

    function deployMocks() public {
        assetManagerMock = new AssetManagerMock();
        adapterMock = new AdapterMock();
        unionTokenMock = new UnionTokenMock("UnionMock", "UNM");
        erc20Mock = new FaucetERC20("MockERc20)", "MERC20");
        erc20Mock.setDecimals(tokenDecimals);
        comptrollerMock = new ComptrollerMock();
        uTokenMock = new UTokenMock();
        marketRegistryMock = new MarketRegistryMock();
        userManagerMock = new UserManagerMock(address(erc20Mock));
        uint256 borrowInterestPerBlock = 0.000001 ether; //0.0001%
        interestRateMock = new FixedInterestRateModelMock(borrowInterestPerBlock);
    }
}
