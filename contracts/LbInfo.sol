// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/**
 * @title LbInfo contract
 * @author gifMaker - contact@littlebits.club
 * @notice v1.00 / 2022
 * @dev Littlebits meta info
 */

import "./LittlebitsNFT.sol";
import "./LbCharacter.sol";

contract LbInfo {
    LittlebitsNFT private _littlebitsNFT;

    constructor(address _littlebitsNFTAddress){
        _littlebitsNFT = LittlebitsNFT(_littlebitsNFTAddress);
    }

    function getTokensByOwner(address owner) public view returns (uint[] memory) {
        uint balance = _littlebitsNFT.balanceOf(owner);
        uint[] memory tokens = new uint[](balance);
        for (uint256 index = 0; index < balance; index++) {
            tokens[index] = _littlebitsNFT.tokenOfOwnerByIndex(owner, index);
        }
        return tokens;
    }

    // only needed if trying to retrieve 1k+ lbits from a single owner
    // function getTokensByOwner(address owner, uint startInd, uint fetchMax) public view returns (uint[] memory) {
    //     uint balance = _littlebitsNFT.balanceOf(owner);
    //     uint fetchTotal = balance - startInd;
    //     fetchTotal = fetchTotal < fetchMax ? fetchTotal : fetchMax;
    //     uint fetchLimit = startInd + fetchTotal;
    //     uint[] memory tokens = new uint[](fetchTotal);
    //     for (uint256 index = startInd; index < startInd + fetchTotal; index++) {
    //         tokens[index - startInd] = _littlebitsNFT.tokenOfOwnerByIndex(owner, index);
    //     }
    //     return tokens;
    // }
}