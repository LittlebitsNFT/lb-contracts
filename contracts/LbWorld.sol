// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/**
 * @title LbWorld contract
 * @author gifMaker - contact@littlebits.club
 * @notice v1.00 / 2022
 * @dev Littlebits World contract
 */

import "./LittlebitsNFT.sol";
import "./LbCharacter.sol";
import "./LittlebucksTKN.sol";
import "./LbBadges.sol";
import "./LbAccess.sol";
import "./LbOpenClose.sol";

struct WorldPlacedInfo {
    uint block;
    int[2] coords;
    bool flipped;
    uint[] flairs;
}

// access requirements:
// must be TRANSFERER on LittlebucksTKN
// must be BADGE_GIVER on LbBadges

contract LbWorld is LbAccess, LbOpenClose {
    // access roles
    uint public constant ADMIN_ROLE = 99;
    uint public constant OTHERCONTRACTS_ROLE = 88;
    uint public constant FLAIRGIVER_ROLE = 1;
    uint public constant LBPLACER_ROLE = 2;
    uint public constant SETTINGS_ROLE = 3;

    // default lb placement price
    uint public placementPrice = 1 * 100;
    
    // maximum blocks considered to be registered on pastTotalBlocksPlaced each time
    uint public maxPlacementBlocksConsidered = 24 * 60 * 60 / 3; // default: 24h for 3s block time
    
    uint public badge1ReqBlocks = 100 * 60 * 60 / 3; 
    uint public badge2ReqBlocks = 1000 * 60 * 60 / 3;

    // other contracts
    LittlebitsNFT private _littlebitsNFT;
    LittlebucksTKN private _littlebucksTKN;
    LbBadges private _lbBadges;

    // events
    event TokenPlaced(uint indexed tokenId, int[2] coords, bool flipped, uint[] flairs);
    event FlairAcquired(uint indexed tokenId, uint indexed flair);

    // mapping from tokenId to (flairId to owned)
    mapping(uint => mapping(uint => bool)) public isFlairOwned;
    
    // mapping from tokenId to [every flair acquired by this token] (for public view / ui listing)
    mapping(uint => uint[]) private flairsAcquired;
    
    // mapping from tokenId to last placed info
    mapping(uint => WorldPlacedInfo) private lastPlaced;

    // mapping from tokenId to past total time placed
    // only updated on a new placement -- the very last time placed is not accounted
    // current total time placed = pastTotalBlocksPlaced + last time placed
    mapping(uint => uint) private pastTotalBlocksPlaced;

    // mapping from account to maxFlairsAcquired on a single token
    mapping(address => uint) private accMaxFlairsSingleToken;

    // mapping from (account, flairId) to wasFlairUnlocked
    mapping(address => mapping(uint => bool)) public wasFlairUnlocked;

    constructor(address littlebitsNFTAddr, address littlebucksTKNAddr, address lbBadges) {
        // access control config
        ACCESS_WAIT_BLOCKS = 0; // tmp testing, default: 200_000
        ACCESS_ADMIN_ROLEID = ADMIN_ROLE;
        hasRole[msg.sender][ADMIN_ROLE] = true;
        
        // other contracts refs
        _littlebitsNFT = LittlebitsNFT(littlebitsNFTAddr);
        _littlebucksTKN = LittlebucksTKN(littlebucksTKNAddr);
        _lbBadges = LbBadges(lbBadges);
    }

    // to be tested
    function getFlairsOwned(uint tokenId, uint startInd, uint fetchMax) public view returns (uint[] memory) {
        uint fetchTotal = flairsAcquired[tokenId].length - startInd;
        fetchTotal = fetchTotal < fetchMax ? fetchTotal : fetchMax;
        uint[] memory returnFlairs = new uint[](fetchTotal);
        uint fetchTo = startInd + fetchTotal;
        for (uint i = startInd; i < fetchTo; i++) {
            returnFlairs[i - startInd] = flairsAcquired[tokenId][i];
        }
        return returnFlairs;
    }

    function getFlairsOwnedSize(uint tokenId) public view returns (uint) {
        return flairsAcquired[tokenId].length;
    }

    function getLastPlacedInfo(uint tokenId) public view returns (WorldPlacedInfo memory) {
        return lastPlaced[tokenId];
    }

    function getAccMaxFlairsSingleToken(address account) public view returns (uint) {
        return accMaxFlairsSingleToken[account];
    }

    // gives current total blocks placed, including last session
    function getTotalBlocksPlaced(uint tokenId) public view returns (uint) {
        uint lastPlacedTotalBlocks = 0;
        uint lastPlacedBlock = lastPlaced[tokenId].block;
        if (lastPlacedBlock != 0) {
            lastPlacedTotalBlocks = block.number - lastPlacedBlock;
            lastPlacedTotalBlocks = lastPlacedTotalBlocks > maxPlacementBlocksConsidered ? maxPlacementBlocksConsidered : lastPlacedTotalBlocks;
        }
        return lastPlacedTotalBlocks + pastTotalBlocksPlaced[tokenId];
    }

    // place lb in the world
    function placeLb(uint tokenId, int[2] memory coords, bool flipped, uint[] memory flairs) public {
        require(isOpen, 'Contract closed');
        // check ownership
        require(msg.sender == _littlebitsNFT.ownerOf(tokenId), "Not the owner");
        // check flairs owned
        for (uint i = 0; i < flairs.length; i++) {
            uint flairId = flairs[i];
            require(isFlairOwned[tokenId][flairId], 'Flair not owned');
        }
        // pay lbucks
        _littlebucksTKN.TRANSFERER_transfer(msg.sender, address(this), placementPrice);
        _littlebucksTKN.burn(placementPrice);
        // update position
        _updatedPlacedPosition(tokenId, coords, flipped, flairs);
        // event
        emit TokenPlaced(tokenId, coords, flipped, flairs);
    }

    // authorized contracts can put lbs in the world with custom effects (safeFlairs)
    // doesnt check lbId ownership
    // doesnt check safeFlairs ownership
    // doesnt charge lbucks
    function LBPLACER_placeLb(uint tokenId, int[2] memory coords, bool flipped, uint[] memory flairs, uint[] memory safeFlairs) public {
        require(hasRole[msg.sender][LBPLACER_ROLE], 'LBPLACER access required');
        require(isOpen, 'Contract closed');
        // check flairs owned
        for (uint i = 0; i < flairs.length; i++) {
            uint flairId = flairs[i];
            require(isFlairOwned[tokenId][flairId], 'Flair not owned');
        }
        // merge owned and custom flairs
        uint[] memory allFlairs = new uint[](flairs.length + safeFlairs.length);
        // update position
        _updatedPlacedPosition(tokenId, coords, flipped, allFlairs);
        // event
        emit TokenPlaced(tokenId, coords, flipped, allFlairs);
    }

    // changes max placement time considered
    function SETTINGS_setMaxBlocksConsidered(uint maxBlocks) public {
        require(hasRole[msg.sender][SETTINGS_ROLE], 'SETTINGS access required');
        maxPlacementBlocksConsidered = maxBlocks;
    }

    // changes lbplacing price
    function SETTINGS_setPlacementPrice(uint weiPrice) public {
        require(hasRole[msg.sender][SETTINGS_ROLE], 'SETTINGS access required');
        placementPrice = weiPrice;
    }

    function FLAIRGIVER_giveFlair(uint tokenId, uint flairId) public {
        require(hasRole[msg.sender][FLAIRGIVER_ROLE], 'FLAIRGIVER access required');
        require(isOpen, 'Contract closed');
        if (!isFlairOwned[tokenId][flairId]) {
            isFlairOwned[tokenId][flairId] = true;
            flairsAcquired[tokenId].push(flairId);
            address owner = _littlebitsNFT.ownerOf(tokenId);
            // register max flairs acquired by account on a single token
            uint tokenFlairsAcquiredLength = flairsAcquired[tokenId].length;
            if (accMaxFlairsSingleToken[owner] < tokenFlairsAcquiredLength) {
                accMaxFlairsSingleToken[owner] = tokenFlairsAcquiredLength;
            }
            // register flair acquired by account
            wasFlairUnlocked[owner][flairId] = true;
            // emit
            emit FlairAcquired(tokenId, flairId);
        }
    }

    // will do a full search if startInd is zero. You can specify where it is on the owned list
    function FLAIRGIVER_removeFlair(uint tokenId, uint flairId, uint startInd) public {
        require(hasRole[msg.sender][FLAIRGIVER_ROLE], 'FLAIRGIVER access required');
        require(isOpen, 'Contract closed');
        if (isFlairOwned[tokenId][flairId]) {
            isFlairOwned[tokenId][flairId] = false;
            // remove from flairsAcquired list
            uint flairsAcquiredLength = flairsAcquired[tokenId].length;
            for (uint i = startInd; i < flairsAcquiredLength; i++) {
                if (flairsAcquired[tokenId][i] == flairId) {
                    flairsAcquired[tokenId][i] = flairsAcquired[tokenId][flairsAcquiredLength - 1];
                    flairsAcquired[tokenId].pop();
                    break;
                }
            }
        }
    }

    function OTHERCONTRACTS_setContract(uint contractId, address newAddress) public {
        require(hasRole[msg.sender][OTHERCONTRACTS_ROLE], 'OTHERCONTRACTS access required');
        if (contractId == 0) {
            _littlebitsNFT = LittlebitsNFT(newAddress);
        }
        if (contractId == 1) {
            _littlebucksTKN = LittlebucksTKN(newAddress);
        }
        if (contractId == 2) {
            _lbBadges = LbBadges(newAddress);
        }
    }

    // update total blocks placed, sets a new placed position and gives badges
    function _updatedPlacedPosition(uint tokenId, int[2] memory coords, bool flipped, uint[] memory flairs) private {
        // update past total blocks placed
        uint totalBlocksPlaced = getTotalBlocksPlaced(tokenId);
        pastTotalBlocksPlaced[tokenId] = totalBlocksPlaced;
        // gives badges
        if (totalBlocksPlaced >= badge1ReqBlocks) {
            _lbBadges.BADGE_GIVER_giveBadge(tokenId, 1010);
        }
        if (totalBlocksPlaced >= badge2ReqBlocks) {
            _lbBadges.BADGE_GIVER_giveBadge(tokenId, 1020);
        }
        // sets a new placed position
        lastPlaced[tokenId] = WorldPlacedInfo(block.number, coords, flipped, flairs);
    }
}