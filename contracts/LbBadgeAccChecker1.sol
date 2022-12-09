// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/**
 * @title LbBadgeAccChecker1 contract
 * @author gifMaker - contact@littlebits.club
 * @notice v1.00 / 2022
 * @dev Badge Checker 1 contract
 */

import "./LittlebitsNFT.sol";
import "./LbWorld.sol";
import "./LbFactory.sol";
import "./LbSkills.sol";
import "./LbBadges.sol";
import "./LbBank.sol";
import "./LbLottery.sol";
import "./LbNames.sol";
import { BadgeAccValidator } from "./LbBadgesAcc.sol";

contract LbBadgeAccChecker1 is BadgeAccValidator {
    LittlebitsNFT private _littlebitsNFT;
    LbWorld private _lbWorld;
    LbFactory private _lbFactory;
    LbSkills private _lbSkills;
    LbBadges private _lbBadges;
    LbBank private _lbBank;
    LbLottery private _lbLottery;
    LbNames private _lbNames;

    uint private constant WORKING_SKILL_ID = 1;
    uint private constant BLOCKS_PER_HOUR = 60 * 60 / 3;
    uint private constant FLAIR_FIREWORKS3 = 28;

    constructor(address littlebitsNFT, address lbWorld, address lbFactory, address lbSkills, address lbBadges, address lbBank, address lbLottery, address lbNames) {
        _littlebitsNFT = LittlebitsNFT(littlebitsNFT);
        _lbWorld = LbWorld(lbWorld);
        _lbFactory = LbFactory(lbFactory);
        _lbSkills = LbSkills(lbSkills);
        _lbBadges = LbBadges(lbBadges);
        _lbBank = LbBank(lbBank);
        _lbLottery = LbLottery(lbLottery);
        _lbNames = LbNames(lbNames);
    }

    function checkBadgeRequirements(address account, uint badgeId, uint[] memory optData) public view returns (bool) {
        //// world
        // number of flairs owned
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
        if (badgeId == 1004) {
            uint flairsAcquired = _lbWorld.getAccMaxFlairsSingleToken(account);
            return flairsAcquired >= 50;
        }
        // casino balcony placement
        if (badgeId == 1005) {
            require(optData.length == 1, 'badgeId 1005 optData not found');
            uint tokenId = optData[0];
            if(account != _littlebitsNFT.ownerOf(tokenId)) return false;
            WorldPlacedInfo memory worldPlacedInfo = _lbWorld.getLastPlacedInfo(tokenId);
            if(worldPlacedInfo.block < block.number - _lbWorld.maxPlacementBlocksConsidered()) return false;
            if(worldPlacedInfo.coords[0] > 1490 && 
                worldPlacedInfo.coords[0] < 1765 && 
                worldPlacedInfo.coords[1] > 1130 && 
                worldPlacedInfo.coords[1] < 1260) return true;
            return false;
        }
        // flair acquired: mecha
        if (badgeId == 1006) {
            uint mechaFlairId = 57;
            return _lbWorld.wasFlairUnlocked(account, mechaFlairId);
        }
        // placed near another token with flair
        if (badgeId == 1007) {
            require(optData.length == 2, 'badgeId 1007 optData not found');
            uint myTokenId = optData[0];
            uint otherTokenId = optData[1];
            // is owner
            if(account != _littlebitsNFT.ownerOf(myTokenId)) return false;
            // both showing
            WorldPlacedInfo memory myWorldPlacedInfo = _lbWorld.getLastPlacedInfo(myTokenId);
            WorldPlacedInfo memory otherWorldPlacedInfo = _lbWorld.getLastPlacedInfo(otherTokenId);
            uint minimumBlock = block.number - _lbWorld.maxPlacementBlocksConsidered();
            if(myWorldPlacedInfo.block < minimumBlock || otherWorldPlacedInfo.block < minimumBlock) return false;
            // using flairs
            if(myWorldPlacedInfo.flairs.length < 1 || otherWorldPlacedInfo.flairs.length < 1) return false;
            // same flair
            if(myWorldPlacedInfo.flairs[0] != otherWorldPlacedInfo.flairs[0]) return false;
            // in range
            bool inRange = testIfInRange(myWorldPlacedInfo.coords, otherWorldPlacedInfo.coords, 50);
            if (!inRange) return false;
            return true;
        }
        // placed token with fireworks near someone with fireworks3
        if (badgeId == 1008) {
            require(optData.length == 2, 'badgeId 1008 optData not found');
            uint myTokenId = optData[0];
            uint otherTokenId = optData[1];
            // is owner
            if(account != _littlebitsNFT.ownerOf(myTokenId)) return false;
            // both showing
            WorldPlacedInfo memory myWorldPlacedInfo = _lbWorld.getLastPlacedInfo(myTokenId);
            WorldPlacedInfo memory otherWorldPlacedInfo = _lbWorld.getLastPlacedInfo(otherTokenId);
            uint minimumBlock = block.number - _lbWorld.maxPlacementBlocksConsidered();
            if(myWorldPlacedInfo.block < minimumBlock || otherWorldPlacedInfo.block < minimumBlock) return false;
            // other using flair
            if(otherWorldPlacedInfo.flairs.length < 1) return false;
            // using fireworks3
            if(otherWorldPlacedInfo.flairs[0] != FLAIR_FIREWORKS3) return false;
            // in range
            bool inRange = testIfInRange(myWorldPlacedInfo.coords, otherWorldPlacedInfo.coords, 100);
            if (!inRange) return false;
            return true;
        }
        //// factory
        // factory total paid
        if (badgeId == 2001) {
            uint accTotalPaid = _lbFactory.accountTotalEarnings(account);
            return accTotalPaid >= 5 * 100;
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
            return accTotalPaid >= 5000 * 100;
        }
        if (badgeId == 2005) {
            uint accTotalPaid = _lbFactory.accountTotalEarnings(account);
            return accTotalPaid >= 100_000 * 100;
        }
        //// skills
        // working skill
        if (badgeId == 3001) {
            uint workingSkill = _lbSkills.accMaxSkill(account, WORKING_SKILL_ID);
            return workingSkill >= 10 * 100;
        }
        if (badgeId == 3002) {
            uint workingSkill = _lbSkills.accMaxSkill(account, WORKING_SKILL_ID);
            return workingSkill >= 30 * 100;
        }
        if (badgeId == 3003) {
            uint workingSkill = _lbSkills.accMaxSkill(account, WORKING_SKILL_ID);
            return workingSkill >= 50 * 100;
        }
        if (badgeId == 3004) {
            uint workingSkill = _lbSkills.accMaxSkill(account, WORKING_SKILL_ID);
            return workingSkill >= 70 * 100;
        }
        if (badgeId == 3005) {
            uint workingSkill = _lbSkills.accMaxSkill(account, WORKING_SKILL_ID);
            return workingSkill >= 90 * 100;
        }
        if (badgeId == 3006) {
            uint workingSkill = _lbSkills.accMaxSkill(account, WORKING_SKILL_ID);
            return workingSkill >= 100 * 100;
        }
        //// badges
        // 100h show
        if (badgeId == 4001) {
            uint tokenBadgeId = 4001;
            uint unlockedByAccount = _lbBadges.unlockCounter(account, tokenBadgeId);
            return unlockedByAccount > 0;
        }
        // 1000h show
        if (badgeId == 4002) {
            uint tokenBadgeId = 4002;
            uint unlockedByAccount = _lbBadges.unlockCounter(account, tokenBadgeId);
            return unlockedByAccount > 0;
        }
        //// bank
        // deposit
        if (badgeId == 5001) {
            uint amount = _lbBank.deposited(account);
            return amount > 0;
        }
        // withdraw
        if (badgeId == 5002) {
            uint amount = _lbBank.alltimeInterest(account);
            return amount > 0;
        }
        //// lottery
        // spend
        if (badgeId == 6001) {
            uint amount = _lbLottery.accountTotalSpent(account);
            return amount > 0;
        }
        //// name
        // set name
        if (badgeId == 7001) {
            uint amount = _lbNames.setnameCounter(account);
            return amount > 0;
        }
        revert('unexpected badgeId');
    }

    function testIfInRange(int[2] memory coords1, int[2] memory coords2, int range) internal pure returns (bool inRange) {
        if ((coords1[0] - coords2[0]) > range ||  (coords1[0] - coords2[0]) < -range ||  (coords1[1] - coords2[1]) > range ||  (coords1[1] - coords2[1]) < -range) {
            return false;
        }
        return true;
    } 

    // function sqrt(uint y) internal pure returns (uint z) {
    //     if (y > 3) {
    //         z = y;
    //         uint x = y / 2 + 1;
    //         while (x < z) {
    //             z = x;
    //             x = (y / x + x) / 2;
    //         }
    //     } else if (y != 0) {
    //         z = 1;
    //     }
    // }
}
