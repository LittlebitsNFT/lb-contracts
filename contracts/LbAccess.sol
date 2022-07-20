// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract LbAccess {
    uint internal ACCESS_ADMIN_ROLEID = 99; // role needed to register and confirm roles
    uint internal ACCESS_WAIT_BLOCKS = 200_000; // blocks to wait to confirm a role

    // mapping from account to (from roleId to hasRole)
    mapping(address => mapping(uint => bool)) public hasRole;

    // mapping from account to (from role requested to block requested)
    mapping(address => mapping(uint => uint)) private _roleRequestBlock;

    event AccessRequested(address indexed _address, uint indexed roleId);
    event AccessConfirmed(address indexed _address, uint indexed roleId);
    event AccessRemoved(address indexed _address, uint indexed roleId);

    // register a new address as a role condidate (should be confirmed later)
    function ACCESS_request(address candidate, uint roleId) public {
        require(hasRole[msg.sender][ACCESS_ADMIN_ROLEID], 'Admin only');
        _roleRequestBlock[candidate][roleId] = block.number;
        emit AccessRequested(candidate, roleId);
    }

    // confirm a role candidate (must wait ACCESS_WAIT_BLOCKS after request)
    function ACCESS_confirm(address candidate, uint roleId) public {
        require(hasRole[msg.sender][ACCESS_ADMIN_ROLEID], 'Admin only');
        require(_roleRequestBlock[candidate][roleId] != 0, 'Role intention not registered');
        uint elapsedBlocks = block.number - _roleRequestBlock[candidate][roleId];
        require(elapsedBlocks >= ACCESS_WAIT_BLOCKS, 'More blocks needed before confirmation');
        hasRole[candidate][roleId] = true;
        emit AccessConfirmed(candidate, roleId);
    }

    // removes role from addr (both active and requested)
    function ACCESS_remove(address addr, uint roleId) public {
        require(hasRole[msg.sender][ACCESS_ADMIN_ROLEID], 'Admin only');
        hasRole[addr][roleId] = false;
        _roleRequestBlock[addr][roleId] = 0;
        emit AccessRemoved(addr, roleId);
    }
}
