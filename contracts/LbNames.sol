// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/**
 * @title LbNames contract
 * @author gifMaker - contact@littlebits.club
 * @notice v1.00 / 2022
 * @dev Littlebits Names
 */

import "./LittlebitsNFT.sol";
import "./LittlebucksTKN.sol";
import "./LbSkills.sol";
import "./LbCharacter.sol";
import "./LbAccess.sol";
import "./LbOpenClose.sol";

// access requirements:
// must be TRANSFERER on LittlebucksTKN

contract LbNames is LbAccess, LbOpenClose {
    // access roles
    uint public constant ADMIN_ROLE = 99;
    uint public constant OTHERCONTRACTS_ROLE = 88;
    uint public constant MANAGER_ROLE = 1;
    uint public constant SETTINGS_ROLE = 2;
    
    // constants
    uint private _changeNamePrice = 500 * 100;

    // mapping from name to isTaken
    mapping(string => bool) public isNameTaken;
    
    // mapping from name to tokenId
    mapping(string => uint) public tokenIdOfName;

    // mapping from tokenId to name
    mapping(uint => string) public tokenName;

    // mapping from account to setnameCounter
    mapping(address => uint) public setnameCounter;

    // other contracts
    LittlebitsNFT private _littlebitsNFT;
    LittlebucksTKN private _littlebucksTKN;

    event SetName(uint indexed tokenId, string name);
    
    constructor(address littlebitsNFT, address littlebucksTKN) {
        // access control config
        ACCESS_WAIT_BLOCKS = 0; // todo: testing, default: 200_000
        ACCESS_ADMIN_ROLEID = ADMIN_ROLE;
        hasRole[msg.sender][ADMIN_ROLE] = true;
        
        // other contracts
        _littlebitsNFT = LittlebitsNFT(littlebitsNFT);
        _littlebucksTKN = LittlebucksTKN(littlebucksTKN);
    }

    function setName(uint tokenId, string memory newName) public {
        require(isOpen, "Building is closed");
        require(msg.sender == _littlebitsNFT.ownerOf(tokenId), "Not the owner");
        _littlebucksTKN.TRANSFERER_transfer(msg.sender, address(this), _changeNamePrice);
        _littlebucksTKN.burn(_changeNamePrice);
        // register data
        setnameCounter[msg.sender] += 1;
        _changeName(tokenId, newName);
    }

    function MANAGER_changeName(uint tokenId, string memory newName) public {
        require(hasRole[msg.sender][MANAGER_ROLE], 'MANAGER_ROLE access required');
        _changeName(tokenId, newName);
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

    function SETTINGS_setChangeNamePrice(uint newPriceInBips) public {
        require(hasRole[msg.sender][SETTINGS_ROLE], 'SETTINGS access required');
        _changeNamePrice = newPriceInBips;
    }
    
    function _changeName(uint tokenId, string memory newName) private {
        require(!isNameTaken[newName], 'Name already in use');
        isNameTaken[tokenName[tokenId]] = false; // makes old name available again
        tokenIdOfName[newName] = tokenId;
        tokenName[tokenId] = newName;
        isNameTaken[newName] = true;
        emit SetName(tokenId, newName);
    }

    function getNameBatch(uint[] memory tokenIds) public view returns (string[] memory) {
        uint querySize = tokenIds.length;
        string[] memory names = new string[](querySize);
        for (uint256 i = 0; i < querySize; i++) {
            names[i] = tokenName[tokenIds[i]];
        }
        return names;
    }

}
