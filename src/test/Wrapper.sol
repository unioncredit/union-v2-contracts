pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../interfaces/IUToken.sol";
import "../interfaces/IUserManager.sol";
import "../interfaces/IAssetManager.sol";
import "../interfaces/IInterestRateModel.sol";
import "../interfaces/IUnionToken.sol";
import "../interfaces/IComptroller.sol";

contract TestWrapper is Test {
    IUToken public uToken;
    IUserManager public userManager;
    IAssetManager public assetManager;
    IInterestRateModel public interestRateModel;
    IUnionToken public unionToken;
    IComptroller public comptroller;

    function setUp() public {}
}
