// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/**
 * @title LbSkills contract
 * @author gifMaker - contact@littlebits.club
 * @notice v1.00 / 2022
 * @dev Littlebits metaverse - Skills Manager
 */

import "./LittlebitsNFT.sol";
import "./LbBadges.sol";
import "./LbAccess.sol";
import "./LbOpenClose.sol";

// access requirements:
// must be BADGE_GIVER on LbBadges

struct SkillTracker {
    uint currentBracket; // 0(0-5) to 20(100+)
    uint totalXp;
}

contract LbSkills is LbAccess, LbOpenClose {
    // access roles
    uint public constant ADMIN_ROLE = 99;
    uint public constant OTHERCONTRACTS_ROLE = 88;
    uint public constant SKILLCHANGER_ROLE = 1;
    uint public constant BRACKETSSETTER_ROLE = 2;

    // mapping from (tokenId, skillId) to skillTracker
    mapping(uint => mapping(uint => SkillTracker)) private _skills;

    // bracketId:            0      1        2               19        20       
    // bracket:             0-5    5-10    10-15   ...     95-100   100-105   ...
    // mapping from (skillId, bracketId) to bracket xp cumulative
    mapping(uint => mapping(uint => uint)) private _bracketsXp;

    // mapping from (account, skillId) to max raised skill by account
    mapping(address => mapping(uint => uint)) public accMaxSkill;

    // other contracts
    LittlebitsNFT private _littlebitsNFT;
    LbBadges private _lbBadges;

    event SkillUp(uint indexed tokenId, uint indexed skillId, uint xpChange, uint xpTotal, uint skillTotal);

    constructor(address littlebitsNFTAddr, address lbBadges) {
        // access control config
        ACCESS_WAIT_BLOCKS = 0; // todo: testing, default: 200_000
        ACCESS_ADMIN_ROLEID = ADMIN_ROLE;
        hasRole[msg.sender][ADMIN_ROLE] = true;

        // other contracts refs
        _littlebitsNFT = LittlebitsNFT(littlebitsNFTAddr);
        _lbBadges = LbBadges(lbBadges);
    }

    function BRACKETSSETTER_setBrackets(uint skillId, uint[] memory bracketsXp) public {
        require(hasRole[msg.sender][BRACKETSSETTER_ROLE], 'BRACKETSSETTER_ROLE access required');
        require(isOpen, "Building is closed");
        for (uint i = 0; i < bracketsXp.length; i++) {
            uint bracketId = i;
            uint bracketXp = bracketsXp[i];
            _bracketsXp[skillId][bracketId] = bracketXp;
        }
    }

    function SKILLCHANGER_changeSkill(uint tokenId, uint skillId, uint xpChange) public {
        require(hasRole[msg.sender][SKILLCHANGER_ROLE], 'SKILLCHANGER_ROLE access required');
        require(isOpen, "Building is closed");
        uint currentBracket = _skills[tokenId][skillId].currentBracket;
        uint currentBracketXp = _bracketsXp[skillId][currentBracket];
        // next bracket exists (wont earn xp if at max bracket)
        if (currentBracketXp != 0) {
            uint newTotalXp = _skills[tokenId][skillId].totalXp + xpChange;
            // update xp
            _skills[tokenId][skillId].totalXp = newTotalXp;
            // update bracket
            while (newTotalXp >= currentBracketXp && currentBracketXp != 0) {
                currentBracket += 1;
                currentBracketXp = _bracketsXp[skillId][currentBracket];
                _skills[tokenId][skillId].currentBracket = currentBracket;
            }
            // limit max xp
            if (currentBracketXp == 0) {
                newTotalXp = _bracketsXp[skillId][currentBracket-1];
                _skills[tokenId][skillId].totalXp = newTotalXp;
            }
            uint totalSkill = getTokenSkill(tokenId, skillId);
            // register max skill acquired by account
            address owner = _littlebitsNFT.ownerOf(tokenId);
            if (accMaxSkill[owner][skillId] < totalSkill) {
                accMaxSkill[owner][skillId] = totalSkill;
            }
            // register badge on 10000 skill
            uint badgeId = 3000 + skillId;
            if (totalSkill == 10000) _lbBadges.BADGE_GIVER_giveBadge(tokenId, badgeId);
            emit SkillUp(tokenId, skillId, xpChange, newTotalXp, totalSkill);
        }
    }

    function OTHERCONTRACTS_setContract(uint contractId, address newAddress) public {
        require(hasRole[msg.sender][OTHERCONTRACTS_ROLE], 'OTHERCONTRACTS access required');
        if (contractId == 0) {
            _littlebitsNFT = LittlebitsNFT(newAddress);
        }
        if (contractId == 1) {
            _lbBadges = LbBadges(newAddress);
        }
    }

    // skill progress in bips (10000 == 100%)
    function getTokenSkill(uint tokenId, uint skillId) public view returns (uint totalProgress) {
        SkillTracker memory skillTracker = _skills[tokenId][skillId];
        uint bracketXp = getBracketXp(skillId, skillTracker.currentBracket);
        uint prevBracketXp = skillTracker.currentBracket == 0 ? 0 : getBracketXp(skillId, skillTracker.currentBracket - 1);
        uint currentBracketProgress = bracketXp == 0 ? 0 : ((skillTracker.totalXp - prevBracketXp) * 10000 * 500) / (bracketXp - prevBracketXp) / 10000; // single-bracket progress from 0 to 500
        uint previousBracketsProgress = skillTracker.currentBracket * 500;
        totalProgress = currentBracketProgress + previousBracketsProgress;
    }

    function getTokenSkillBatch(uint[] memory tokenIds, uint[] memory skillIds) public view returns (uint[] memory) {
        uint batchLength = tokenIds.length;
        require(batchLength == skillIds.length, 'Different size arrays');
        uint[] memory tokensSkills = new uint[](batchLength);
        for (uint i = 0; i < batchLength; i++) {
            tokensSkills[i] = getTokenSkill(tokenIds[i], skillIds[i]);
        }
        return tokensSkills;
    }

    function getBracketXp(uint skillId, uint bracketId) public view returns (uint) {
        return _bracketsXp[skillId][bracketId];
    }

    function getTokenSkillTracker(uint tokenId, uint skillId) public view returns (SkillTracker memory tokenSkillTracker) {
        return _skills[tokenId][skillId];
    }

    // skill ticks cummulative
    //                            0-5  10   15   20   25   30   35   40   45   50    55    60    65    70    75    80    85    90    95    100
    // uint[20] workingSkillReq = [50, 100, 150, 200, 300, 400, 500, 600, 800, 1000, 1300, 1600, 2000, 2400, 3000, 3600, 4800, 6000, 8500, 11000];
}
