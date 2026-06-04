// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Transfer is Ownable {
    ERC20 public immutable token;

    uint256 public feeBps;
    uint256 public accumulatedFees;
    bool public paused;

    event TokenTransferred(address indexed from, address indexed to, uint256 amount);
    event BatchTransferExecuted(address indexed from, uint256 recipients, uint256 totalAmount);
    event FeeUpdated(uint256 newFeeBps);
    event Paused(address indexed by);
    event Unpaused(address indexed by);

    modifier whenNotPaused() {
        require(!paused, "Transfers are paused");
        _;
    }

    constructor(address tokenAddress) Ownable(msg.sender) {
        require(tokenAddress != address(0), "Invalid token address");
        token = ERC20(tokenAddress);
    }

    function singleTransfer(address to, uint256 amount) external whenNotPaused {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be greater than zero");

        bool pulled = token.transferFrom(msg.sender, address(this), amount);
        require(pulled, "TransferFrom failed");

        uint256 fee = (amount * feeBps) / 10_000;
        uint256 sendAmount = amount - fee;

        if (fee > 0) {
            accumulatedFees += fee;
        }

        bool sent = token.transfer(to, sendAmount);
        require(sent, "Transfer failed");

        emit TokenTransferred(msg.sender, to, sendAmount);
    }

    function batchTransfer(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external whenNotPaused {
        require(recipients.length > 0, "Empty recipients list");

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "Invalid recipient");
            require(amounts[i] > 0, "Amount must be greater than zero");
            totalAmount += amounts[i];
        }

        bool pulled = token.transferFrom(msg.sender, address(this), totalAmount);
        require(pulled, "TransferFrom failed");

        for (uint256 i = 0; i < recipients.length; i++) {
            uint256 fee = (amounts[i] * feeBps) / 10_000;
            uint256 sendAmount = amounts[i] - fee;

            if (fee > 0) {
                accumulatedFees += fee;
            }

            bool sent = token.transfer(recipients[i], sendAmount);
            require(sent, "Transfer failed");

            emit TokenTransferred(msg.sender, recipients[i], sendAmount);
        }

        emit BatchTransferExecuted(msg.sender, recipients.length, totalAmount);
    }

    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function setFee(uint256 newFeeBps) external onlyOwner {
        require(newFeeBps <= 1_000, "Fee too high");
        feeBps = newFeeBps;
        emit FeeUpdated(newFeeBps);
    }

    function claimFees() external onlyOwner {
        require(accumulatedFees > 0, "No fees to claim");

        uint256 amount = accumulatedFees;
        token.transfer(owner(), amount);
        accumulatedFees = 0;
    }
}
