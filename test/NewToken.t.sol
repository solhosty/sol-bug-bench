// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/NewToken.sol";

contract NewTokenTest is Test {
    NewToken token;
    address alice;
    address bob;

    function setUp() public {
        token = new NewToken(1_000_000e18);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
    }

    function test_NameAndSymbol() public view {
        assertEq(token.name(), "NewToken");
        assertEq(token.symbol(), "NTK");
    }

    function test_InitialSupplyMintedToDeployer() public view {
        assertEq(token.balanceOf(address(this)), 1_000_000e18);
        assertEq(token.totalSupply(), 1_000_000e18);
    }

    function test_Mint() public {
        token.mint(alice, 100e18);

        assertEq(token.balanceOf(alice), 100e18);
        assertEq(token.totalSupply(), 1_000_100e18);
    }

    function test_Transfer() public {
        token.mint(alice, 100e18);

        vm.prank(alice);
        bool transferred = token.transfer(bob, 40e18);

        assertTrue(transferred);

        assertEq(token.balanceOf(alice), 60e18);
        assertEq(token.balanceOf(bob), 40e18);
    }

    function test_RevertWhen_TransferExceedsBalance() public {
        vm.prank(alice);
        (bool success, ) =
            address(token).call(abi.encodeWithSelector(token.transfer.selector, bob, 1));

        assertFalse(success);
    }
}
