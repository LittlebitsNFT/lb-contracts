// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/**
 * @title LbBank contract
 * @author gifMaker - contact@littlebits.club
 * @notice v1.00 / 2022
 * @dev Littlebits Bank
 */

import "./LittlebucksTKN.sol";

// access requirements:
// must be TRANSFERER and MINTER on LittlebucksTKN

contract LbBank is LbAccess {
    // allow start work
    bool public isOpen = true; // todo: start false
    bool public pausedForever = false;

    // access roles
    uint public constant ADMIN_ROLE = 99;

    // interest per week in bips 
    uint private _weekBips = 100; // 1%

    // base blocks per week
    uint private _blocksPerWeek = 201_600 / 7 / 24; // todo: change to 201_600 (1w, now it's 1 hour)
    
    // total deposited
    uint public totalDeposited;

    // mapping from wallet to deposited amount
    mapping(address => uint) public deposited;

    // other contracts
    LittlebucksTKN private _littlebucksTKN;

    // events
    event Deposit(address indexed account, uint amount);
    event Withdraw(address indexed account, uint amount);

    constructor(address littlebucksTKN) {
        // access control config
        ACCESS_WAIT_BLOCKS = 20; // todo: testing, default: 200_000
        ACCESS_ADMIN_ROLEID = ADMIN_ROLE;
        hasRole[msg.sender][ADMIN_ROLE] = true;
        
        // other contracts
        _littlebucksTKN = LittlebucksTKN(littlebucksTKN);
    }

    function ADMIN_openBank() public {
        require(hasRole[msg.sender][ADMIN_ROLE], 'ADMIN access required');
        isOpen = true;
    }

    function ADMIN_closeBank() public {
        require(hasRole[msg.sender][ADMIN_ROLE], 'ADMIN access required');
        isOpen = false;
    }

    // ADMIN force acc withdraw
    // ADMIN withdraw mtv
    
    function deposit(uint amount) public {
        require(deposited[msg.sender] == 0, 'Must withdraw first');
        _littlebucksTKN.TRANSFERER_transfer(msg.sender, address(this), amount);
        deposited[msg.sender] = amount;
        emit Deposit(msg.sender, amount);
    }

    function withdraw() public {
        uint withdrawAmount = deposited[msg.sender];
        require(withdrawAmount != 0, 'Must deposit first');
        _littlebucksTKN.TRANSFERER_transfer(address(this), msg.sender, withdrawAmount);
        deposited[msg.sender] = 0;
        emit Withdraw(msg.sender, withdrawAmount);
    }


}