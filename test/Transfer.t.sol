// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Transfer.sol";

contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");

        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        return true;
    }
}

contract TransferTest is Test {
    Transfer public transferContract;
    MockERC20 public token;
    address public alice;
    address public bob;

    event EthSent(address indexed from, address indexed to, uint256 amount);
    event TokenSent(
        address indexed token,
        address indexed from,
        address indexed to,
        uint256 amount
    );

    function setUp() public {
        transferContract = new Transfer();
        token = new MockERC20();
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function testSendEthTransfersValue() public {
        uint256 amount = 1 ether;
        uint256 bobBalanceBefore = bob.balance;

        vm.prank(alice);
        transferContract.sendEth{value: amount}(payable(bob));

        assertEq(bob.balance, bobBalanceBefore + amount);
    }

    function testSendEthEmitsEvent() public {
        uint256 amount = 1 ether;

        vm.expectEmit(true, true, true, true);
        emit EthSent(alice, bob, amount);

        vm.prank(alice);
        transferContract.sendEth{value: amount}(payable(bob));
    }

    function testSendEthRevertsOnZeroAmount() public {
        vm.expectRevert("Amount must be greater than 0");

        vm.prank(alice);
        transferContract.sendEth{value: 0}(payable(bob));
    }

    function testSendEthRevertsOnZeroRecipient() public {
        vm.expectRevert("Invalid recipient");

        vm.prank(alice);
        transferContract.sendEth{value: 1 ether}(payable(address(0)));
    }

    function testSendTokenTransfersTokens() public {
        uint256 amount = 50;

        token.mint(alice, 100);
        vm.prank(alice);
        token.approve(address(transferContract), amount);

        vm.expectEmit(true, true, true, true);
        emit TokenSent(address(token), alice, bob, amount);

        vm.prank(alice);
        transferContract.sendToken(IERC20(address(token)), bob, amount);

        assertEq(token.balanceOf(alice), 50);
        assertEq(token.balanceOf(bob), 50);
    }

    function testSendTokenRevertsOnZeroAmount() public {
        token.mint(alice, 100);
        vm.prank(alice);
        token.approve(address(transferContract), 10);

        vm.expectRevert("Amount must be greater than 0");

        vm.prank(alice);
        transferContract.sendToken(IERC20(address(token)), bob, 0);
    }

    function testSendTokenRevertsOnInsufficientAllowance() public {
        token.mint(alice, 100);
        vm.prank(alice);
        token.approve(address(transferContract), 10);

        vm.expectRevert("Insufficient allowance");

        vm.prank(alice);
        transferContract.sendToken(IERC20(address(token)), bob, 11);
    }
}
