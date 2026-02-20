// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../src/LiquidityPool.sol";

/**
 * @title ReentrancyAttacker
 * @dev Mock contract to test reentrancy protection on withdraw function
 */
contract ReentrancyAttacker {
    LiquidityPool public pool;
    PoolShare public shareToken;
    uint256 public attackCount;
    uint256 public maxAttacks = 3;
    
    constructor(LiquidityPool _pool) {
        pool = _pool;
        shareToken = pool.shareToken();
    }
    
    function attack() external payable {
        pool.deposit{value: msg.value}();
        shareToken.approve(address(pool), type(uint256).max);
    }
    
    function startWithdrawAttack(uint256 shares) external {
        attackCount = 0;
        pool.withdraw(shares);
    }
    
    receive() external payable {
        if (attackCount < maxAttacks && shareToken.balanceOf(address(this)) > 0) {
            attackCount++;
            pool.withdraw(shareToken.balanceOf(address(this)));
        }
    }
}

/**
 * @title RewardClaimAttacker
 * @dev Mock contract to test reentrancy protection on claimReward function
 */
contract RewardClaimAttacker {
    LiquidityPool public pool;
    uint256 public attackCount;
    uint256 public maxAttacks = 3;
    address public user;
    uint256 public amount;
    uint256 public nonce;
    bytes public signature;
    
    constructor(LiquidityPool _pool) {
        pool = _pool;
    }
    
    function setupAttack(
        address _user,
        uint256 _amount,
        uint256 _nonce,
        bytes memory _signature
    ) external {
        user = _user;
        amount = _amount;
        nonce = _nonce;
        signature = _signature;
    }
    
    function attack() external {
        attackCount = 0;
        pool.claimReward(user, amount, nonce, signature);
    }
    
    receive() external payable {
        if (attackCount < maxAttacks) {
            attackCount++;
            // Attempt to re-enter claimReward
            pool.claimReward(user, amount, nonce + attackCount, signature);
        }
    }
}
