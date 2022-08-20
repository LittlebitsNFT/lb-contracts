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
    bool working;
    uint refBlock;
    uint lifetimeWorkedHours;
}

contract LbFactory is LbAccess, LbOpenClose {
    // access roles
    uint public constant ADMIN_ROLE = 99;
    
    // number of current workers
    uint public totalWorkers;

    // lbucks mint tracking
    uint public totalLbucksMinted;

    // mapping from account to total earnings
    mapping(address => uint) public accountTotalEarnings;

    // base payment per hour
    uint private _hourPayment = 100;

    // blocks per hour
    uint private _blocksPerHour = 1200;
    
    // other contracts
    LittlebitsNFT private _littlebitsNFT;
    LittlebucksTKN private _littlebucksTKN;
    
    // rarity bonuses in bips        0%  10%   25%   50%   100%   300%
    uint[6] private _rarityBonuses = [0, 1000, 2500, 5000, 10000, 30000]; // todo make this public, and getraritybonus private (you get the rarity bonus using the rarityId)

	// mapping from tokenId to Worker
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
        ACCESS_WAIT_BLOCKS = 0; // todo: testing, default: 200_000
        ACCESS_ADMIN_ROLEID = ADMIN_ROLE;
        hasRole[msg.sender][ADMIN_ROLE] = true;
        
        // other contracts
        _littlebitsNFT = LittlebitsNFT(littlebitsNFT);
        _littlebucksTKN = LittlebucksTKN(littlebucksTKN);
    }

    // MANAGER_fireWorker

    function getWorker(uint tokenId) public view returns (Worker memory worker) {
        worker = _workers[tokenId];
    }

    // ui helper
    function getWorkers(uint[] memory tokenIds) public view returns (Worker[] memory worker) {
        Worker[] memory workers = new Worker[](tokenIds.length);
        for (uint i = 0; i < tokenIds.length; i++) {
            workers[i] = _workers[tokenIds[i]];
        }
        return workers;
    }

    function startWork(uint tokenId) public onlyTokenOwner(tokenId) {
        require(!_workers[tokenId].working, "Already working");
        require(isOpen, "Building is closed");
        _workers[tokenId].working = true;
        _workers[tokenId].refBlock = block.number;
        totalWorkers += 1;
        emit WorkStart(tokenId);
	}
    
	function stopWork(uint tokenId) public onlyTokenOwner(tokenId) {
        require(_workers[tokenId].working, "Not currently working");
        // withdraw payment
        withdrawPayment(tokenId);
        // remove worker
        _workers[tokenId].working = false;
        totalWorkers -= 1;
        emit WorkStop(tokenId);
	}

    // withdraw payment
    function withdrawPayment(uint tokenId) public onlyTokenOwner(tokenId) {
        require(_workers[tokenId].working, "Not currently working");
        // calculate final payment
        (uint totalPayment, uint hoursWorked, uint remainderBlocks) = getTotalPaymentInfo(tokenId);
        // save token data
        _workers[tokenId].refBlock = block.number - remainderBlocks;
        _workers[tokenId].lifetimeWorkedHours += hoursWorked;
        // save contract data
        totalLbucksMinted += totalPayment;
        // save acc data
        accountTotalEarnings[msg.sender] += totalPayment;
        // pay
        _littlebucksTKN.MINTER_mint(_littlebitsNFT.ownerOf(tokenId), totalPayment);
        emit WithdrawPayment(tokenId, totalPayment);
    }

    function getTotalPaymentInfo(uint tokenId) public view returns (uint totalPayment, uint hoursWorked, uint remainderBlocks) {
        bool isWorking = _workers[tokenId].working;
        require(isWorking, "Not currently working");
        (hoursWorked, remainderBlocks) = _calculateHoursWorked(tokenId);
        uint basePayment = _hourPayment * hoursWorked;
        uint rarityBonusInBips = getRarityBonusInBips(tokenId);
        totalPayment = (basePayment * (10000 + rarityBonusInBips)) / 10000; // basePayment + basePayment * rarityBonusBips / 10000
    }

    // returns hours worked and remainder blocks.
    function _calculateHoursWorked(uint tokenId) private view returns (uint hoursWorked, uint remainderBlocks) {
        uint blocksWorked = block.number - _workers[tokenId].refBlock;
        hoursWorked = blocksWorked / _blocksPerHour;
        remainderBlocks = blocksWorked % _blocksPerHour;
    }

    function getRarityBonusInBips(uint tokenId) public view returns (uint rarityBonus) {
        uint rarity = _littlebitsNFT.getCharacter(tokenId).attributes[0];
        rarityBonus = _rarityBonuses[rarity];
    }

    function startWorkBatch(uint[] memory tokenIds) public {
        for (uint i = 0; i < tokenIds.length; i++) {
            uint tokenId = tokenIds[i];
            startWork(tokenId);
        }
	}

    function stopWorkBatch(uint[] memory tokenIds) public {
        for (uint i = 0; i < tokenIds.length; i++) {
            uint tokenId = tokenIds[i];
            stopWork(tokenId);
        }
	}

    function withdrawPaymentBatch(uint[] memory tokenIds) public {
        for (uint i = 0; i < tokenIds.length; i++) {
            uint tokenId = tokenIds[i];
            withdrawPayment(tokenId);
        }
	}
}
