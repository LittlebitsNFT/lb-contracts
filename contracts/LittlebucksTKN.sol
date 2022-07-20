// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./LbAccess.sol";

contract LittlebucksTKN is ERC20, ERC20Burnable, Pausable, LbAccess {
    // allows this contract to be shutdown and relaunched (ex: in case of upgrades or if admin control is compromised)
    // funds can be frozen and carried over to a new contract
    bool public pausedForever = false;
    
    // access roles
    uint public constant ADMIN_ROLE = 99;
    uint public constant MINTER_ROLE = 1;
    uint public constant TRANSFERER_ROLE = 2;

    constructor() ERC20("Testbucks", "TBUCKS") {
        // access control config
        ACCESS_WAIT_BLOCKS = 0; // tmp testing, default: 200_000
        ACCESS_ADMIN_ROLEID = ADMIN_ROLE;
        hasRole[msg.sender][ADMIN_ROLE] = true;

        // tmp test
        hasRole[msg.sender][MINTER_ROLE] = true;        // TODO:  remove this, only registered contracts should mint
        hasRole[msg.sender][TRANSFERER_ROLE] = true;    // TODO:  remove this, only registered contracts should tranfer
    }

    // pause all minting and transfers
    function ADMIN_pause() public {
        require(hasRole[msg.sender][uint(ADMIN_ROLE)], 'ADMIN access required');
        _pause();
    }

    // unpause if not locked
    function ADMIN_unpause() public {
        require(hasRole[msg.sender][ADMIN_ROLE], 'ADMIN access required');
        require(!pausedForever);
        _unpause();
    }

    // contract lock
    function ADMIN_pauseForever() public {
        require(hasRole[msg.sender][ADMIN_ROLE], 'ADMIN access required');
        _pause();
        pausedForever = true;
    }

    // authorized contracts transfer
    function TRANSFERER_transfer(address from, address to, uint256 amount) public {
        require(hasRole[msg.sender][TRANSFERER_ROLE], 'TRANSFERER access required');
        _transfer(from, to, amount);
    }

    // authorized contracts mint
    function MINTER_mint(address to, uint256 amount) public {
        require(hasRole[msg.sender][MINTER_ROLE], 'MINTER access required');
        _mint(to, amount);
    }

    // blocks transfers if paused
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal whenNotPaused override {
        super._beforeTokenTransfer(from, to, amount);
    }

    // lbucks is real money
    function decimals() public view override returns (uint8) {
        return 2;
    }

}