// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MultiSigV4
 * @dev Simple multi-signature wallet with owner confirmations and guarded execution.
 */
contract MultiSigV4 {
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 numConfirmations;
    }

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public threshold;

    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public isConfirmed;

    event SubmitTransaction(
        address indexed owner,
        uint256 indexed txIndex,
        address indexed to,
        uint256 value,
        bytes data
    );
    event ConfirmTransaction(address indexed owner, uint256 indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint256 indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint256 indexed txIndex);

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    modifier txExists(uint256 txIndex) {
        require(txIndex < transactions.length, "tx does not exist");
        _;
    }

    modifier notExecuted(uint256 txIndex) {
        require(!transactions[txIndex].executed, "tx already executed");
        _;
    }

    modifier notConfirmed(uint256 txIndex) {
        require(!isConfirmed[txIndex][msg.sender], "tx already confirmed");
        _;
    }

    /**
     * @dev Creates the wallet with a fixed owner set and confirmation threshold.
     * @param _owners Addresses allowed to submit/confirm/execute transactions.
     * @param _threshold Number of confirmations required before execution.
     */
    constructor(address[] memory _owners, uint256 _threshold) {
        require(_owners.length > 0, "owners required");
        require(_threshold > 0 && _threshold <= _owners.length, "invalid threshold");

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        threshold = _threshold;
    }

    receive() external payable {}

    /**
     * @dev Submits a transaction to be approved by owners.
     * @param to Target address for execution.
     * @param value ETH value to send with execution.
     * @param data Calldata for the low-level call.
     */
    function submitTransaction(
        address to,
        uint256 value,
        bytes calldata data
    ) external onlyOwner {
        uint256 txIndex = transactions.length;

        transactions.push(
            Transaction({
                to: to,
                value: value,
                data: data,
                executed: false,
                numConfirmations: 0
            })
        );

        emit SubmitTransaction(msg.sender, txIndex, to, value, data);
    }

    /**
     * @dev Confirms a pending transaction.
     * @param txIndex Index of the submitted transaction.
     */
    function confirmTransaction(
        uint256 txIndex
    ) external onlyOwner txExists(txIndex) notExecuted(txIndex) notConfirmed(txIndex) {
        transactions[txIndex].numConfirmations += 1;
        isConfirmed[txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, txIndex);
    }

    /**
     * @dev Revokes a previously given confirmation for a pending transaction.
     * @param txIndex Index of the submitted transaction.
     */
    function revokeConfirmation(
        uint256 txIndex
    ) external onlyOwner txExists(txIndex) notExecuted(txIndex) {
        require(isConfirmed[txIndex][msg.sender], "tx not confirmed");

        transactions[txIndex].numConfirmations -= 1;
        isConfirmed[txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, txIndex);
    }

    /**
     * @dev Executes a transaction after enough confirmations are collected.
     * @param txIndex Index of the submitted transaction.
     */
    function executeTransaction(
        uint256 txIndex
    ) external onlyOwner txExists(txIndex) notExecuted(txIndex) {
        Transaction storage transaction = transactions[txIndex];
        require(transaction.numConfirmations >= threshold, "cannot execute tx");

        transaction.executed = true;
        (bool success,) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "tx failed");

        emit ExecuteTransaction(msg.sender, txIndex);
    }

    /**
     * @dev Returns number of configured owners.
     */
    function getOwnersCount() external view returns (uint256) {
        return owners.length;
    }

    /**
     * @dev Returns number of submitted transactions.
     */
    function getTransactionCount() external view returns (uint256) {
        return transactions.length;
    }
}
