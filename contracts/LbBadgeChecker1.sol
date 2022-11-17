// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/**
 * @title LbBadgeChecker1 contract
 * @author gifMaker - contact@littlebits.club
 * @notice v1.00 / 2022
 * @dev Badge Checker 1 contract
 */

import "./LbWorld.sol";
import "./LbFactory.sol";
import "./LbSkills.sol";
import { BadgeValidator } from "./LbBadges.sol";

contract LbBadgeChecker1 is BadgeValidator {
    LbWorld private _lbWorld;
    LbFactory private _lbFactory;
    LbSkills private _lbSkills;

    uint public constant WORKING_SKILL_ID = 1;
    uint public constant BLOCKS_PER_HOUR = 60 * 60 / 3;

    constructor(address lbWorldAddress, address lbFactoryAddress, address lbSkillsAddress) {
        _lbWorld = LbWorld(lbWorldAddress);
        _lbFactory = LbFactory(lbFactoryAddress);
        _lbSkills = LbSkills(lbSkillsAddress);
    }

    function checkBadgeRequirements(uint tokenId, uint badgeId, uint[] memory optionalData) public view returns (bool) {
        // flairs owned
        if (badgeId == 1001) {
            uint flairsAcquired = _lbWorld.getFlairsOwnedSize(tokenId);
            return flairsAcquired >= 3;
        } 
        if (badgeId == 1002) {
            uint flairsAcquired = _lbWorld.getFlairsOwnedSize(tokenId);
            return flairsAcquired >= 10;
        } 
        if (badgeId == 1003) {
            uint flairsAcquired = _lbWorld.getFlairsOwnedSize(tokenId);
            return flairsAcquired >= 25;
        }
        // factory total paid
        if (badgeId == 2001) {
            Worker memory worker = _lbFactory.getWorker(tokenId);
            return worker.totalPaid >= 10 * 100;
        }
        if (badgeId == 2002) {
            Worker memory worker = _lbFactory.getWorker(tokenId);
            return worker.totalPaid >= 100 * 100;
        }
        if (badgeId == 2003) {
            Worker memory worker = _lbFactory.getWorker(tokenId);
            return worker.totalPaid >= 500 * 100;
        }
        if (badgeId == 2004) {
            Worker memory worker = _lbFactory.getWorker(tokenId);
            return worker.totalPaid >= 1000 * 100;
        }
        if (badgeId == 2005) {
            Worker memory worker = _lbFactory.getWorker(tokenId);
            return worker.totalPaid >= 5000 * 100;
        }
        // working skill
        if (badgeId == 3001) {
            uint workingSkill = _lbSkills.getTokenSkill(tokenId, WORKING_SKILL_ID);
            return workingSkill >= 10 * 100;
        }
        if (badgeId == 3002) {
            uint workingSkill = _lbSkills.getTokenSkill(tokenId, WORKING_SKILL_ID);
            return workingSkill >= 30 * 100;
        }
        if (badgeId == 3003) {
            uint workingSkill = _lbSkills.getTokenSkill(tokenId, WORKING_SKILL_ID);
            return workingSkill >= 90 * 100;
        }
        if (badgeId == 3004) {
            uint workingSkill = _lbSkills.getTokenSkill(tokenId, WORKING_SKILL_ID);
            return workingSkill >= 100 * 100;
        }
        // world time shown
        if (badgeId == 4001) {
            uint totalBlocksPlaced = _lbWorld.getTotalBlocksPlaced(tokenId);
            return (totalBlocksPlaced / BLOCKS_PER_HOUR) >= 10;
        }
        if (badgeId == 4002) {
            uint totalBlocksPlaced = _lbWorld.getTotalBlocksPlaced(tokenId);
            return (totalBlocksPlaced / BLOCKS_PER_HOUR) >= 100;
        }
        revert('unexpected badgeId');
    }
}
