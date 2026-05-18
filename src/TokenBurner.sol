// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title TokenBurner
 * @dev Tracks tokens sent to this contract as permanently burned.
 */
contract TokenBurner {
    mapping(address => uint256) private burnedAmounts;

    event TokensBurned(
        address indexed token,
        address indexed burner,
        uint256 amount
    );

    /**
     * @notice Moves tokens from caller into this contract and records burn amount.
     * @param token ERC20 token address.
     * @param amount Token amount to burn.
     */
    function burn(address token, uint256 amount) external {
        require(token != address(0), "Invalid token");
        require(amount > 0, "Amount must be greater than zero");

        (bool success, ) = token.call(
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                msg.sender,
                address(this),
                amount
            )
        );
        require(success, "Transfer call failed");

        burnedAmounts[token] += amount;

        emit TokensBurned(token, msg.sender, amount);
    }

    /**
     * @notice Returns the total amount recorded as burned for a token.
     * @param token ERC20 token address.
     * @return amount Burned amount tracked for token.
     */
    function totalBurned(address token) external view returns (uint256 amount) {
        amount = burnedAmounts[token];
    }
}
