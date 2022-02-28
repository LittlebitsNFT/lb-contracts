// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * --== NOT FOR RELEASE ==--
 *
 * @title LbCharacter in-development contract 
 * @author gifMaker - contact@littlebits.club
 * @notice v0.81 / 2022
 * @dev LittlebitsNFT token on-chain metadata -- each token is a Character
 *
 * --== NOT FOR RELEASE ==--
 */
contract LbCharacter {
    // AttributeId AttributeKey;
    // 0 gender; 1 rarity; 2 costume; 3 hat; 4 hair; 5 glasses; 6 eyes; 7 nose;
    // 8 beard; 9 bowtie; 10 jacket; 11 torso; 12 legs; 13 shoes; 14 skin;
    struct Character {
        uint8[15] attributes;
        string imageId;
    }
}