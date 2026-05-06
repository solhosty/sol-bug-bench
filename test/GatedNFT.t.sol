// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/GatedNFT.sol";

contract GatedNFTTest is Test {
    GatedNFT nft;
    address owner;
    address alice;
    address bob;

    function setUp() public {
        owner = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        nft = new GatedNFT();
    }

    function test_NameAndSymbol() public view {
        assertEq(nft.name(), "GatedNFT");
        assertEq(nft.symbol(), "GNFT");
    }

    function test_OwnerCanMint() public {
        nft.mint(alice, "ipfs://token/1");

        assertEq(nft.ownerOf(0), alice);
        assertEq(nft.tokenURI(0), "ipfs://token/1");
        assertEq(nft.totalMinted(), 1);
    }

    function test_MintIncrementsTokenId() public {
        nft.mint(alice, "ipfs://token/1");
        nft.mint(bob, "ipfs://token/2");

        assertEq(nft.ownerOf(0), alice);
        assertEq(nft.ownerOf(1), bob);
        assertEq(nft.totalMinted(), 2);
    }

    function test_RevertWhen_NonOwnerMints() public {
        vm.prank(alice);
        vm.expectRevert();
        nft.mint(alice, "ipfs://x");
    }

    function test_Transfer() public {
        nft.mint(alice, "ipfs://token/1");

        vm.prank(alice);
        nft.transferFrom(alice, bob, 0);

        assertEq(nft.ownerOf(0), bob);
    }
}
