// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SimpleBurnTokenV3.sol";

contract SimpleBurnTokenV3Test is Test {
    SimpleBurnTokenV3 public token;
    address public owner;
    address public burner;
    uint256 public constant INITIAL_SUPPLY = 1_000_000 * 10 ** 18;

    function setUp() public {
        owner = address(this);
        burner = makeAddr("burner");
        token = new SimpleBurnTokenV3("BurnToken", "BURN", INITIAL_SUPPLY);
    }

    function testInitialSupplyAndBalance() public {
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
    }

    function testBurnReducesBalanceAndTotalSupply() public {
        uint256 amountToBurn = 100 * 10 ** 18;

        token.burn(amountToBurn);

        assertEq(token.totalSupply(), INITIAL_SUPPLY - amountToBurn);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - amountToBurn);
    }

    function testBurnFromWithAllowance() public {
        uint256 transferAmount = 1_000 * 10 ** 18;
        uint256 burnAmount = 300 * 10 ** 18;

        token.transfer(burner, transferAmount);

        vm.prank(burner);
        token.approve(owner, burnAmount);

        token.burnFrom(burner, burnAmount);

        assertEq(token.balanceOf(burner), transferAmount - burnAmount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - burnAmount);
        assertEq(token.allowance(burner, owner), 0);
    }

    function test_RevertWhen_BurnFromWithoutAllowance() public {
        uint256 transferAmount = 1_000 * 10 ** 18;
        uint256 burnAmount = 300 * 10 ** 18;

        token.transfer(burner, transferAmount);

        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientAllowance(address,uint256,uint256)",
                owner,
                0,
                burnAmount
            )
        );
        token.burnFrom(burner, burnAmount);
    }

    function test_RevertWhen_BurnMoreThanBalance() public {
        uint256 burnAmount = 1;

        vm.prank(burner);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientBalance(address,uint256,uint256)",
                burner,
                0,
                burnAmount
            )
        );
        token.burn(burnAmount);
    }
}
