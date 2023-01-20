//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IOvmL2CrossDomainMessenger {
    function xDomainMessageSender() external returns (address);
}

contract OpOwner {
    address private _owner;
    IOvmL2CrossDomainMessenger private ovmL2CrossDomainMessenger;

    event CallExecuted(address target, uint256 value, bytes data);

    modifier onlyOwner() {
        require(
            msg.sender == address(ovmL2CrossDomainMessenger) &&
                ovmL2CrossDomainMessenger.xDomainMessageSender() == owner()
        );
        _;
    }

    constructor(address owner_, IOvmL2CrossDomainMessenger ovmL2CrossDomainMessenger_) {
        _owner = owner_;
        ovmL2CrossDomainMessenger = ovmL2CrossDomainMessenger_;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        _owner = newOwner;
    }

    function execute(
        address target,
        uint256 value,
        bytes calldata data
    ) public payable onlyOwner {
        (bool success, ) = target.call{value: value}(data);
        require(success, "underlying transaction reverted");

        emit CallExecuted(target, value, data);
    }
}
