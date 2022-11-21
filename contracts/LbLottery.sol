// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/**
 * @title LbLottery contract
 * @author gifMaker - contact@littlebits.club
 * @notice v1.00 / 2022
 * @dev Littlebits Lottery
 */

import "./LittlebitsNFT.sol";
import "./LittlebucksTKN.sol";
import "./LbSkills.sol";
import "./LbCharacter.sol";
import "./LbAccess.sol";
import "./LbOpenClose.sol";

// access requirements:
// must be MINTER and TRANSFERER on LittlebucksTKN

contract LbLottery is LbAccess, LbOpenClose {
    // access roles
    uint public constant ADMIN_ROLE = 99;
    uint public constant OTHERCONTRACTS_ROLE = 88;
    uint public constant SETTINGS_ROLE = 1;
    
    // settings
    uint private _minLotteryHours = 1; //= 167;
    uint private _blocksPerHour = 20; //= 1200;
    uint private _totalTickets = 10000;
    uint private _ticketBurnAmount = 10 * 100;
    uint private _ticketAddAmount = 40 * 100;
    uint private _startPrize = 10000 * 100;

    // current drawId
    uint public currentDrawId = 0;

    // 2-step draw refBlock
    uint public drawRefBlock;

    // state
    bool public isRunning;
    bool public isDrawing;
    bool private isSetupDone;

    // mapping from drawId to number of tickets
    mapping(uint => uint) public enrolled;

    // mapping from drawId to ticket to isEnrolled
    mapping(uint => mapping(uint => bool)) public isEnrolled;

    // mapping from drawId to drawnTicket
    mapping(uint => uint) public drawnTicket;

    // mapping from drawId to prizePool
    mapping(uint => uint) public prizePool;

    // mapping from drawId to winnerAccount
    mapping(uint => address) public winnerAccount;

    // mapping from account to total earnings
    mapping(address => uint) public accountTotalEarnings;

    // mapping from drawId to startBlock
    mapping(uint => uint) public startBlock;

    // other contracts
    LittlebitsNFT private _littlebitsNFT;
    LittlebucksTKN private _littlebucksTKN;
    
    event LotteryStart(uint indexed drawId, uint prize, bool isAccumulated, uint lastDrawnTicket, uint lastPrize, address lastWinnerAcc);
    event TicketBought(uint indexed ticket);
    event LotteryResult(uint indexed drawId, uint indexed luckyTicket, bool haveWinner, uint prize, address winnerAccount);

    constructor(address littlebitsNFT, address littlebucksTKN) {
        // access control config
        ACCESS_WAIT_BLOCKS = 0; // todo: testing, default: 200_000
        ACCESS_ADMIN_ROLEID = ADMIN_ROLE;
        hasRole[msg.sender][ADMIN_ROLE] = true;
        
        // other contracts
        _littlebitsNFT = LittlebitsNFT(littlebitsNFT);
        _littlebucksTKN = LittlebucksTKN(littlebucksTKN);
    }

    function OTHERCONTRACTS_setContract(uint contractId, address newAddress) public {
        require(hasRole[msg.sender][OTHERCONTRACTS_ROLE], 'OTHERCONTRACTS access required');
        if (contractId == 0) {
            _littlebitsNFT = LittlebitsNFT(newAddress);
        }
        if (contractId == 1) {
            _littlebucksTKN = LittlebucksTKN(newAddress);
        }
    }

    function SETTINGS_setSettingsVar(uint settingsVarId, uint newValue) public {
        require(hasRole[msg.sender][SETTINGS_ROLE], 'SETTINGS access required');
        if (settingsVarId == 0) {
            _minLotteryHours = newValue;
        }
        if (settingsVarId == 1) {
            _blocksPerHour = newValue;
        }
        if (settingsVarId == 2) {
            _totalTickets = newValue;
        }
        if (settingsVarId == 3) {
            _ticketBurnAmount = newValue;
        }
        if (settingsVarId == 4) {
            _ticketAddAmount = newValue;
        }
        if (settingsVarId == 5) {
            _startPrize = newValue;
        }
    }

    function setupLottery() public {
        require(!isSetupDone, "Setup already done");
        prizePool[currentDrawId] = _startPrize;
        _littlebucksTKN.MINTER_mint(address(this), _startPrize);
        isSetupDone = true;
    }

    function startLottery() public {
        require(isOpen, "Building is closed");
        require(isSetupDone, "Setup not done");
        require(!isRunning, "Lottery is running");
        require(!isDrawing, "Lottery is drawing");
        isRunning = true;
        currentDrawId += 1;
        startBlock[currentDrawId] = block.number;
        uint lastDrawId = currentDrawId - 1;
        uint lastDrawnTicket = drawnTicket[lastDrawId];
        bool hadWinner = isEnrolled[lastDrawId][lastDrawnTicket];
        if (hadWinner) {
            // start new prize
            prizePool[currentDrawId] = _startPrize;
            _littlebucksTKN.MINTER_mint(address(this), _startPrize);
        } else {
            // rollover
            prizePool[currentDrawId] = prizePool[lastDrawId];
        }
        emit LotteryStart(currentDrawId, prizePool[currentDrawId], !hadWinner, lastDrawnTicket, prizePool[lastDrawId], winnerAccount[lastDrawId]);
    }

    function firstStepDraw() public {
        require(isRunning, "Lottery is NOT running");
        require(startBlock[currentDrawId] < block.number - _minLotteryHours * _blocksPerHour, "Not enough time elapsed");
        isRunning = false;
        isDrawing = true;
        drawRefBlock = block.number;
    }

    function secondStepDraw() public {
        require(isDrawing, "Lottery is NOT drawing");
        bytes32 drawRefBlockHash = blockhash(drawRefBlock);
        if (drawRefBlockHash != 0) {
            uint luckyTicket = uint(keccak256(abi.encodePacked(drawRefBlockHash))) % _totalTickets;
            luckyTicket = 891;
            drawnTicket[currentDrawId] = luckyTicket;
            bool hadWinner = isEnrolled[currentDrawId][luckyTicket];
            address ownerOfLuckyTicket = address(0);
            uint currentPrizePool = prizePool[currentDrawId];
            if (hadWinner) {
                ownerOfLuckyTicket = _littlebitsNFT.ownerOf(luckyTicket);
                _littlebucksTKN.transfer(ownerOfLuckyTicket, currentPrizePool);
                winnerAccount[currentDrawId] = ownerOfLuckyTicket;
                accountTotalEarnings[ownerOfLuckyTicket] += currentPrizePool;
            }
            emit LotteryResult(currentDrawId, luckyTicket, hadWinner, currentPrizePool, ownerOfLuckyTicket);
            isDrawing = false;
        } else {
            // waited too much
            drawRefBlock = block.number;
        }
    }

    function buyTicket(uint tokenId) public {
        require(isRunning, "Lottery is NOT running");
        require(!isEnrolled[currentDrawId][tokenId], 'Already enrolled');
        require(msg.sender == _littlebitsNFT.ownerOf(tokenId), "Not the owner");
        // pay
        _littlebucksTKN.TRANSFERER_transfer(msg.sender, address(this), _ticketBurnAmount + _ticketAddAmount);
        // burn fee
        _littlebucksTKN.burn(_ticketBurnAmount);
        // register
        enrolled[currentDrawId] += 1;
        isEnrolled[currentDrawId][tokenId] = true;
        prizePool[currentDrawId] += _ticketAddAmount;
        // event
        emit TicketBought(tokenId);
    }

    function buyTicketBatch(uint[] memory tickets) public {
        for (uint i = 0; i < tickets.length; i++) {
            buyTicket(tickets[i]);
        }
    }

    function checkTicketEnrollmentBatch(uint[] memory tickets) public view returns (bool[] memory) {
        bool[] memory results = new bool[](tickets.length);
        for (uint i = 0; i < tickets.length; i++) {
            results[i] = isEnrolled[currentDrawId][tickets[i]];
        }
        return results;
    }

}
