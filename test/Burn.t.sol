// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/Burn.sol";

contract BurnMockERC20 is ERC20 {
    constructor() ERC20("Burn Mock", "BMK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract BurnTest is Test {
    Burn public burnContract;
    BurnMockERC20 public token;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        token = new BurnMockERC20();
        burnContract = new Burn(token);

        token.mint(user1, 1_000 ether);
        token.mint(user2, 1_000 ether);
    }

    function testDepositAndBurn() public {
        vm.startPrank(user1);
        token.approve(address(burnContract), 200 ether);
        burnContract.deposit(200 ether);
        burnContract.burn(50 ether);
        vm.stopPrank();

        assertEq(burnContract.depositedBalance(user1), 150 ether);
        assertEq(token.balanceOf(burnContract.BURN_ADDRESS()), 50 ether);
    }

    function testBurnFrom() public {
        vm.prank(user1);
        token.approve(address(burnContract), 300 ether);

        vm.prank(user1);
        burnContract.deposit(300 ether);

        burnContract.burnFrom(user1, 100 ether);

        assertEq(burnContract.depositedBalance(user1), 200 ether);
        assertEq(token.balanceOf(burnContract.BURN_ADDRESS()), 100 ether);
    }

    function test_RevertWhen_BurnMoreThanDeposited() public {
        vm.prank(user1);
        token.approve(address(burnContract), 100 ether);

        vm.prank(user1);
        burnContract.deposit(100 ether);

        vm.prank(user1);
        vm.expectRevert("Insufficient deposited balance");
        burnContract.burn(101 ether);
    }

    function test_RevertWhen_BurnFromMoreThanDeposited() public {
        vm.prank(user1);
        token.approve(address(burnContract), 100 ether);

        vm.prank(user1);
        burnContract.deposit(100 ether);

        vm.expectRevert("Insufficient deposited balance");
        burnContract.burnFrom(user1, 101 ether);
    }

    function testUnauthorizedBurnFromIssue() public {
        vm.prank(user1);
        token.approve(address(burnContract), 200 ether);

        vm.prank(user1);
        burnContract.deposit(200 ether);

        vm.prank(user2);
        burnContract.burnFrom(user1, 75 ether);

        assertEq(burnContract.depositedBalance(user1), 125 ether);
        assertEq(token.balanceOf(burnContract.BURN_ADDRESS()), 75 ether);
    }
}
