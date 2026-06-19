// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title MultiSigV2
 * @dev A simple multi-signature wallet for managing ETH transfers.
 */
contract MultiSigV2 {
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 numConfirmations;
    }

    address[] private owners;
    mapping(address => bool) private ownerStatus;
    mapping(uint256 => mapping(address => bool)) private confirmations;
    Transaction[] private transactions;

    uint256 public immutable threshold;

    event Deposit(address indexed sender, uint256 amount, uint256 balance);
    event SubmitTransaction(
        address indexed owner,
        uint256 indexed txId,
        address indexed to,
        uint256 value,
        bytes data
    );
    event ConfirmTransaction(address indexed owner, uint256 indexed txId);
    event RevokeConfirmation(address indexed owner, uint256 indexed txId);
    event ExecuteTransaction(address indexed owner, uint256 indexed txId);

    modifier onlyOwner() {
        require(ownerStatus[msg.sender], "not owner");
        _;
    }

    modifier txExists(uint256 txId) {
        require(txId < transactions.length, "tx does not exist");
        _;
    }

    modifier notExecuted(uint256 txId) {
        require(!transactions[txId].executed, "tx already executed");
        _;
    }

    modifier notConfirmed(uint256 txId) {
        require(!confirmations[txId][msg.sender], "tx already confirmed");
        _;
    }

    /**
     * @dev Initializes owners and confirmation threshold.
     * @param _owners Addresses allowed to manage wallet transactions.
     * @param _threshold Minimum confirmations required for execution.
     */
    constructor(address[] memory _owners, uint256 _threshold) {
        require(_owners.length > 0, "owners required");
        require(_threshold >= 1, "invalid threshold");
        require(_threshold <= _owners.length, "invalid threshold");

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "invalid owner");
            require(!ownerStatus[owner], "owner not unique");

            ownerStatus[owner] = true;
            owners.push(owner);
        }

        threshold = _threshold;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    /**
     * @dev Submits a transaction for owner confirmations.
     * @param to Recipient address for the transaction.
     * @param value ETH value to send.
     * @param data Calldata to send to recipient.
     * @return txId Index of the submitted transaction.
     */
    function submitTransaction(
        address to,
        uint256 value,
        bytes memory data
    ) external onlyOwner returns (uint256 txId) {
        txId = transactions.length;

        transactions.push(
            Transaction({
                to: to,
                value: value,
                data: data,
                executed: false,
                numConfirmations: 0
            })
        );

        emit SubmitTransaction(msg.sender, txId, to, value, data);
    }

    /**
     * @dev Confirms a pending transaction.
     * @param txId Transaction id to confirm.
     */
    function confirmTransaction(
        uint256 txId
    ) external onlyOwner txExists(txId) notExecuted(txId) notConfirmed(txId) {
        confirmations[txId][msg.sender] = true;
        transactions[txId].numConfirmations += 1;

        emit ConfirmTransaction(msg.sender, txId);
    }

    /**
     * @dev Revokes a previous confirmation for a pending transaction.
     * @param txId Transaction id to revoke.
     */
    function revokeConfirmation(
        uint256 txId
    ) external onlyOwner txExists(txId) notExecuted(txId) {
        require(confirmations[txId][msg.sender], "tx not confirmed");

        confirmations[txId][msg.sender] = false;
        transactions[txId].numConfirmations -= 1;

        emit RevokeConfirmation(msg.sender, txId);
    }

    /**
     * @dev Executes a confirmed transaction.
     * @param txId Transaction id to execute.
     */
    function executeTransaction(
        uint256 txId
    ) external onlyOwner txExists(txId) notExecuted(txId) {
        Transaction storage transaction = transactions[txId];
        require(
            transaction.numConfirmations >= threshold,
            "cannot execute tx"
        );

        transaction.executed = true;

        (bool success,) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "tx failed");

        emit ExecuteTransaction(msg.sender, txId);
    }

    /**
     * @dev Returns the owner list.
     */
    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    /**
     * @dev Returns the number of submitted transactions.
     */
    function getTransactionCount() external view returns (uint256) {
        return transactions.length;
    }

    /**
     * @dev Returns transaction details.
     * @param txId Transaction id to query.
     */
    function getTransaction(
        uint256 txId
    )
        external
        view
        txExists(txId)
        returns (
            address to,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 numConfirmations
        )
    {
        Transaction storage transaction = transactions[txId];
        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations
        );
    }

    /**
     * @dev Returns whether an owner confirmed a transaction.
     * @param txId Transaction id to query.
     * @param owner Owner address to query.
     */
    function isConfirmed(
        uint256 txId,
        address owner
    ) external view txExists(txId) returns (bool) {
        return confirmations[txId][owner];
    }
}
