// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/**
 * @title LbFactory contract
 * @author gifMaker - contact@littlebits.club
 * @notice v1.00 / 2022
 * @dev Littlebits Factory
 */

import "./LittlebitsNFT.sol";
import "./LittlebucksTKN.sol";
import "./LbCharacter.sol";
import "./LbAccess.sol";
import "./LbOpenClose.sol";

// access requirements:
// must be MINTER on LittlebucksTKN

// worker status
struct Worker {
    uint tokenId;
    bool working;
    uint refBlock;
    uint lifetimeWorkedHours;
}

contract LbFactory is LbAccess, LbOpenClose {
    // access roles
    uint public constant ADMIN_ROLE = 99;
    
    // number of current workers
    uint public totalWorkers;

    // number of current workers
    uint public totalLbucksMinted;

    // base payment per hour
    uint private _hourPayment = 100;

    // blocks per hour
    uint private _blocksPerHour = 1200 / 60; // todo: change to 1200 (1h, now it's 1 minute)
    
    // other contracts
    LittlebitsNFT private _littlebitsNFT;
    LittlebucksTKN private _littlebucksTKN;
    
    // rarity bonuses in bips        0%  10%   25%   50%   100%   300%
    uint[6] private _rarityBonuses = [0, 1000, 2500, 5000, 10000, 30000]; // todo make this public, and getraritybonus private (you get the rarity bonus using the rarityId)

	// mapping from token id to Worker
    mapping(uint => Worker) private _workers;

    modifier onlyTokenOwner(uint tokenId) {
        require(msg.sender == _littlebitsNFT.ownerOf(tokenId), "Not the owner");
        _;
    }

    event WorkStart(uint indexed lbId);
    event WorkStop(uint indexed lbId);
    event WithdrawPayment(uint indexed lbId, uint amount);

    constructor(address littlebitsNFT, address littlebucksTKN) {
        // access control config
        ACCESS_WAIT_BLOCKS = 20; // todo: testing, default: 200_000
        ACCESS_ADMIN_ROLEID = ADMIN_ROLE;
        hasRole[msg.sender][ADMIN_ROLE] = true;
        
        // other contracts
        _littlebitsNFT = LittlebitsNFT(littlebitsNFT);
        _littlebucksTKN = LittlebucksTKN(littlebucksTKN);
    }

    // MANAGER_fireWorker
    // MANAGER_fireWorker

    function getWorker(uint tokenId) public view returns (Worker memory worker) {
        worker = _workers[tokenId];
    }

    function startWork(uint tokenId) public onlyTokenOwner(tokenId) {
        require(!_workers[tokenId].working, "Already working here");
        require(isOpen, "Building is closed");
        _workers[tokenId].tokenId = tokenId;
        _workers[tokenId].working = true;
        _workers[tokenId].refBlock = block.number;
        totalWorkers += 1;
        emit WorkStart(tokenId);
	}
    
	function stopWork(uint tokenId) public onlyTokenOwner(tokenId) {
        require(_workers[tokenId].working, "Not working here");
        // withdraw payment
        withdrawPayment(tokenId);
        // remove worker
        _workers[tokenId].working = false;
        totalWorkers -= 1;
        emit WorkStop(tokenId);
	}

    // withdraw payment
    function withdrawPayment(uint tokenId) public onlyTokenOwner(tokenId) { // todo: change to token owner or manager_role
        (uint totalPayment, uint hoursWorked, uint remainderBlocks) = getTotalPaymentInfo(tokenId);
        _workers[tokenId].refBlock = block.number - remainderBlocks;
        _workers[tokenId].lifetimeWorkedHours += hoursWorked;
        totalLbucksMinted += totalPayment;
        _littlebucksTKN.MINTER_mint(_littlebitsNFT.ownerOf(tokenId), totalPayment);
        emit WithdrawPayment(tokenId, totalPayment);
    }

    function getTotalPaymentInfo(uint tokenId) public view returns (uint totalPayment, uint hoursWorked, uint remainderBlocks) {
        (hoursWorked, remainderBlocks) = _calculateHoursWorked(tokenId);
        uint basePayment = _hourPayment * hoursWorked;
        uint rarityBonusInBips = getRarityBonusInBips(tokenId);
        totalPayment = (basePayment * (10000 + rarityBonusInBips)) / 10000;
    }

    // returns hours worked and remainder blocks.
    function _calculateHoursWorked(uint tokenId) private view returns (uint hoursWorked, uint remainderBlocks) {
        bool isWorking = _workers[tokenId].working;
        require(isWorking, "Not currently working");
        uint blocksWorked = block.number - _workers[tokenId].refBlock;
        hoursWorked = blocksWorked / _blocksPerHour;
        remainderBlocks = blocksWorked % _blocksPerHour;
    }

    function getRarityBonusInBips(uint tokenId) public view returns (uint rarityBonus) {
        uint rarity = _littlebitsNFT.getCharacter(tokenId).attributes[0];
        rarityBonus = _rarityBonuses[rarity];
    }
}

    // implement batch ops in v2 (maybe another contract)

    // function startWork(uint[] memory tokenIds) public {
    //     for (uint256 index = 0; index < tokenIds.length; index++) {
    //         uint tokenId = tokenIds[index];
    //         startWork(tokenId);
    //     }
	// }

    // blocker status: when true prevent starting work
    // string[] private _blockersStatus;

    // multiplier status: when true multiplies wage
    // equal types stack additively, different types stack multiplicatively
    // up to 8 multiplier types
    // string[][8] private _multipliersStatus; 

    // mapping from multiplier status to multiply factor
    // in bips: 20% -> 2000
    // mapping(string => uint) private _multipliersValues;
    
    //200 * 2000 / 10000 = 40

    // add or remove a status to be checked as blocker
    // function SetupBlockerStatus(string statusName, bool addingStatus) onlyOwner {
    //     if (addingStatus) {
    //         _blockersStatus.push(statusName);
    //         return;
    //     }
    //     for (uint index = 0; index < _blockersStatus.length; index++) {
    //         if (_blockersStatus[index] == statusName) {
    //             _blockersStatus[index] = _blockersStatus[_blockersStatus.length - 1];
    //             _blockersStatus.pop();
    //             return;
    //         }
    //     }
    // }

    // add or remove a status to be checked as multiplier
    // function SetupMultiplierStatus(string statusName, uint statusType, uint percentValueInBips, bool addingStatus) onlyOwner {
    //     if (addingStatus) {
    //         _multipliersStatus[statusType].push(statusName);
    //         _multipliersValues[statusName] = percentValueInBips;
    //         return;
    //     }
    //     for (uint index = 0; index < _multipliersStatus[statusType].length; index++) {
    //         if (_multipliersStatus[statusType][index] == statusName) {
    //             _multipliersStatus[statusType][index] = _multipliersStatus[statusType][_multipliersStatus[statusType].length - 1];
    //             _multipliersStatus[statusType].pop();
    //             _multipliersValues[statusName] = 0;
    //             return;
    //         }
    //     }
    // }