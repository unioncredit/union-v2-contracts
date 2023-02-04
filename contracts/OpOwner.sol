//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IOvmL2CrossDomainMessenger {
    function xDomainMessageSender() external returns (address);
}

contract OpOwner {
    address private _owner;
    address private _admin;
    IOvmL2CrossDomainMessenger private ovmL2CrossDomainMessenger;

    event CallExecuted(address target, uint256 value, bytes data);

    modifier onlyAuth() {
        require(
            msg.sender == admin() ||
                (msg.sender == address(ovmL2CrossDomainMessenger) &&
                    ovmL2CrossDomainMessenger.xDomainMessageSender() == owner())
        );
        _;
    }

    constructor(
        address admin_,
        address owner_,
        IOvmL2CrossDomainMessenger ovmL2CrossDomainMessenger_
    ) {
        _owner = owner_;
        _admin = admin_;
        ovmL2CrossDomainMessenger = ovmL2CrossDomainMessenger_;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function admin() public view returns (address) {
        return _admin;
    }

    function transferOwnership(address newOwner) public onlyAuth {
        _owner = newOwner;
    }

    function transferAdmin(address newAdmin) public onlyAuth {
        _admin = newAdmin;
    }

    function execute(
        address target,
        uint256 value,
        bytes calldata data
    ) public payable onlyAuth {
        (bool success, ) = target.call{value: value}(data);
        require(success, "underlying transaction reverted");

        emit CallExecuted(target, value, data);
    }
}
