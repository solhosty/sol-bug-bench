// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SimpleNFT.sol";

contract SimpleNFTTest is Test {
    SimpleNFT public nft;
    address public owner;
    address public alice;
    address public bob;

    function setUp() public {
        owner = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        nft = new SimpleNFT();
    }

    function testNameAndSymbol() public {
        assertEq(nft.name(), "SimpleNFT");
        assertEq(nft.symbol(), "SNFT");
    }

    function testMintAssignsOwnerAndIncrementsId() public {
        nft.mint(alice);

        assertEq(nft.ownerOf(0), alice);
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.nextTokenId(), 1);
    }

    function testMintMultipleTokens() public {
        nft.mint(alice);
        nft.mint(alice);
        nft.mint(bob);

        assertEq(nft.ownerOf(0), alice);
        assertEq(nft.ownerOf(1), alice);
        assertEq(nft.ownerOf(2), bob);
        assertEq(nft.balanceOf(alice), 2);
        assertEq(nft.balanceOf(bob), 1);
        assertEq(nft.nextTokenId(), 3);
    }

    function testMintRevertsWhenNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        nft.mint(alice);
    }
}
