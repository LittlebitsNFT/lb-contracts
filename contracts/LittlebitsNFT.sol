// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/**
 * --== NOT FOR RELEASE ==--
 *
 * @title LittlebitsNFT in-development contract 
 * @author gifMaker - contact@littlebits.club
 * @notice v0.82 / 2022
 *
 * --== NOT FOR RELEASE ==--
 */

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./LbAttributeDisplay.sol";
import "./LbCharacter.sol";

/// @custom:security-contact contact@littlebits.club
contract LittlebitsNFT is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable {
    uint private constant MAX_SUPPLY = 10000;
    uint private constant AIRDROP_SUPPLY = 1000;
    uint private constant MINT_PRICE = 3000 ether;

    // failsafe functions lock
    bool public failsafesActive = true;

    // airdrop history
    address[] public airdropReceiversLog;
    
    // authorized mint addresses (for stores custom sales purposes)
    mapping(address => bool) public authorizedMintAddresses;

    // history of every authorized mint address
    address[] public authorizedMintAddressesLog;

    // log of mint number by authorized addresses
    mapping(address => uint) public authorizedMintQuantityLog;
    
    // attributes dictionary address
    LbAttributeDisplay private _attrDisplay;

    // mapping from token id to Character
    mapping(uint => Character) private _characters;

    // Characters waiting to be assigned to tokens
    Character[] private _unresolvedCharacters;

    // minted tokens waiting to be assigned to Characters
    UnresolvedToken[] private _unresolvedTokens;
    
    // next mint id
    uint private _mintId;

    // optional field, to be set if needed
    string private _contractMetadataUrl = "";

    // used for EIP2981, can be adjusted
    uint private _royaltyInBips = 500; 

    // mint unlock
    bool private _mintUnlocked;

    // minted token with no assigned Character
    struct UnresolvedToken {
        uint tokenId;
        uint refBlock;
    }

    constructor(address attrDisplayAddr) ERC721("Littlebits", "LBITS") {
        _attrDisplay = LbAttributeDisplay(attrDisplayAddr);
    }

    ////////////////  ADMIN FUNCTIONS  ////////////////
    function ADMIN_registerCharacters(Character[] memory newCharacters) public onlyOwner {
        uint resolvedCharacters = totalSupply() - getUnresolvedTokensLength();
        require(
            resolvedCharacters + getUnresolvedCharactersLength() + newCharacters.length
            <= MAX_SUPPLY, "More characters than max supply"
        );

        for (uint i = 0; i < newCharacters.length; i++) {
            _unresolvedCharacters.push(newCharacters[i]);
        }
    }

    function ADMIN_airdrop(address[] memory winners) public onlyOwner {
        require(airdropReceiversLog.length + winners.length <= AIRDROP_SUPPLY);
        for (uint i = 0; i < winners.length; i++) {
            airdropReceiversLog.push(winners[i]);
            _mintToken(winners[i]);
        }
    }

    function ADMIN_setMintAddressAuth(address addr, bool state) public onlyOwner {
        authorizedMintAddresses[addr] = state;
        if (state == true){
            authorizedMintAddressesLog.push(addr);
        }
    }

    function ADMIN_withdrawFunds() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function ADMIN_setContractMetadata(string memory contractMetadataUrl) public onlyOwner {
        _contractMetadataUrl = contractMetadataUrl;
    }

    function ADMIN_setRoyaltiesInBips(uint royaltyInBips) public onlyOwner {
        require(royaltyInBips <= 10000);
        _royaltyInBips = royaltyInBips;
    }

    function ADMIN_setMintUnlocked(bool state) public onlyOwner {
        _mintUnlocked = state;
    }

    function ADMIN_failsafeUpdateURI(uint tokenId, string memory newTokenURI) public onlyOwner {
        require(failsafesActive, "Failsafe permanently disabled");
        _setTokenURI(tokenId, newTokenURI);
    }

    function ADMIN_failsafeUpdateCharacter(uint tokenId, Character memory character) public onlyOwner {
        require(failsafesActive, "Failsafe permanently disabled");
        _characters[tokenId] = character;
    }

    function ADMIN_disableFailsafes(uint tokenId, Character memory character) public onlyOwner {
        failsafesActive = false;
    }

    ////////////////  PUBLIC FUNCTIONS  ////////////////
    function buyLittlebits(uint quantity) public payable {
        require (msg.value == quantity * MINT_PRICE);
        for (uint i = 0; i < quantity; i++) {
            _mintToken(msg.sender);
        }
    }

    // for stores custom sales, must be registered by ADMIN_setMintAddressAuth
    function delegatedMint(uint quantity, address destination) public {
        require(authorizedMintAddresses[msg.sender]);
        require(_mintId < MAX_SUPPLY, "Max supply reached");
        for (uint i = 0; i < quantity; i++) {
            _mintToken(destination);
        }
        authorizedMintQuantityLog[msg.sender] += quantity;
    }

    // try to assign any unresolved tokens to available Characters
    function resolveTokens(uint maxResolves) public {
        require(_unresolvedTokens.length > 0, "No tokens to be resolved");
        require(maxResolves > 0, "Invalid parameter");
        uint i = 0;
        while (i < _unresolvedTokens.length) {
            bytes32 tokenBlockHash = blockhash(_unresolvedTokens[i].refBlock);
            if (tokenBlockHash != 0) {
                // get next unresolved token
                uint tokenId = _unresolvedTokens[i].tokenId;
                // get random unresolved_character index
                uint randomCharacterInd = uint(keccak256(abi.encodePacked(tokenBlockHash, tokenId))) % _unresolvedCharacters.length;
                // resolve token
                _resolveToken(tokenId, randomCharacterInd);
                // remove unresolved token
                _unresolvedTokens[i] = _unresolvedTokens[_unresolvedTokens.length-1];
                _unresolvedTokens.pop();
            }
            else {
                // unresolved token timeout! this token wasnt resolved in time
                // new ref block assigned
                _unresolvedTokens[i].refBlock = block.number;
                i++;
            }
            if (--maxResolves == 0) break;
        }
    }

    // get characters from address
    function getCharacters(address owner) public view returns (Character[] memory) {
        uint ownerBalance = balanceOf(owner);
        Character[] memory ownerCharacters = new Character[](ownerBalance);
        for (uint i = 0; i < ownerBalance; i++) {
            uint token = tokenOfOwnerByIndex(owner, i);
            ownerCharacters[i] = _characters[token];
        }
        return ownerCharacters;
    }

    function getUnresolvedTokensLength() public view returns (uint) {
        return _unresolvedTokens.length;
    }

    function getUnresolvedCharactersLength() public view returns (uint) {
        return _unresolvedCharacters.length;
    }

    function getAirdropReceiversLength() public view returns (uint) {
        return airdropReceiversLog.length;
    }

    // optional standard to be implemented if needed
    function contractURI() public view returns (string memory) {
        return _contractMetadataUrl;
    }
    
    // royalty standard EIP2981
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) external view returns (address receiver, uint256 royaltyAmount) {
        uint256 calculatedRoyalties = _salePrice / 10000 * _royaltyInBips;
        return(owner(), calculatedRoyalties);
    }

    ////////////////  PRIVATE FUNCTIONS  ////////////////
    function _mintToken(address to) private {
        require(_mintId < (MAX_SUPPLY - AIRDROP_SUPPLY + airdropReceiversLog.length), "Max supply reached");
        require(_mintUnlocked, "Minting not unlocked");
        _mint(to, _mintId);
        _unresolvedTokens.push(UnresolvedToken(_mintId, block.number));
        _mintId++;
    }

    // assign available Character to token
    function _resolveToken(uint tokenId, uint characterInd) private {
        // get Character
        Character memory character = _unresolvedCharacters[characterInd];
        // register Character to token 
        _characters[tokenId] = character;
        // set token URI
        //string memory newTokenUri = _buildMetadata(character, tokenId);
        string memory newTokenUri = _attrDisplay.buildMetadata(character, tokenId);
        _setTokenURI(tokenId, newTokenUri);
        // make Character unavailable
        _unresolvedCharacters[characterInd] = _unresolvedCharacters[_unresolvedCharacters.length-1];
        _unresolvedCharacters.pop();
    }

    ////////////////  OVERRIDES  ////////////////
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return interfaceId == 0x2a55205a // royalty standard EIP2981
        || super.supportsInterface(interfaceId);
    }

    function renounceOwnership() public view override(Ownable) onlyOwner {
        revert("renounce ownership disabled");
    }

    ////////////////  MULTIPLE INHERITANCE OVERRIDES  ////////////////
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }
}
