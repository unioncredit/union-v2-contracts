//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IOvmL2CrossDomainMessenger {
    function xDomainMessageSender() external returns (address);
}

contract OpOwner {
    address private _owner;
    address private _admin;
    address private _pendingOwner;
    address private _pendingAdmin;

    IOvmL2CrossDomainMessenger private ovmL2CrossDomainMessenger;

    error SenderNotPendingAdmin();
    error SenderNotPendingOwner();
    error AddressNotZero();

    event CallExecuted(address target, uint256 value, bytes data);

    modifier onlyAuth() {
        require(
            msg.sender == admin() ||
                (msg.sender == address(ovmL2CrossDomainMessenger) &&
                    ovmL2CrossDomainMessenger.xDomainMessageSender() == owner())
        );
        _;
    }

    constructor(address admin_, address owner_, IOvmL2CrossDomainMessenger ovmL2CrossDomainMessenger_) {
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

    function pendingOwner() public view returns (address) {
        return _pendingOwner;
    }

    function pendingAdmin() public view returns (address) {
        return _pendingAdmin;
    }

    function setPendingOwner(address newOwner) public onlyAuth {
        if (newOwner == address(0)) revert AddressNotZero();
        _pendingOwner = newOwner;
    }

    function setPendingAdmin(address newAdmin) public onlyAuth {
        if (newAdmin == address(0)) revert AddressNotZero();
        _pendingAdmin = newAdmin;
    }

    function acceptOwner() public {
        if (_pendingOwner != msg.sender) revert SenderNotPendingOwner();
        _owner = _pendingOwner;
        _pendingOwner = address(0);
    }

    function acceptAdmin() public {
        if (_pendingAdmin != msg.sender) revert SenderNotPendingAdmin();
        _admin = _pendingAdmin;
        _pendingAdmin = address(0);
    }

    function execute(address target, uint256 value, bytes calldata data) public payable onlyAuth {
        (bool success, ) = target.call{value: value}(data);
        require(success, "underlying transaction reverted");

        emit CallExecuted(target, value, data);
    }
}
