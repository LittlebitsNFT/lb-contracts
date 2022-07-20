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

// access requirements:
// must be TRANSFERER on LittlebucksTKN

contract LbWorld is LbAccess {
    // allows this contract to be shutdown and relaunched (ex: in case of upgrades or if admin control is compromised)
    bool public pausedForever = false;
    // access roles
    uint public constant ADMIN_ROLE = 99;
    uint public constant FLAIRGIVER_ROLE = 1;
    uint public constant LBPLACER_ROLE = 2;
    uint public constant PRICESETTER_ROLE = 3;

    // default lb placement price
    uint public lbucksPlacementPrice = 1 * 100;
    
    // other contracts
    LittlebitsNFT private _littlebitsNFT;
    LittlebucksTKN private _littlebucksTKN;

    // events
    event NewLbPlaced(uint indexed lbId, int[2] coords, bool flipped, uint[] flairs);
    event NewFlairAcquired(uint indexed lbId, uint indexed flair);

    struct LbPlaced {
        uint block;
        int[2] coords;
        bool flipped;
        uint[] flairs;
    }

    // mapping from lb_id to (flairId to owned)
    mapping(uint => mapping(uint => bool)) public flairsOwned;
    
    // mapping from lb_id to [every flair acquired by this lb] (for public view / ui listing)
    mapping(uint => uint[]) public flairsAcquired;
    
    // mapping from lbId to last placed info
    mapping(uint => LbPlaced) public lastPlaced;

    constructor(address littlebitsNFTAddr, address littlebucksTKNAddr) {
        // access control config
        ACCESS_WAIT_BLOCKS = 20; // tmp testing, default: 200_000
        ACCESS_ADMIN_ROLEID = ADMIN_ROLE;
        hasRole[msg.sender][ADMIN_ROLE] = true;
        
        // tmp test
        // hasRole[msg.sender][FLAIRGIVER_ROLE] = true;     // TODO:  remove this, only registered contracts should mint
        // hasRole[msg.sender][LBPLACER_ROLE] = true;       // TODO:  remove this, only registered contracts should tranfer
        
        // other contracts refs
        _littlebitsNFT = LittlebitsNFT(littlebitsNFTAddr);
        _littlebucksTKN = LittlebucksTKN(littlebucksTKNAddr);
    }

    // place lb in the world
    function placeLb(uint lbId, int[2] memory coords, bool flipped, uint[] memory flairs) public {
        require(!pausedForever, 'Contract locked');
        // check ownership
        // require(msg.sender == _littlebitsNFT.ownerOf(tokenId), "Not the owner"); // TMP: ownership requirement disabled
        // check flairs owned
        for (uint i = 0; i < flairs.length; i++) {
            uint flairId = flairs[i];
            bool owned = flairsOwned[lbId][flairId];
            require(owned, 'Flair not owned');
        }
        // pay lbucks
        _littlebucksTKN.TRANSFERER_transfer(msg.sender, address(this), lbucksPlacementPrice);
        // update lastPlaced state
        lastPlaced[lbId] = LbPlaced(block.number, coords, flipped, flairs);
        // event
        emit NewLbPlaced(lbId, coords, flipped, flairs);
    }

    // authorized contracts can put lbs in the world with custom effects (safeFlairs)
    // doesnt check lbId ownership
    // doesnt check safeFlairs ownership
    // doesnt charge anything
    function LBPLACER_placeLb(uint lbId, int[2] memory coords, bool flipped, uint[] memory flairs, uint[] memory safeFlairs) public {
        require(hasRole[msg.sender][LBPLACER_ROLE], 'LBPLACER access required');
        require(!pausedForever, 'Contract locked');
        // check flairs owned
        for (uint i = 0; i < flairs.length; i++) {
            uint flairId = flairs[i];
            bool owned = flairsOwned[lbId][flairId];
            require(owned, 'Flair not owned');
        }
        // merge owned and custom flairs
        uint[] memory allFlairs = new uint[](flairs.length + safeFlairs.length);
        // update lastPlaced state
        lastPlaced[lbId] = LbPlaced(block.number, coords, flipped, allFlairs);
        // event
        emit NewLbPlaced(lbId, coords, flipped, allFlairs);
    }

    // contract lock
    function ADMIN_pauseForever() public {
        require(hasRole[msg.sender][ADMIN_ROLE], 'ADMIN access required');
        pausedForever = true;
    }

    // changes default lbplacing price
    function PRICESETTER_setPlacementPrice(uint lbucksInWei) public {
        require(hasRole[msg.sender][ADMIN_ROLE], 'PRICESETTER access required');
        lbucksPlacementPrice = lbucksInWei;
    }

    function FLAIRGIVER_giveFlair(uint lbId, uint flairId) public {
        require(hasRole[msg.sender][FLAIRGIVER_ROLE], 'FLAIRGIVER access required');
        require(!pausedForever, 'Contract locked');
        bool flairOwned = flairsOwned[lbId][flairId];
        if (!flairOwned) {
            flairsOwned[lbId][flairId] = true;
            flairsAcquired[lbId].push(flairId);
            emit NewFlairAcquired(lbId, flairId);
        }
    }
}
// TODO: MAKE A NOT-FOREVER PAUSE
// TODO: VER COMO LITTLEBABIES + OUTRAS NFTS INFLUENCIARIAM NO SISTEMA