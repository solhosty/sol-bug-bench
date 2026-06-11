// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/BurnToken.sol";

contract BurnTokenTest is Test {
    BurnToken public burnToken;
    TokenVault public tokenVault;
    address public owner;
    address public user1;
    address public user2;
    address public attacker;

    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);
    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);
    event TokensDestroyed(address indexed caller, uint256 amount);

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        attacker = makeAddr("attacker");

        burnToken = new BurnToken();
        tokenVault = new TokenVault(burnToken);

        burnToken.transfer(user1, 10_000 ether);
        burnToken.transfer(user2, 10_000 ether);
    }

    function testInitialState() public {
        assertEq(burnToken.name(), "Burn Token");
        assertEq(burnToken.symbol(), "BURN");
        assertEq(tokenVault.deposits(user1), 0);
    }

    function testMint() public {
        uint256 mintAmount = 250 ether;

        vm.expectEmit(true, false, false, true);
        emit TokensMinted(user1, mintAmount);

        burnToken.mint(user1, mintAmount);

        assertEq(burnToken.balanceOf(user1), 10_000 ether + mintAmount);
    }

    function testBurn() public {
        uint256 burnAmount = 100 ether;

        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit TokensBurned(user1, burnAmount);
        burnToken.burn(burnAmount);

        assertEq(burnToken.balanceOf(user1), 10_000 ether - burnAmount);
    }

    function testBurnFrom() public {
        uint256 burnAmount = 125 ether;

        vm.startPrank(user2);
        burnToken.approve(user1, burnAmount);
        vm.stopPrank();

        vm.prank(user1);
        burnToken.burnFrom(user2, burnAmount);

        assertEq(burnToken.balanceOf(user2), 10_000 ether - burnAmount);
    }

    function testTokenVaultDepositWithdraw() public {
        uint256 depositAmount = 500 ether;
        uint256 withdrawAmount = 200 ether;

        vm.startPrank(user1);
        burnToken.approve(address(tokenVault), depositAmount);

        vm.expectEmit(true, false, false, true);
        emit Deposit(user1, depositAmount);
        tokenVault.deposit(depositAmount);

        vm.expectEmit(true, false, false, true);
        emit Withdrawal(user1, withdrawAmount);
        tokenVault.withdraw(withdrawAmount);
        vm.stopPrank();

        assertEq(tokenVault.deposits(user1), depositAmount - withdrawAmount);
        assertEq(
            burnToken.balanceOf(address(tokenVault)), depositAmount - withdrawAmount
        );
    }

    function test_RevertWhen_BurnMoreThanBalance() public {
        uint256 userBalance = burnToken.balanceOf(user1);

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientBalance(address,uint256,uint256)",
                user1,
                userBalance,
                userBalance + 1
            )
        );
        burnToken.burn(userBalance + 1);
    }

    function test_RevertWhen_WithdrawMoreThanDeposited() public {
        uint256 depositAmount = 100 ether;

        vm.startPrank(user1);
        burnToken.approve(address(tokenVault), depositAmount);
        tokenVault.deposit(depositAmount);

        vm.expectRevert(stdError.arithmeticError);
        tokenVault.withdraw(depositAmount + 1);
        vm.stopPrank();
    }

    function testMintAccessControlIssue() public {
        uint256 amount = 777 ether;

        vm.prank(attacker);
        burnToken.mint(attacker, amount);

        assertEq(burnToken.balanceOf(attacker), amount);
    }

    function testBurnFromSkipsAllowance() public {
        uint256 amount = 333 ether;

        vm.prank(attacker);
        burnToken.burnFrom(user1, amount);

        assertEq(burnToken.balanceOf(user1), 10_000 ether - amount);
        assertEq(burnToken.allowance(user1, attacker), 0);
    }

    function testVaultBurnAllAccessControlIssue() public {
        uint256 user1Deposit = 600 ether;
        uint256 user2Deposit = 400 ether;

        vm.startPrank(user1);
        burnToken.approve(address(tokenVault), user1Deposit);
        tokenVault.deposit(user1Deposit);
        vm.stopPrank();

        vm.startPrank(user2);
        burnToken.approve(address(tokenVault), user2Deposit);
        tokenVault.deposit(user2Deposit);
        vm.stopPrank();

        vm.prank(attacker);
        vm.expectEmit(true, false, false, true);
        emit TokensDestroyed(attacker, user1Deposit + user2Deposit);
        tokenVault.burnAll();

        assertEq(burnToken.balanceOf(address(tokenVault)), 0);
        assertEq(tokenVault.deposits(user1), user1Deposit);
        assertEq(tokenVault.deposits(user2), user2Deposit);
    }
}
