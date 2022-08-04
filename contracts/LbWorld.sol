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
import "./LbAccess.sol";
import "./LbOpenClose.sol";

struct WorldPlacedInfo {
    uint tokenId; // todo: add uint collectionId for multiple collections?
    uint block;
    int[2] coords;
    bool flipped;
    uint[] flairs;
}

// access requirements:
// must be TRANSFERER on LittlebucksTKN

contract LbWorld is LbAccess, LbOpenClose {
    // access roles
    uint public constant ADMIN_ROLE = 99;
    uint public constant FLAIRGIVER_ROLE = 1;
    uint public constant LBPLACER_ROLE = 2;
    uint public constant PRICESETTER_ROLE = 3;

    // default lb placement price
    uint public placementPrice = 1 * 100;
    
    // other contracts
    LittlebitsNFT private _littlebitsNFT;
    LittlebucksTKN private _littlebucksTKN;

    // events
    event TokenPlaced(uint indexed tokenId, int[2] coords, bool flipped, uint[] flairs);
    event FlairAcquired(uint indexed tokenId, uint indexed flair);

    // mapping from tokenId to (flairId to owned)
    mapping(uint => mapping(uint => bool)) public isFlairOwned;
    
    // mapping from tokenId to [every flair acquired by this token] (for public view / ui listing)
    mapping(uint => uint[]) private flairsAcquired;
    
    // mapping from tokenId to last placed info
    mapping(uint => WorldPlacedInfo) private lastPlaced;

    constructor(address littlebitsNFTAddr, address littlebucksTKNAddr) {
        // access control config
        ACCESS_WAIT_BLOCKS = 0; // tmp testing, default: 200_000
        ACCESS_ADMIN_ROLEID = ADMIN_ROLE;
        hasRole[msg.sender][ADMIN_ROLE] = true;
        
        // other contracts refs
        _littlebitsNFT = LittlebitsNFT(littlebitsNFTAddr);
        _littlebucksTKN = LittlebucksTKN(littlebucksTKNAddr);
    }

    // to be tested
    // TODO: CHANGE TO getFlairsOwned
    function getFlairsAcquired(uint tokenId, uint startInd, uint fetchMax) public view returns (uint[] memory) {
        uint fetchTotal = flairsAcquired[tokenId].length - startInd;
        fetchTotal = fetchTotal < fetchMax ? fetchTotal : fetchMax;
        uint[] memory returnFlairs = new uint[](fetchTotal);
        uint fetchTo = startInd + fetchTotal;
        for (uint i = startInd; i < fetchTo; i++) {
            returnFlairs[i - startInd] = flairsAcquired[tokenId][i];
        }
        return returnFlairs;
    }

    // TODO: CHANGE TO getFlairsOwnedSize
    function getFlairsAcquiredSize(uint tokenId) public view returns (uint) {
        return flairsAcquired[tokenId].length;
    }

    function getLastPlacedInfo(uint tokenId) public view returns (WorldPlacedInfo memory) {
        return lastPlaced[tokenId];
    }

    // place lb in the world
    function placeLb(uint tokenId, int[2] memory coords, bool flipped, uint[] memory flairs) public {
        require(isOpen, 'Contract closed');
        // check ownership
        // require(msg.sender == _littlebitsNFT.ownerOf(tokenId), "Not the owner"); // TMP: ownership requirement disabled
        // check flairs owned
        for (uint i = 0; i < flairs.length; i++) {
            uint flairId = flairs[i];
            require(isFlairOwned[tokenId][flairId], 'Flair not owned');
        }
        // pay lbucks
        _littlebucksTKN.TRANSFERER_transfer(msg.sender, address(this), placementPrice);
        // update lastPlaced state
        lastPlaced[tokenId] = WorldPlacedInfo(tokenId, block.number, coords, flipped, flairs);
        // event
        emit TokenPlaced(tokenId, coords, flipped, flairs);
    }

    // authorized contracts can put lbs in the world with custom effects (safeFlairs)
    // doesnt check lbId ownership
    // doesnt check safeFlairs ownership
    // doesnt charge anything
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
        // update lastPlaced state
        lastPlaced[tokenId] = WorldPlacedInfo(tokenId, block.number, coords, flipped, allFlairs);
        // event
        emit TokenPlaced(tokenId, coords, flipped, allFlairs);
    }

    // changes default lbplacing price
    function PRICESETTER_setPlacementPrice(uint weiPrice) public {
        require(hasRole[msg.sender][ADMIN_ROLE], 'PRICESETTER access required');
        placementPrice = weiPrice;
    }

    function FLAIRGIVER_giveFlair(uint lbId, uint flairId) public {
        require(hasRole[msg.sender][FLAIRGIVER_ROLE], 'FLAIRGIVER access required');
        require(isOpen, 'Contract closed');
        if (!isFlairOwned[lbId][flairId]) {
            isFlairOwned[lbId][flairId] = true;
            flairsAcquired[lbId].push(flairId);
            emit FlairAcquired(lbId, flairId);
        }
    }
}