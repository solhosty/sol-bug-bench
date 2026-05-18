// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/TokenBurner.sol";

contract MockBurnToken is ERC20 {
    constructor() ERC20("Mock Burn Token", "MBT") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract TokenBurnerTest is Test {
    TokenBurner internal burner;
    MockBurnToken internal token;

    address internal user;

    function setUp() public {
        burner = new TokenBurner();
        token = new MockBurnToken();
        user = makeAddr("user");

        token.mint(user, 1_000 ether);
    }

    function testBurnSucceedsAndTracksAmount() public {
        uint256 burnAmount = 100 ether;

        vm.startPrank(user);
        token.approve(address(burner), burnAmount);
        burner.burn(address(token), burnAmount);
        vm.stopPrank();

        assertEq(burner.totalBurned(address(token)), burnAmount);
        assertEq(token.balanceOf(address(burner)), burnAmount);
        assertEq(token.balanceOf(user), 900 ether);
    }

    function test_RevertWhen_BurnZeroAmount() public {
        vm.prank(user);
        vm.expectRevert("Amount must be greater than zero");
        burner.burn(address(token), 0);
    }

    function test_RevertWhen_BurnWithoutApproval() public {
        vm.prank(user);
        vm.expectRevert("Transfer call failed");
        burner.burn(address(token), 10 ether);
    }

    function testMultipleBurnsAccumulate() public {
        vm.startPrank(user);
        token.approve(address(burner), 250 ether);
        burner.burn(address(token), 100 ether);
        burner.burn(address(token), 150 ether);
        vm.stopPrank();

        assertEq(burner.totalBurned(address(token)), 250 ether);
        assertEq(token.balanceOf(address(burner)), 250 ether);
        assertEq(token.balanceOf(user), 750 ether);
    }
}
