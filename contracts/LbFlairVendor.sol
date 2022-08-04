// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/**
 * @title LbFlairVendor contract
 * @author gifMaker - contact@littlebits.club
 * @notice v1.00 / 2022
 * @dev Littlebits Flair Vendor contract
 */

import "./LittlebitsNFT.sol";
import "./LittlebucksTKN.sol";
import "./LbWorld.sol";
import "./LbAccess.sol";
import "./LbOpenClose.sol";

// access requirements:
// must be TRANSFERER on LittlebucksTKN
// must be FLAIRGIVER on LbWorld

contract LbFlairVendor is LbAccess, LbOpenClose {
    // access roles
    uint public constant ADMIN_ROLE = 99;
    uint public constant SALES_ROLE = 1; // can add/remove flairs for sale

    // other contracts
    LittlebitsNFT private _littlebitsNFT;
    LittlebucksTKN private _littlebucksTKN;
    LbWorld private _lbWorld;

    // events
    event FlairSold(uint indexed lbId, uint indexed flair, uint price);
    event FlairAddedForSale(uint indexed flair, uint price);
    event FlairRemovedForSale(uint indexed flair);

    constructor(address littlebitsNFTAddr, address littlebucksTKNAddr, address lbWorldAddr) {
        // access control config
        ACCESS_WAIT_BLOCKS = 0; // tmp testing, default: 200_000
        ACCESS_ADMIN_ROLEID = ADMIN_ROLE;
        hasRole[msg.sender][ADMIN_ROLE] = true;
        
        // other contracts refs
        _littlebitsNFT = LittlebitsNFT(littlebitsNFTAddr);
        _littlebucksTKN = LittlebucksTKN(littlebucksTKNAddr);
        _lbWorld = LbWorld(lbWorldAddr);
    }

    // mapping from flairId to price (lbucks wei)
    mapping(uint => uint) public flairPrice;

    // add flair for sale
    function SALES_addForSale(uint flairId, uint price) public {
        require(hasRole[msg.sender][SALES_ROLE], 'SALES access required');
        require(isOpen, 'Contract closed');
        require(flairPrice[flairId] == 0, 'Flair already for sale');
        flairPrice[flairId] = price;
        emit FlairAddedForSale(flairId, price);
    }

    // remove flair from sale
    function SALES_removeForSale(uint flairId) public {
        require(hasRole[msg.sender][SALES_ROLE], 'SALES access required');
        require(isOpen, 'Contract closed');
        require(flairPrice[flairId] != 0, 'Flair not for sale');
        flairPrice[flairId] = 0;
        emit FlairRemovedForSale(flairId);
    }


    function buyFlair(uint tokenId, uint flairId) public {
        require(msg.sender == _littlebitsNFT.ownerOf(tokenId), "Not the owner");
        require(isOpen, 'Contract closed');
        require(flairPrice[flairId] != 0, 'Flair not for sale');
        _littlebucksTKN.TRANSFERER_transfer(msg.sender, address(this), flairPrice[flairId]);
        _lbWorld.FLAIRGIVER_giveFlair(tokenId, flairId);
        emit FlairSold(tokenId, flairId, flairPrice[flairId]);
    }
}