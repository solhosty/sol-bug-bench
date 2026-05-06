// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SimpleNFT.sol";

contract SimpleNFTTest is Test {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    SimpleNFT public nft;
    address public alice;
    address public bob;

    function setUp() public {
        nft = new SimpleNFT();
        alice = makeAddr("alice");
        bob = makeAddr("bob");
    }

    function test_NameAndSymbol() public view {
        assertEq(nft.name(), "SimpleNFT");
        assertEq(nft.symbol(), "SNFT");
    }

    function test_Mint_AssignsOwnershipAndIncrementsId() public {
        uint256 tokenId = nft.mint(alice);

        assertEq(tokenId, 0);
        assertEq(nft.ownerOf(0), alice);
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.nextTokenId(), 1);
    }

    function test_Mint_MultipleTokens() public {
        nft.mint(alice);
        nft.mint(bob);

        assertEq(nft.ownerOf(0), alice);
        assertEq(nft.ownerOf(1), bob);
        assertEq(nft.nextTokenId(), 2);
    }

    function test_Mint_EmitsTransferEvent() public {
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), alice, 0);

        nft.mint(alice);
    }

    function test_RevertWhen_MintToZeroAddress() public {
        vm.expectRevert();
        nft.mint(address(0));
    }
}
