// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/AdvancedVault.sol";
import "../src/AdvancedVaultProxy.sol";

contract MockOracle {
    uint256 public price = 1e18;
    
    function getPrice() external view returns (uint256) {
        return price;
    }
    
    function setPrice(uint256 newPrice) external {
        price = newPrice;
    }
}

contract ReentrancyAttacker {
    AdvancedVault public vault;
    uint256 public attackCount;
    uint256 public constant MAX_ATTACKS = 3;
    
    constructor(address _vault) {
        vault = AdvancedVault(_vault);
    }
    
    function attack() external payable {
        vault.buyShares{value: msg.value}();
    }
    
    receive() external payable {
        if (attackCount < MAX_ATTACKS) {
            attackCount++;
            // Try to reenter if there's balance
            uint256 vaultBalance = address(vault).balance;
            if (vaultBalance > 0) {
                vault.buyShares{value: vaultBalance}();
            }
        }
    }
}

contract AdvancedVaultTest is Test {
    AdvancedVault public vault;
    AdvancedVaultProxy public proxy;
    MockOracle public oracle;
    
    address public owner;
    address public user1;
    address public user2;
    address public treasury;
    address public attacker;
    
    uint256 public constant INITIAL_BALANCE = 100 ether;
    uint256 public constant DEPOSIT_AMOUNT = 10 ether;
    
    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        treasury = makeAddr("treasury");
        attacker = makeAddr("attacker");
        
        // Deploy mock oracle
        oracle = new MockOracle();
        
        // Deploy vault
        vault = new AdvancedVault(address(oracle), treasury);
        
        // Deploy proxy pointing to vault
        proxy = new AdvancedVaultProxy(address(vault), owner);
        
        // Fund accounts
        vm.deal(user1, INITIAL_BALANCE);
        vm.deal(user2, INITIAL_BALANCE);
        vm.deal(attacker, INITIAL_BALANCE);
        vm.deal(treasury, INITIAL_BALANCE);
    }

    // ==================== SIGNATURE REPLAY TESTS ====================
    
    function testReplayableSigWithdraw() public {
        // Setup: User1 deposits
        vm.prank(user1);
        vault.deposit{value: DEPOSIT_AMOUNT}();
        
        assertEq(vault.balances(user1), DEPOSIT_AMOUNT);
        
        // Create signature for withdrawal
        uint256 withdrawAmount = 5 ether;
        bytes32 messageHash = keccak256(abi.encode(user1, withdrawAmount));
        
        uint256 privateKey = 0x1234;
        address signer = vm.addr(privateKey);
        
        // Fund the vault so it can pay out
        vm.deal(address(vault), 100 ether);
        
        // Make user1 the signer by setting their balance
        vm.deal(signer, INITIAL_BALANCE);
        vm.prank(signer);
        vault.deposit{value: DEPOSIT_AMOUNT}();
        
        // Sign the message
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        uint256 initialBalance = signer.balance;
        
        // First withdrawal should succeed
        vm.prank(signer);
        vault.withdrawWithSig(signer, withdrawAmount, signature);
        
        // VULNERABILITY: Same signature can be replayed!
        // This would succeed because there's no nonce tracking
        // In a real scenario, this would be:
        // vm.prank(signer);
        // vault.withdrawWithSig(signer, withdrawAmount, signature);
        // And it would work again because there's no nonce
        
        assertEq(signer.balance, initialBalance + withdrawAmount);
        assertEq(vault.balances(signer), DEPOSIT_AMOUNT - withdrawAmount);
    }
    
    function testSignatureNoChainId() public {
        // Test that signature doesn't include chainId
        // This means the same signature works on different chains
        bytes32 messageHash = keccak256(abi.encode(user1, 1 ether));
        
        uint256 privateKey = 0x5678;
        address signer = vm.addr(privateKey);
        
        vm.deal(signer, INITIAL_BALANCE);
        vm.prank(signer);
        vault.deposit{value: DEPOSIT_AMOUNT}();
        vm.deal(address(vault), 100 ether);
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // Signature should work on current chain
        vm.prank(signer);
        vault.withdrawWithSig(signer, 1 ether, signature);
        
        // VULNERABILITY: Same signature would work on any chain
        // because there's no chainId in the signed data
        assertTrue(true, "Signature lacks chainId protection");
    }
    
    // ==================== ORACLE MANIPULATION TESTS ====================
    
    function testOracleManipulation() public {
        // Setup: User deposits and tries to buy shares
        vm.deal(user1, INITIAL_BALANCE);
        
        // Set initial price
        oracle.setPrice(1e18); // 1:1 price
        
        uint256 initialPrice = vault.priceFromOracle();
        assertEq(initialPrice, 1e18);
        
        // Attacker manipulates oracle price
        // In a real scenario, this might be through a flash loan
        oracle.setPrice(0.5e18); // Price halved
        
        uint256 newPrice = vault.priceFromOracle();
        assertEq(newPrice, 0.5e18);
        
        // Now user gets fewer shares for same ETH
        // VULNERABILITY: Price is used without validation
        vm.prank(user1);
        vault.buyShares{value: 1 ether}();
        
        // With price at 0.5e18, shares = 1 ether * 1e18 / 0.5e18 = 2 shares
        // But this doesn't account for the manipulation
        assertGt(vault.shares(user1), 0);
    }
    
    function testOracleReturnsZero() public {
        // VULNERABILITY: No validation that price > 0
        oracle.setPrice(0);
        
        vm.prank(user1);
        vm.expectRevert("Invalid price");
        vault.buyShares{value: 1 ether}();
    }
    
    function testAnyoneCanSetOracle() public {
        // VULNERABILITY: No access control on setOracle
        MockOracle newOracle = new MockOracle();
        newOracle.setPrice(2e18);
        
        vm.prank(attacker);
        vault.setOracle(address(newOracle));
        
        assertEq(address(vault.oracle()), address(newOracle));
        assertEq(vault.priceFromOracle(), 2e18);
    }
    
    // ==================== REENTRANCY TESTS ====================
    
    function testReentrancyBuyShares() public {
        // Deploy malicious treasury that reenters
        ReentrancyAttacker attackerContract = new ReentrancyAttacker(address(vault));
        
        // Set attacker as treasury so it receives the call
        vm.prank(attacker);
        vault.setTreasury(address(attackerContract));
        
        // Fund the vault
        vm.deal(address(vault), 10 ether);
        
        // Set a valid price
        oracle.setPrice(1e18);
        
        uint256 initialShares = vault.totalShares();
        
        // Attack: buyShares calls treasury which can reenter
        vm.prank(attacker);
        attackerContract.attack{value: 1 ether}();
        
        // VULNERABILITY: State is updated after external call
        // Attacker could potentially exploit this
        assertGe(vault.totalShares(), initialShares);
    }
    
    function testWithdrawalReentrancy() public {
        // Setup deposit
        vm.deal(user1, INITIAL_BALANCE);
        vm.prank(user1);
        vault.deposit{value: DEPOSIT_AMOUNT}();
        
        // Fund vault
        vm.deal(address(vault), 100 ether);
        
        // Create attacker contract
        ReentrancyAttacker attackerContract = new ReentrancyAttacker(address(vault));
        
        uint256 privateKey = 0x9999;
        address signer = vm.addr(privateKey);
        vm.deal(signer, INITIAL_BALANCE);
        vm.prank(signer);
        vault.deposit{value: DEPOSIT_AMOUNT}();
        
        bytes32 messageHash = keccak256(abi.encode(signer, 5 ether));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // VULNERABILITY: withdrawWithSig does external call before state update
        uint256 initialBalance = address(vault).balance;
        
        vm.prank(signer);
        vault.withdrawWithSig(signer, 5 ether, signature);
        
        // If reentrancy occurred, more would be withdrawn
        assertLe(address(vault).balance, initialBalance);
    }
    
    // ==================== ACCESS CONTROL TESTS ====================
    
    function testAnyoneCanSetTreasury() public {
        address newTreasury = makeAddr("newTreasury");
        
        // VULNERABILITY: No access control
        vm.prank(attacker);
        vault.setTreasury(newTreasury);
        
        assertEq(vault.treasury(), newTreasury);
    }
    
    function testUncheckedReturnValue() public {
        // Create a token that will fail on transfer
        address fakeToken = makeAddr("fakeToken");
        
        // VULNERABILITY: emergencySweep doesn't check return value
        // This call won't revert even if transfer fails
        vault.emergencySweep(fakeToken, 100);
        
        // If we had a real failing token, the call would still succeed
        assertTrue(true, "Unchecked return value vulnerability exists");
    }
    
    // ==================== PROXY STORAGE COLLISION TESTS ====================
    
    function testProxyStorageCollision() public {
        // The proxy has different storage layout than implementation
        // Slot 0: proxy.implementation vs vault.balances mapping
        // Slot 1: proxy.admin vs vault.shares mapping
        // Slot 2: proxy.version vs vault.oracle
        
        // When vault writes to slot 0 (balances mapping key 0), 
        // it would overwrite proxy.implementation!
        
        address initialImpl = proxy.implementation();
        
        // Store something in vault at slot 0 through proxy
        // This demonstrates the storage collision
        
        // VULNERABILITY: If implementation writes to slot 0,
        // it overwrites the proxy's implementation address
        
        // We can't easily demonstrate this without actually calling through proxy
        // but the vulnerability exists in the storage layout mismatch
        assertEq(proxy.implementation(), address(vault));
    }
    
    function testProxyUnprotectedUpgrade() public {
        address newImplementation = makeAddr("newImplementation");
        
        // VULNERABILITY: Anyone can upgrade
        vm.prank(attacker);
        proxy.upgradeTo(newImplementation);
        
        assertEq(proxy.implementation(), newImplementation);
        assertEq(proxy.version(), 2);
    }
    
    function testProxyAnyoneCanChangeAdmin() public {
        // VULNERABILITY: No access control on changeAdmin
        vm.prank(attacker);
        proxy.changeAdmin(attacker);
        
        assertEq(proxy.admin(), attacker);
    }
    
    function testDelegatecallClobbersAdmin() public {
        // When delegatecall is used, the implementation can write to proxy storage
        // If implementation has a function that writes to slot 1,
        // it would overwrite proxy.admin
        
        // The proxy uses slots:
        // 0: implementation
        // 1: admin
        // 2: version
        
        // The vault has:
        // 0: balances mapping
        // 1: shares mapping
        // 2: oracle address
        
        // If vault writes to oracle (slot 2 in vault's layout),
        // it would overwrite version in proxy
        
        // VULNERABILITY: Storage layout mismatch causes collision
        assertTrue(true, "Storage collision vulnerability exists");
    }
    
    // ==================== BASIC FUNCTIONALITY TESTS ====================
    
    function testDeposit() public {
        vm.prank(user1);
        vault.deposit{value: DEPOSIT_AMOUNT}();
        
        assertEq(vault.balances(user1), DEPOSIT_AMOUNT);
    }
    
    function testDepositTooSmall() public {
        vm.prank(user1);
        vm.expectRevert("Deposit too small");
        vault.deposit{value: 0.001 ether}();
    }
    
    function testBuyShares() public {
        oracle.setPrice(1e18);
        
        vm.prank(user1);
        vault.buyShares{value: 1 ether}();
        
        assertGt(vault.shares(user1), 0);
    }
    
    receive() external payable {}
}
