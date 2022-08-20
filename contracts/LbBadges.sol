// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/**
 * @title LbData contract
 * @author gifMaker - contact@littlebits.club
 * @notice v1.00 / 2022
 * @dev Littlebits token and wallet persistent data hub
 */

import "./LittlebitsNFT.sol";
import "./LbAccess.sol";
import "./LbOpenClose.sol";

//  Register/change BadgeId => BadgeValidator as needed
//  Different badges can have the same validator

interface BadgeValidator {
    function checkBadgeRequirements(uint tokenId, uint badgeId, uint[] memory optionalData) external view returns (bool);
}

contract LbBadges is LbAccess, LbOpenClose {
    // access roles
    uint public constant ADMIN_ROLE = 99;
    uint public constant BADGE_REGISTERER_ROLE = 1; // can set/modify badges callbacks

    // other contracts
    LittlebitsNFT private _littlebitsNFT;

    // (tokenId, badgeId) to owned
    mapping(uint => mapping(uint => bool)) private _isBadgeOwned;

    // tokenId to [badges owned by this token] (for public view / ui listing)
    mapping(uint => uint[]) private _badgesOwned;
    
    // badgeId to badge checker function
    mapping(uint => BadgeValidator) private _badgeCheckerCallback;

    constructor(address littlebitsNFT) {
        // access control config
        ACCESS_WAIT_BLOCKS = 0; // todo: testing, default: 200_000
        ACCESS_ADMIN_ROLEID = ADMIN_ROLE;
        hasRole[msg.sender][ADMIN_ROLE] = true;

        // other contracts
        _littlebitsNFT = LittlebitsNFT(littlebitsNFT);
    }

    function BADGE_REGISTERER_register_validator(uint badgeId, address badgeValidator) public {
        require(isOpen, "Building is closed");
        _badgeCheckerCallback[badgeId] = BadgeValidator(badgeValidator);
    }

    function unlockBadge(uint tokenId, uint badgeId, uint[] memory optionalData) public {
        require(isOpen, "Building is closed");
        require(msg.sender == _littlebitsNFT.ownerOf(tokenId), "Not the owner");
        require(!_isBadgeOwned[tokenId][badgeId], 'Badge already owned');
        bool reqsMet = _badgeCheckerCallback[badgeId].checkBadgeRequirements(tokenId, badgeId, optionalData);
        require(reqsMet, 'Badge requirements not met');
        _isBadgeOwned[tokenId][badgeId] = true;
        _badgesOwned[tokenId].push(badgeId);
    }

    function checkBadgesReqs(uint tokenId, uint[] memory badgeIds, uint[] memory optionalData) public view returns (bool[] memory) {
        uint badgesSize = badgeIds.length;
        bool[] memory reqsMetArray = new bool[](badgesSize);
        for (uint i = 0; i < badgesSize; i++) {
            uint badgeId = badgeIds[i];
            bool reqsMet = _badgeCheckerCallback[badgeId].checkBadgeRequirements(tokenId, badgeId, optionalData);
            reqsMetArray[i] = reqsMet;
        }
        return reqsMetArray;
    }

    // all badges owned by a single token
    function getBadgesOwned(uint tokenId, uint startInd, uint fetchMax) public view returns (uint[] memory) {
        uint fetchTotal = _badgesOwned[tokenId].length - startInd;
        fetchTotal = fetchTotal < fetchMax ? fetchTotal : fetchMax;
        uint[] memory returnBadges = new uint[](fetchTotal);
        uint fetchTo = startInd + fetchTotal;
        for (uint i = startInd; i < fetchTo; i++) {
            returnBadges[i - startInd] = _badgesOwned[tokenId][i];
        }
        return returnBadges;
    }

    // amount of badges owned by a single token
    function getBadgesOwnedLength(uint tokenId) public view returns (uint) {
        return _badgesOwned[tokenId].length;
    }

    // check if a badge is owned by a token
    function checkBadgeOwned(uint tokenId, uint badgeId) public view returns (bool) {
        return _isBadgeOwned[tokenId][badgeId];
    }

    // check if a badge is owned for each tokenId-badgeId pair
    function checkBadgeOwnedBatch(uint[] memory tokenIds, uint[] memory badgeIds) public view returns (bool[] memory) {
        uint badgesLength = badgeIds.length;
        require(badgesLength == tokenIds.length, 'Length mismatch');
        bool[] memory ownedArray = new bool[](badgesLength);
        for (uint i = 0; i < badgesLength; i++) {
            uint badgeId = badgeIds[i];
            uint tokenId = tokenIds[i];
            bool isBadgeOwned = _isBadgeOwned[tokenId][badgeId];
            ownedArray[i] = isBadgeOwned;
        }
        return ownedArray;
    }

}
