// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/**
 * @title LbBank contract
 * @author gifMaker - contact@littlebits.club
 * @notice v1.00 / 2022
 * @dev Littlebits Bank
 */

import "./LittlebucksTKN.sol";
import "./LbAccess.sol";
import "./LbOpenClose.sol";

// access requirements:
// must be TRANSFERER and MINTER on LittlebucksTKN

contract LbBank is LbAccess, LbOpenClose {
    // access roles
    uint public constant ADMIN_ROLE = 99;

    // interest per week in bips 
    uint private _weekBips = 100; // 1%

    // base blocks per week
    uint private constant _blocksPerWeek = 201_600; // 1 week
    
    // total deposited
    uint public totalDeposited;

    // lbucks mint tracking
    uint public totalLbucksMinted;

    // mapping from wallet to deposited amount
    mapping(address => uint) public deposited;

    // mapping from wallet to refBlock
    mapping(address => uint) public refBlock;

    // other contracts
    LittlebucksTKN private _littlebucksTKN;

    // events
    event Deposit(address indexed account, uint amount);
    event Withdraw(address indexed account, uint amount, uint initialDeposit);

    constructor(address littlebucksTKN) {
        // access control config
        ACCESS_WAIT_BLOCKS = 0; // todo: testing, default: 200_000
        ACCESS_ADMIN_ROLEID = ADMIN_ROLE;
        hasRole[msg.sender][ADMIN_ROLE] = true;
        
        // other contracts
        _littlebucksTKN = LittlebucksTKN(littlebucksTKN);
    }

    function ADMIN_forceWithdraw(address account) public {
        require(hasRole[msg.sender][ADMIN_ROLE], 'ADMIN_ROLE access required');
        _withdraw(account);
    }
    
    function deposit(uint amount) public {
        require(deposited[msg.sender] == 0, 'Must withdraw first');
        _littlebucksTKN.TRANSFERER_transfer(msg.sender, address(this), amount);
        deposited[msg.sender] = amount;
        refBlock[msg.sender] = block.number;
        totalDeposited += amount;
        emit Deposit(msg.sender, amount);
    }

    function withdraw() public {
        _withdraw(msg.sender);
    }

    function _withdraw(address account) private {
        uint depositedAmount = deposited[account];
        require(depositedAmount > 0, 'Not currently invested');
        // interest mint
        (uint weeksInvested,) = _calculateWeeksInvested(account);
        uint interest = depositedAmount * weeksInvested * _weekBips / 10000;
        _littlebucksTKN.MINTER_mint(address(this), interest);
        totalLbucksMinted += interest;
        // total
        uint withdrawAmount = depositedAmount + interest;
        // single transfer
        _littlebucksTKN.TRANSFERER_transfer(address(this), account, withdrawAmount);
        deposited[account] = 0;
        totalDeposited -= depositedAmount;
        // emit with total
        emit Withdraw(account, withdrawAmount, depositedAmount);
    }

    // returns hours worked and remainder blocks.
    function _calculateWeeksInvested(address account) private view returns (uint weeksInvested, uint remainderBlocks) {
        uint blocksInvested = block.number - refBlock[account];
        weeksInvested = blocksInvested / _blocksPerWeek;
        remainderBlocks = blocksInvested % _blocksPerWeek;
    }

    // ui
    function getInvestedInfo(address account) public view returns (uint amount, uint _refBlock) {
        amount = deposited[account];
        _refBlock = refBlock[account];
    }


}