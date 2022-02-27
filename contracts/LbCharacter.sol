// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * --== NOT FOR RELEASE ==--
 *
 * @title LbCharacter in-development contract 
 * @author gifMaker - contact@littlebits.club
 * @notice v0.8 / 2022
 * @dev LittlebitsNFT token on-chain metadata -- each token is a Character
 *
 * --== NOT FOR RELEASE ==--
 */
contract LbCharacter {
    // AttributeId AttributeKey;
    // 0 gender; 1 rarity; 2 costume; 3 hat; 4 hair; 5 glasses; 6 eyes; 7 nose;
    // 8 bowtie; 9 beard; 10 shoes; 11 jacket; 12 torso; 13 legs; 14 skin;
    struct Character {
        uint8[15] attributes;
        string imageId;
    }
}