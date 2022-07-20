// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/**
 * @title LbSkills contract
 * @author gifMaker - contact@littlebits.club
 * @notice v1.00 / 2022
 * @dev Littlebits metaverse - Skills Manager
 */

import "@openzeppelin/contracts/access/Ownable.sol";

contract LbSkills is Ownable {

    struct Skill {
        uint[] skillLevels;
        uint[] skillLevelsTicks;
        uint[] skillBonuses;
    }

    mapping(string => Skill) private _skills;

    function registerSkill(uint[] skillLevels, uint[] skillLevelsTicks, uint[] skillBonuses) public ownerOnly {
        
    }




    // SKILL

    // skill brackets (bips)
    uint[10] private skillBrackets = [1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000];
    
    // skill ticks cummulative     0-10    10-20   20-30   30-40   40-50    50-60    60-70    70-80    80-90    90-100
    uint[10] private skillTicks = [120000, 240000, 480000, 720000, 1200000, 1920000, 2880000, 4320000, 7200000, 13200000];
    
    //skill bonus % (bips)                 0-10   10-20  20-30  30-40  40-50  50-60  60-70  70-80  80-90  90-100 100
    uint[11] private skillBonus = [10000, 11000, 11000, 12000, 12000, 13000, 13000, 14000, 14000, 15000, 20000];

    // returns "Worker" skill in bips(0 to 10000) and bracket(0 to 10)
    function getSkillAndBracket(uint totalTicks) public view returns (uint, uint) {
        uint bracket = 0;
        while (bracket < 10) {
            if (totalTicks < skillTicks[bracket]) {
                break;
            }
            bracket++;
        }

        if (bracket == 10) return (10000, bracket);

        uint ticksUntilCurrentBracket = bracket > 0 ? skillTicks[bracket-1] : 0;
        uint remainderTicks = totalTicks - ticksUntilCurrentBracket;
        uint partialSkill = remainderTicks * 1000 / (skillTicks[bracket] - ticksUntilCurrentBracket);
        uint skill = bracket * 1000 + partialSkill;
        return (skill, bracket);
    }

    // 500k blocks br0
    // 500 >= 120?  br1
    // 500 >= 240?  br2
    // 500 >= 480?  br3
    // 500 >= 720?  no   500-480 = 20k
    // 20k / br3-br2   20k / 240 = 83
    // b3 = 3000 -> 3000 + 83 = 3083 current skill

    // 20M blocks ....
    // 20M >= 13M200 br10

}
