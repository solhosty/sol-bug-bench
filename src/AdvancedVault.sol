// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

interface IOracle {
    function getPrice() external view returns (uint256);
}

/**
 * @title AdvancedVault
 * @dev Advanced vault contract with multiple intentional vulnerabilities
 *
 * This contract demonstrates various security flaws for educational purposes:
 * - Replayable signatures (missing nonce/chainId)
 * - Oracle manipulation
 * - Reentrancy in buyShares
 * - Missing access control
 * - Unchecked return values
 */
contract AdvancedVault {
    using ECDSA for bytes32;

    mapping(address => uint256) public balances;
    mapping(address => uint256) public shares;
    
    IOracle public oracle;
    address public treasury;
    
    uint256 public totalShares;
    uint256 public constant MIN_DEPOSIT = 0.01 ether;
    
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event SharesBought(address indexed user, uint256 ethAmount, uint256 sharesReceived);
    event TreasurySet(address indexed newTreasury);
    event EmergencySweep(address indexed token, uint256 amount);

    constructor(address _oracle, address _treasury) {
        oracle = IOracle(_oracle);
        treasury = _treasury;
    }

    /**
     * @dev Deposit ETH into the vault
     */
    function deposit() external payable {
        require(msg.value >= MIN_DEPOSIT, "Deposit too small");
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @dev VULNERABLE: Replayable signature withdrawal
     * Missing nonce and chainId allows signature replay across chains and sessions
     */
    function withdrawWithSig(address user, uint256 amount, bytes memory sig) external {
        // VULNERABILITY: Missing nonce allows replay attacks
        // VULNERABILITY: Missing chainId allows cross-chain replay
        bytes32 h = keccak256(abi.encode(user, amount));
        require(ECDSA.recover(h, sig) == user, "bad sig");
        
        // VULNERABILITY: External call before state update (reentrancy vector)
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "send failed");
        
        // State update happens AFTER external call
        balances[user] -= amount;
        
        emit Withdraw(user, amount);
    }

    /**
     * @dev VULNERABLE: Uses unvalidated oracle price
     * No sanity checks on returned price
     */
    function priceFromOracle() public view returns (uint256) {
        // VULNERABILITY: No validation of oracle price
        // Could return 0, be stale, or be manipulated
        return oracle.getPrice();
    }

    /**
     * @dev VULNERABLE: Reentrancy through external call before state update
     * No reentrancy guard, external call before balance update
     */
    function buyShares() external payable {
        require(msg.value > 0, "Must send ETH");
        
        uint256 price = priceFromOracle();
        require(price > 0, "Invalid price");
        
        uint256 sharesToMint = (msg.value * 1e18) / price;
        
        // VULNERABILITY: External call before state update
        // Treasury could be a malicious contract that reenters
        (bool success,) = treasury.call{value: msg.value}("");
        // VULNERABILITY: Success not properly validated before continuing
        
        // State update happens AFTER external call
        shares[msg.sender] += sharesToMint;
        totalShares += sharesToMint;
        
        emit SharesBought(msg.sender, msg.value, sharesToMint);
    }

    /**
     * @dev VULNERABLE: No access control
     * Anyone can change the treasury address
     */
    function setTreasury(address newTreasury) external {
        // VULNERABILITY: Missing access control check
        treasury = newTreasury;
        emit TreasurySet(newTreasury);
    }

    /**
     * @dev VULNERABLE: Unchecked return value
     * Call success is not verified
     */
    function emergencySweep(address token, uint256 amount) external {
        // VULNERABILITY: Return value not checked
        // If call fails, no revert occurs
        token.call(abi.encodeWithSignature("transfer(address,uint256)", treasury, amount));
        
        emit EmergencySweep(token, amount);
    }

    /**
     * @dev VULNERABLE: Oracle can be changed without authorization
     */
    function setOracle(address newOracle) external {
        // VULNERABILITY: Missing access control
        oracle = IOracle(newOracle);
    }

    /**
     * @dev Allows the contract to receive ETH
     */
    receive() external payable {}
}
