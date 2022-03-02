// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/**
 * @title LbSales contract
 * @author gifMaker - contact@littlebits.club
 * @notice v1.00 / 2022
 * @dev Littlebits bundle mints
 */

import "@openzeppelin/contracts/access/Ownable.sol";
import "./LittlebitsNFT.sol";

contract LbSales is Ownable {

    uint private constant PRICE_ONE = 3000 ether;
    uint private constant PRICE_THREE = 8000 ether;
    uint private constant PRICE_TEN = 24000 ether;

    LittlebitsNFT private _lbContract;
    
    constructor(address _lbContractAddress){
        _lbContract = LittlebitsNFT(_lbContractAddress);
    }

    function BUY_ONE_LBITS() public payable {
        require(msg.value == PRICE_ONE, "exactly 3000 MTV needed");
        _lbContract.delegatedMint(1, msg.sender);
    }

    function BUY_THREE_LBITS() public payable {
        require(msg.value == PRICE_THREE, "exactly 8000 MTV needed");
        _lbContract.delegatedMint(3, msg.sender);
    }

    function BUY_TEN_LBITS() public payable {
        require(msg.value == PRICE_TEN, "exactly 24000 MTV needed");
        _lbContract.delegatedMint(10, msg.sender);
    }

    function ADMIN_withdrawFunds() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
