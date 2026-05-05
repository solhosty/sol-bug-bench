// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SimpleNFT
 * @dev Minimal ERC721 NFT contract with owner-gated minting
 */
contract SimpleNFT is ERC721, Ownable {
    uint256 public nextTokenId;

    /**
     * @dev Initializes the NFT collection metadata and owner
     */
    constructor() ERC721("SimpleNFT", "SNFT") Ownable(msg.sender) {}

    /**
     * @dev Mints a new NFT to the specified address
     * @param to The address that will receive the minted NFT
     * @return tokenId The token ID that was minted
     */
    function mint(address to) external onlyOwner returns (uint256 tokenId) {
        tokenId = nextTokenId;
        _safeMint(to, tokenId);
        nextTokenId = tokenId + 1;
    }
}
