// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/**
 * @title LbBadgeAccChecker1 contract
 * @author gifMaker - contact@littlebits.club
 * @notice v1.00 / 2022
 * @dev Badge Checker 1 contract
 */

import "./LbWorld.sol";
import "./LbFactory.sol";
import "./LbSkills.sol";
import "./LbBadges.sol";
import { BadgeAccValidator } from "./LbBadgesAcc.sol";

contract LbBadgeAccChecker1 is BadgeAccValidator {
    LbWorld private _lbWorld;
    LbFactory private _lbFactory;
    LbSkills private _lbSkills;
    LbBadges private _lbBadges;

    uint private constant WORKING_SKILL_ID = 1;
    uint private constant BLOCKS_PER_HOUR = 60 * 60 / 3;

    constructor(address lbWorldAddress, address lbFactoryAddress, address lbSkillsAddress, address lbBadgesAddress) {
        _lbWorld = LbWorld(lbWorldAddress);
        _lbFactory = LbFactory(lbFactoryAddress);
        _lbSkills = LbSkills(lbSkillsAddress);
        _lbBadges = LbBadges(lbBadgesAddress);
    }

    function checkBadgeRequirements(address account, uint badgeId, uint[] memory optionalData) public view returns (bool) {
        // flairs owned
        if (badgeId == 1001) {
            uint flairsAcquired = _lbWorld.getAccMaxFlairsSingleToken(account);
            return flairsAcquired >= 3;
        } 
        if (badgeId == 1002) {
            uint flairsAcquired = _lbWorld.getAccMaxFlairsSingleToken(account);
            return flairsAcquired >= 10;
        } 
        if (badgeId == 1003) {
            uint flairsAcquired = _lbWorld.getAccMaxFlairsSingleToken(account);
            return flairsAcquired >= 25;
        }
        // factory total paid
        if (badgeId == 2001) {
            uint accTotalPaid = _lbFactory.accountTotalEarnings(account);
            return accTotalPaid >= 10 * 100;
        }
        if (badgeId == 2002) {
            uint accTotalPaid = _lbFactory.accountTotalEarnings(account);
            return accTotalPaid >= 100 * 100;
        }
        if (badgeId == 2003) {
            uint accTotalPaid = _lbFactory.accountTotalEarnings(account);
            return accTotalPaid >= 500 * 100;
        }
        if (badgeId == 2004) {
            uint accTotalPaid = _lbFactory.accountTotalEarnings(account);
            return accTotalPaid >= 1000 * 100;
        }
        if (badgeId == 2005) {
            uint accTotalPaid = _lbFactory.accountTotalEarnings(account);
            return accTotalPaid >= 5000 * 100;
        }
        // working skill
        if (badgeId == 3001) {
            uint workingSkill = _lbSkills.accMaxSkill(account, WORKING_SKILL_ID);
            return workingSkill >= 30 * 100;
        }
        if (badgeId == 3002) {
            uint workingSkill = _lbSkills.accMaxSkill(account, WORKING_SKILL_ID);
            return workingSkill >= 50 * 100;
        }
        if (badgeId == 3003) {
            uint workingSkill = _lbSkills.accMaxSkill(account, WORKING_SKILL_ID);
            return workingSkill >= 70 * 100;
        }
        if (badgeId == 3004) {
            uint workingSkill = _lbSkills.accMaxSkill(account, WORKING_SKILL_ID);
            return workingSkill >= 90 * 100;
        }
        if (badgeId == 3005) {
            uint workingSkill = _lbSkills.accMaxSkill(account, WORKING_SKILL_ID);
            return workingSkill >= 100 * 100;
        }
        // token badge unlocked
        if (badgeId == 4001) {
            uint tokenBadgeId = 4001;
            uint unlockedByAccount = _lbBadges.accountUnlockCounter(account, tokenBadgeId);
            return unlockedByAccount > 0;
        }
        if (badgeId == 4002) {
            uint tokenBadgeId = 4002;
            uint unlockedByAccount = _lbBadges.accountUnlockCounter(account, tokenBadgeId);
            return unlockedByAccount > 0;
        }
        revert('unexpected badgeId');
    }
}
