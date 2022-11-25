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
//  Different badges can have the same validator (using badgeId to decide)
interface BadgeValidator {
    function checkBadgeRequirements(uint tokenId, uint badgeId, uint[] memory optionalData) external view returns (bool);
}

interface BadgeRewarder {
    function rewardBadgeUnlock(uint tokenId, uint badgeId, address owner) external;
}

contract LbBadges is LbAccess, LbOpenClose {
    // access roles
    uint public constant ADMIN_ROLE = 99;
    uint public constant OTHERCONTRACTS_ROLE = 88;
    uint public constant BADGE_REGISTERER_ROLE = 1; // set / modify badge validators (callbacks)
    uint public constant BADGE_REMOVER_ROLE = 2; // remove badges
    uint public constant BADGE_GIVER_ROLE = 3; // give badges

    // other contracts
    LittlebitsNFT private _littlebitsNFT;

    // (tokenId, badgeId) to owned
    mapping(uint => mapping(uint => bool)) private _isBadgeOwned;

    // tokenId to [badges owned by this token] (for public view / ui listing)
    mapping(uint => uint[]) private _badgesOwned;
    
    // badgeId to badge checker function
    mapping(uint => BadgeValidator) private _badgeCheckerCallback;
    mapping(uint => BadgeRewarder) private _badgeRewarderCallback;

    // (account, badgeId) to number_of_times_unlocked
    mapping(address => mapping(uint => uint)) public unlockCounter;

    event BadgeRegistered(uint indexed badgeId, address indexed validatorAddress);
    event BadgeUnlocked(uint indexed tokenId, uint indexed badgeId);

    constructor(address littlebitsNFT) {
        // access control config
        ACCESS_WAIT_BLOCKS = 0; // todo: testing, default: 200_000
        ACCESS_ADMIN_ROLEID = ADMIN_ROLE;
        hasRole[msg.sender][ADMIN_ROLE] = true;

        // other contracts
        _littlebitsNFT = LittlebitsNFT(littlebitsNFT);
    }

    function BADGE_REGISTERER_registerValidator(uint badgeId, address validatorAddress) public {
        require(hasRole[msg.sender][BADGE_REGISTERER_ROLE], 'BADGE_REGISTERER access required');
        require(isOpen, "Building is closed");
        _badgeCheckerCallback[badgeId] = BadgeValidator(validatorAddress);
        emit BadgeRegistered(badgeId, validatorAddress);
    }

    // will do a full search if startInd is zero. You can specify where it is on the owned list
    function BADGE_REMOVER_removeBadge(uint tokenId, uint badgeId, uint startInd) public {
        require(hasRole[msg.sender][BADGE_REMOVER_ROLE], 'BADGE_REMOVER access required');
        require(isOpen, "Building is closed");
        require(_isBadgeOwned[tokenId][badgeId], 'Badge not owned');
        _isBadgeOwned[tokenId][badgeId] = false;
        // remove from badgesOwned list
        uint badgesOwnedLength = _badgesOwned[tokenId].length;
        for (uint i = startInd; i < badgesOwnedLength; i++) {
            if (_badgesOwned[tokenId][i] == badgeId) {
                _badgesOwned[tokenId][i] = _badgesOwned[tokenId][badgesOwnedLength - 1];
                _badgesOwned[tokenId].pop();
                break;
            }
        }
        // remove from account registry
        address owner = _littlebitsNFT.ownerOf(tokenId);
        unlockCounter[owner][badgeId] -= 1;
    }

    // gives badge without checking for requirements (will still give reward)
    function BADGE_GIVER_giveBadge(uint tokenId, uint badgeId) public {
        require(hasRole[msg.sender][BADGE_GIVER_ROLE], 'BADGE_GIVER access required');
        require(isOpen, "Building is closed");
        if (_isBadgeOwned[tokenId][badgeId]) return;
        address lbOwner = _littlebitsNFT.ownerOf(tokenId);
        _unlockBadge(tokenId, badgeId, lbOwner);
    }

    function OTHERCONTRACTS_setContract(uint contractId, address newAddress) public {
        require(hasRole[msg.sender][OTHERCONTRACTS_ROLE], 'OTHERCONTRACTS access required');
        if (contractId == 0) {
            _littlebitsNFT = LittlebitsNFT(newAddress);
        }
    }
    
    function unlockBadge(uint tokenId, uint badgeId, uint[] memory optionalData) public {
        require(isOpen, "Building is closed");
        address lbOwner = _littlebitsNFT.ownerOf(tokenId);
        require(msg.sender == lbOwner, "Not the owner");
        require(!_isBadgeOwned[tokenId][badgeId], 'Badge already owned');
        bool reqsMet = _badgeCheckerCallback[badgeId].checkBadgeRequirements(tokenId, badgeId, optionalData);
        require(reqsMet, 'Badge requirements not met');
        _unlockBadge(tokenId, badgeId, lbOwner);
    }

    // check if badge requirements are met
    function checkBadgesReqs(uint tokenId, uint[] memory badgeIds, uint[][] memory optionalDatas) public view returns (bool[] memory) {
        uint badgesSize = badgeIds.length;
        require(badgesSize == optionalDatas.length, 'BadgeIds and optionalDatas length differs');
        bool[] memory reqsMetArray = new bool[](badgesSize);
        for (uint i = 0; i < badgesSize; i++) {
            uint badgeId = badgeIds[i];
            uint[] memory optionalData = optionalDatas[i];
            BadgeValidator validator = _badgeCheckerCallback[badgeId];
            bool reqsMet = false;
            if(address(validator) != address(0)) {  // Validator exists
                reqsMet = validator.checkBadgeRequirements(tokenId, badgeId, optionalData);
            }
            reqsMetArray[i] = reqsMet;
        }
        return reqsMetArray;
    }

    // all badgeIds owned by a single token
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

    function getBadgesOwnedFull(uint tokenId) public view returns (uint[] memory) {
        return _badgesOwned[tokenId];
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



    function _unlockBadge(uint tokenId, uint badgeId, address lbOwner) private {
        _isBadgeOwned[tokenId][badgeId] = true;
        _badgesOwned[tokenId].push(badgeId);
        if(address(_badgeRewarderCallback[badgeId]) != address(0)) {
            _badgeRewarderCallback[badgeId].rewardBadgeUnlock(tokenId, badgeId, lbOwner);
        }
        unlockCounter[lbOwner][badgeId] += 1;
        emit BadgeUnlocked(tokenId, badgeId);
    }    

}
