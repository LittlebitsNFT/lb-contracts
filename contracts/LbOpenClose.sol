// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/**
 * @title LbWorld contract
 * @author gifMaker - contact@littlebits.club
 * @notice v1.00 / 2022
 * @dev Littlebits OpenClose contract
 */

import "./LittlebitsNFT.sol";
import "./LbCharacter.sol";
import "./LittlebucksTKN.sol";
import "./LbAccess.sol";

// simple open/close state contract
// allows ADMIN to open, close or permanently close the contract
// what each state means is open to implementation
contract LbOpenClose is LbAccess {
    // allows this contract to be open/closed
    bool public isOpen = true;

    // allows this contract to be permanently closed
    bool public permanentlyClosed = false;

    // contract open
    function ADMIN_openContract() virtual external {
        require(hasRole[msg.sender][ACCESS_ADMIN_ROLEID], 'ADMIN access required');
        require(!permanentlyClosed, 'Contract permanently closed');
        isOpen = true;
    }

    // contract close
    function ADMIN_closeContract() virtual external {
        require(hasRole[msg.sender][ACCESS_ADMIN_ROLEID], 'ADMIN access required');
        isOpen = false;
    }

    // contract shutdown
    function ADMIN_closePermanently() virtual external {
        require(hasRole[msg.sender][ACCESS_ADMIN_ROLEID], 'ADMIN access required');
        isOpen = false;
        permanentlyClosed = true;
    }
}