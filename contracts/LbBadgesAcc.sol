// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/**
 * @title LbData contract
 * @author gifMaker - contact@littlebits.club
 * @notice v1.00 / 2022
 * @dev Littlebits token and wallet persistent data hub
 */

import "./LbAccess.sol";
import "./LbOpenClose.sol";

//  Register/change BadgeId => BadgeValidator as needed
//  Different badges can have the same validator (using badgeId to decide)
interface BadgeAccValidator {
    function checkBadgeRequirements(address account, uint badgeId, uint[] memory optionalData) external view returns (bool);
}

interface BadgeAccRewarder {
    function rewardBadgeUnlock(address account, uint badgeId) external;
}

contract LbBadgesAcc is LbAccess, LbOpenClose {
    // access roles
    uint public constant ADMIN_ROLE = 99;
    uint public constant OTHERCONTRACTS_ROLE = 88;
    uint public constant BADGE_REGISTERER_ROLE = 1; // set / modify badge validators (callbacks)
    uint public constant BADGE_REMOVER_ROLE = 2; // removes badges
    uint public constant BADGE_GIVER_ROLE = 3; // gives badges

    // (account, badgeId) to owned
    mapping(address => mapping(uint => bool)) private _isBadgeOwned;

    // account to [badges owned by this account] (for public view / ui listing)
    mapping(address => uint[]) private _badgesOwned;
    
    // badgeId to badge checker function
    mapping(uint => BadgeAccValidator) private _badgeCheckerCallback;
    mapping(uint => BadgeAccRewarder) private _badgeRewarderCallback;

    event BadgeAccRegistered(uint indexed badgeId, address indexed validatorAddress);
    event BadgeAccUnlocked(address indexed account, uint indexed badgeId);

    constructor() {
        // access control config
        ACCESS_WAIT_BLOCKS = 0; // todo: testing, default: 200_000
        ACCESS_ADMIN_ROLEID = ADMIN_ROLE;
        hasRole[msg.sender][ADMIN_ROLE] = true;
        // other contracts
    }

    function BADGE_REGISTERER_registerValidator(uint badgeId, address validatorAddress) public {
        require(hasRole[msg.sender][BADGE_REGISTERER_ROLE], 'BADGE_REGISTERER access required');
        require(isOpen, "Building is closed");
        _badgeCheckerCallback[badgeId] = BadgeAccValidator(validatorAddress);
        emit BadgeAccRegistered(badgeId, validatorAddress);
    }

    // Will do a full search if startInd is zero. You can specify where it is on the owned list
    function BADGE_REMOVER_removeBadge(address account, uint badgeId, uint startInd) public {
        require(hasRole[msg.sender][BADGE_REMOVER_ROLE], 'BADGE_REMOVER access required');
        require(isOpen, "Building is closed");
        require(_isBadgeOwned[account][badgeId], 'Badge not owned');
        _isBadgeOwned[account][badgeId] = false;
        // remove from badgesOwned list.
        uint badgesOwnedLength = _badgesOwned[account].length;
        for (uint i = startInd; i < badgesOwnedLength; i++) {
            if (_badgesOwned[account][i] == badgeId) {
                _badgesOwned[account][i] = _badgesOwned[account][badgesOwnedLength - 1];
                _badgesOwned[account].pop();
                break;
            }
        }
    }

    // gives badge without checking for requirements (will still give reward)
    function BADGE_GIVER_giveBadge(address account, uint badgeId) public {
        require(hasRole[msg.sender][BADGE_GIVER_ROLE], 'BADGE_GIVER access required');
        require(isOpen, "Building is closed");
        if (_isBadgeOwned[account][badgeId]) return;
        _unlockBadge(account, badgeId);
    }

    function unlockBadge(uint badgeId, uint[] memory optionalData) public {
        require(isOpen, "Building is closed");
        address account = msg.sender;
        require(!_isBadgeOwned[account][badgeId], 'Badge already owned');
        bool reqsMet = _badgeCheckerCallback[badgeId].checkBadgeRequirements(account, badgeId, optionalData);
        require(reqsMet, 'Badge requirements not met');
        _unlockBadge(account, badgeId);
    }

    // check if badge requirements are met
    function checkBadgesReqs(address account, uint[] memory badgeIds, uint[][] memory optionalDatas) public view returns (bool[] memory) {
        uint badgesSize = badgeIds.length;
        require(badgesSize == optionalDatas.length, 'BadgeIds and optionalDatas length differs');
        bool[] memory reqsMetArray = new bool[](badgesSize);
        for (uint i = 0; i < badgesSize; i++) {
            uint badgeId = badgeIds[i];
            uint[] memory optionalData = optionalDatas[i];
            BadgeAccValidator validator = _badgeCheckerCallback[badgeId];
            bool reqsMet = false;
            if(address(validator) != address(0)) {  // Validator exists
                reqsMet = validator.checkBadgeRequirements(account, badgeId, optionalData);
            }
            reqsMetArray[i] = reqsMet;
        }
        return reqsMetArray;
    }

    // all badgeIds owned by a single account
    function getBadgesOwned(address account, uint startInd, uint fetchMax) public view returns (uint[] memory) {
        uint fetchTotal = _badgesOwned[account].length - startInd;
        fetchTotal = fetchTotal < fetchMax ? fetchTotal : fetchMax;
        uint[] memory returnBadges = new uint[](fetchTotal);
        uint fetchTo = startInd + fetchTotal;
        for (uint i = startInd; i < fetchTo; i++) {
            returnBadges[i - startInd] = _badgesOwned[account][i];
        }
        return returnBadges;
    }

    function getBadgesOwnedFull(address account) public view returns (uint[] memory) {
        return _badgesOwned[account];
    }

    // amount of badges owned by a single account
    function getBadgesOwnedLength(address account) public view returns (uint) {
        return _badgesOwned[account].length;
    }

    // check if a badge is owned by an account
    function checkBadgeOwned(address account, uint badgeId) public view returns (bool) {
        return _isBadgeOwned[account][badgeId];
    }

    // check if a badge is owned for each account-badgeId pair
    function checkBadgeOwnedBatch(address[] memory accounts, uint[] memory badgeIds) public view returns (bool[] memory) {
        uint badgesLength = badgeIds.length;
        require(badgesLength == accounts.length, 'Length mismatch');
        bool[] memory ownedArray = new bool[](badgesLength);
        for (uint i = 0; i < badgesLength; i++) {
            uint badgeId = badgeIds[i];
            address account = accounts[i];
            bool isBadgeOwned = _isBadgeOwned[account][badgeId];
            ownedArray[i] = isBadgeOwned;
        }
        return ownedArray;
    }

    function _unlockBadge(address account, uint badgeId) private {
        _isBadgeOwned[account][badgeId] = true;
        _badgesOwned[account].push(badgeId);
        if(address(_badgeRewarderCallback[badgeId]) != address(0)) {
            _badgeRewarderCallback[badgeId].rewardBadgeUnlock(account, badgeId);
        }
        emit BadgeAccUnlocked(account, badgeId);
    }
}
