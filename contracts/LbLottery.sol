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
// must be MINTER on LittlebucksTKN
// must be TRANSFERER on LittlebucksTKN
// must be BURNER on LittlebucksTKN (tbi)

contract LbLottery is LbAccess, LbOpenClose {
    // access roles
    uint public constant ADMIN_ROLE = 99;
    uint public constant MANAGER_ROLE = 1;
    
    // constants
    uint public constant MIN_LOTTERY_HOURS = 1; //= 167;
    uint public constant BLOCKS_PER_HOUR = 20; //= 1200;
    uint public constant TOTAL_TICKETS = 10000;
    uint public constant TICKET_BURN_VALUE = 10 * 100;
    uint public constant TICKET_ADDED_VALUE = 40 * 100;
    uint public constant TICKET_PRICE = TICKET_BURN_VALUE + TICKET_ADDED_VALUE;

    // start lottery prize
    uint private _startPrize = 10000 * 100;

    uint public currentDrawId = 0;

    // mapping from drawId to number of tickets
    mapping(uint => uint) public currentlyEnrolled;

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

    bool private isSetupDone;

    bool public isRunning;

    bool public isDrawing;

    uint public drawRefBlock;
    
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
        require(startBlock[currentDrawId] < block.number - MIN_LOTTERY_HOURS * BLOCKS_PER_HOUR, "Not enough time elapsed");
        isRunning = false;
        isDrawing = true;
        drawRefBlock = block.number;
    }

    function secondStepDraw() public {
        require(isDrawing, "Lottery is NOT drawing");
        bytes32 drawRefBlockHash = blockhash(drawRefBlock);
        if (drawRefBlockHash != 0) {
            uint luckyTicket = uint(keccak256(abi.encodePacked(drawRefBlockHash))) % TOTAL_TICKETS;
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
        _littlebucksTKN.TRANSFERER_transfer(msg.sender, address(this), TICKET_BURN_VALUE); // todo: change to burn
        _littlebucksTKN.TRANSFERER_transfer(msg.sender, address(this), TICKET_ADDED_VALUE);
        // register
        currentlyEnrolled[currentDrawId] += 1;
        isEnrolled[currentDrawId][tokenId] = true;
        prizePool[currentDrawId] += TICKET_ADDED_VALUE;
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
