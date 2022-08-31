// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/**
 * @title LbSkills contract
 * @author gifMaker - contact@littlebits.club
 * @notice v1.00 / 2022
 * @dev Littlebits metaverse - Skills Manager
 */

import "./LbAccess.sol";
import "./LbOpenClose.sol";

struct SkillTracker {
    uint currentBracket; // 0(0-5) to 20(100+)
    uint totalXp;
}

contract LbSkills is LbAccess, LbOpenClose {
    // access roles
    uint public constant ADMIN_ROLE = 99;
    uint public constant SKILLCHANGER_ROLE = 1;
    uint public constant BRACKETSSETTER_ROLE = 2;

    // mapping from (tokenId, skillId) to skillTracker
    mapping(uint => mapping(uint => SkillTracker)) private _skills;

    // bracketId:            0      1        2               19        20       
    // bracket:             0-5    5-10    10-15   ...     95-100   100-105   ...
    // mapping from (skillId, bracketId) to bracket xp cumulative
    mapping(uint => mapping(uint => uint)) private _bracketsXp;

    event SkillUp(uint indexed tokenId, uint indexed skillId, uint change, uint total);

    constructor() {
        // access control config
        ACCESS_WAIT_BLOCKS = 0; // todo: testing, default: 200_000
        ACCESS_ADMIN_ROLEID = ADMIN_ROLE;
        hasRole[msg.sender][ADMIN_ROLE] = true;
    }

    function BRACKETSSETTER_setBrackets(uint skillId, uint[] memory bracketIds, uint[] memory bracketsXp) public {
        require(hasRole[msg.sender][BRACKETSSETTER_ROLE], 'BRACKETSSETTER_ROLE access required');
        require(isOpen, "Building is closed");
        uint bracketsLength = bracketIds.length;
        require(bracketsLength == bracketsXp.length);
        for (uint i = 0; i < bracketsLength; i++) {
            uint bracketId = bracketIds[i];
            uint bracketXp = bracketsXp[i];
            _bracketsXp[skillId][bracketId] = bracketXp;
        }
    }

    function SKILLCHANGER_changeSkill(uint tokenId, uint skillId, uint change) public {
        require(hasRole[msg.sender][SKILLCHANGER_ROLE], 'SKILLCHANGER_ROLE access required');
        require(isOpen, "Building is closed");
        uint currentBracket = _skills[tokenId][skillId].currentBracket;
        uint currentBracketXp = _bracketsXp[skillId][currentBracket];
        // next bracket exists (wont earn xp if at max bracket)
        if (currentBracketXp != 0) {
            uint newTotalXp = _skills[tokenId][skillId].totalXp + change;
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
            emit SkillUp(tokenId, skillId, change, newTotalXp);
        }
    }

    // skill progress in bips (10000 == 100%)
    function getTokenSkill(uint tokenId, uint skillId) public view returns (uint totalProgress) {
        SkillTracker memory skillTracker = _skills[tokenId][skillId];
        uint bracketXp = getBracketXp(skillId, skillTracker.currentBracket);
        uint prevBracketXp = skillTracker.currentBracket == 0 ? 0 : getBracketXp(skillId, skillTracker.currentBracket - 1);
        uint currentBracketProgress = bracketXp == 0 ? 0 : ((skillTracker.totalXp - prevBracketXp) * 10000 * 500) / (bracketXp - prevBracketXp) / 10000; // from 0 to 500
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

    // skill ticks cummulative        0-10     10-20    20-30    30-40    40-50      50-60      60-70      70-80      80-90      90-100
    // uint[10] private skillTicks = [120_000, 240_000, 480_000, 720_000, 1_200_000, 1_920_000, 2_880_000, 4_320_000, 7_200_000, 13_200_000];
    //          +50                       
    // 50       +50
    // 100      +50  
    // 150      +50
    // 200      +100
    // 300      +100
    // 400      +100
    // 500      +100
    // 600      +200
    // 800      +200
    // 1000     +300
    // 1300     +300 
    // 1600     +400
    // 2000     +400 
    // 2400     +600
    // 3000     +600
    // 3600     +1200
    // 4800     +1200 
    // 6000     +2500
    // 8500     +2500
    // 11000    
    //                            0-5  10   15   20   25   30   35   40   45   50    55    60    65    70    75    80    85    90    95    100
    // uint[20] workingSkillReq = [50, 100, 150, 200, 300, 400, 500, 600, 800, 1000, 1300, 1600, 2000, 2400, 3000, 3600, 4800, 6000, 8500, 11000];
}
