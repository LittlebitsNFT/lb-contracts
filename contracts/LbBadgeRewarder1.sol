// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/**
 * @title LbBadgeRewarder1 contract
 * @author gifMaker - contact@littlebits.club
 * @notice v1.00 / 2022
 * @dev Badge Rewarder 1 contract
 */

import "./LbWorld.sol";
import "./LbOpenClose.sol";
import "./LbAccess.sol";
import { BadgeRewarder } from "./LbBadges.sol";

// access requirements:
// must be FLAIR_GIVER on LbWorld

contract LbBadgeRewarder1 is LbAccess, LbOpenClose, BadgeRewarder {
    // access roles
    uint public constant ADMIN_ROLE = 99;
    uint public constant REWARDER_ROLE = 1; // give rewards

    uint private constant SHINYUP_FLAIRID = 42;
    uint private constant SHINYCOLOR_FLAIRID = 43;
    uint private constant MONEYRAIN_FLAIRID = 58;

    LbWorld private _lbWorld;

    constructor(address lbWorldAddress) {
        // access control config
        ACCESS_WAIT_BLOCKS = 0; // todo: testing, default: 200_000
        ACCESS_ADMIN_ROLEID = ADMIN_ROLE;
        hasRole[msg.sender][ADMIN_ROLE] = true;

        _lbWorld = LbWorld(lbWorldAddress);
    }

    function rewardBadgeUnlock(uint tokenId, uint badgeId, address lbOwner) public {
        require(hasRole[msg.sender][REWARDER_ROLE], 'REWARDER_ROLE access required');
        require(isOpen, "Building is closed");

        // world time shown
        if (badgeId == 1010) {
            _lbWorld.FLAIRGIVER_giveFlair(tokenId, SHINYUP_FLAIRID);
        }
        if (badgeId == 1020) {
            _lbWorld.FLAIRGIVER_giveFlair(tokenId, SHINYCOLOR_FLAIRID);
        }
        // lottery
        if (badgeId == 6777) {
            _lbWorld.FLAIRGIVER_giveFlair(tokenId, MONEYRAIN_FLAIRID);
        }
        revert('unexpected badgeId');
    }
}
