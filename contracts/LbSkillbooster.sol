// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/**
 * @title LbSkillbooster contract
 * @author gifMaker - contact@littlebits.club
 * @notice v1.00 / 2022
 * @dev Littlebits metaverse - Skill Booster
 */

import "./LittlebitsNFT.sol";
import "./LbSkills.sol";
import "./LbAccess.sol";
import "./LbOpenClose.sol";

// access requirements:
// must be SKILLCHANGER_ROLE on LbSkills

contract LbSkillbooster is LbAccess, LbOpenClose {
    // access roles
    uint public constant ADMIN_ROLE = 99;
    uint public constant SKILLCHANGER_ROLE = 1;
    uint public constant BOOSTERSETTER_ROLE = 2;

    // mapping from tokenId to boostInBips
    mapping(uint => uint) public boostBonus;

    // rarity bonuses in bips        0%  1%   2%   3%   5%   10%
    uint[6] private _rarityBonuses = [0, 100, 200, 300, 500, 1000];

    // other contracts
    LittlebitsNFT private _littlebitsNFT;
    LbSkills private _lbSkills;

    constructor(address lbitsNFT, address lbSkills) {
        // access control config
        ACCESS_WAIT_BLOCKS = 0; // todo: testing, default: 200_000
        ACCESS_ADMIN_ROLEID = ADMIN_ROLE;
        hasRole[msg.sender][ADMIN_ROLE] = true;

        // other contracts refs
        _littlebitsNFT = LittlebitsNFT(lbitsNFT);
        _lbSkills = LbSkills(lbSkills);
    }
    
    // set single use boost
    function BOOSTERSETTER_setBoost(uint tokenId, uint boostPctInBips) public {
        require(hasRole[msg.sender][BOOSTERSETTER_ROLE], 'BOOSTERSETTER_ROLE access required');
        require(isOpen, "Building is closed");
        boostBonus[tokenId] = boostPctInBips;
    }

    // set rarity bonuses
    function BRACKETSSETTER_setRarityBonus(uint[6] memory newRarityBonusesInBips) public {
        require(hasRole[msg.sender][BOOSTERSETTER_ROLE], 'BRACKETSSETTER_ROLE access required');
        require(isOpen, "Building is closed");
        _rarityBonuses = newRarityBonusesInBips;
    }

    function SKILLCHANGER_changeSkill(uint tokenId, uint skillId, uint xpChange) public {
        require(hasRole[msg.sender][SKILLCHANGER_ROLE], 'SKILLCHANGER_ROLE access required');
        require(isOpen, "Building is closed");
        // new xp change
        uint rarityBonusInBips = _getRarityBonusInBips(tokenId);
        uint boostBonusInBips = boostBonus[tokenId];
        uint newXpChange = (xpChange * (10000 + rarityBonusInBips + boostBonusInBips)) / 10000; // base + base * bonuses / 10000    
        // reset boost value
        boostBonus[tokenId] = 0;
        _lbSkills.SKILLCHANGER_changeSkill(tokenId, skillId, newXpChange);
    }

    function getTokenSkill(uint tokenId, uint skillId) public view returns (uint totalProgress) {
        return _lbSkills.getTokenSkill(tokenId, skillId);
    }

    function _getRarityBonusInBips(uint tokenId) private view returns (uint rarityBonus) {
        uint rarity = _littlebitsNFT.getCharacter(tokenId).attributes[0];
        rarityBonus = _rarityBonuses[rarity];
    }

}
