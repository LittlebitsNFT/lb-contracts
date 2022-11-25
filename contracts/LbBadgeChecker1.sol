// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/**
 * @title LbBadgeChecker1 contract
 * @author gifMaker - contact@littlebits.club
 * @notice v1.00 / 2022
 * @dev Badge Checker 1 contract
 */

import "./LbWorld.sol";
import "./LbSkills.sol";
import { BadgeValidator } from "./LbBadges.sol";

contract LbBadgeChecker1 is BadgeValidator {
    LbWorld private _lbWorld;
    LbSkills private _lbSkills;

    uint private constant WORKING_SKILL_ID = 1;
    uint private constant BLOCKS_PER_HOUR = 60 * 60 / 3;

    constructor(address lbWorldAddress, address lbSkillsAddress) {
        _lbWorld = LbWorld(lbWorldAddress);
        _lbSkills = LbSkills(lbSkillsAddress);
    }

    function checkBadgeRequirements(uint tokenId, uint badgeId, uint[] memory optionalData) public view returns (bool) {
        if (badgeId == 3004) {
            uint workingSkill = _lbSkills.getTokenSkill(tokenId, WORKING_SKILL_ID);
            return workingSkill >= 100 * 100;
        }
        // world time shown
        if (badgeId == 4001) {
            uint totalBlocksPlaced = _lbWorld.getTotalBlocksPlaced(tokenId);
            return (totalBlocksPlaced / BLOCKS_PER_HOUR) >= 100;
        }
        if (badgeId == 4002) {
            uint totalBlocksPlaced = _lbWorld.getTotalBlocksPlaced(tokenId);
            return (totalBlocksPlaced / BLOCKS_PER_HOUR) >= 1000;
        }
        revert('unexpected badgeId');
    }
}
