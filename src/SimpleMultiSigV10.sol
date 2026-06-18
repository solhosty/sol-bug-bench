// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title SimpleMultiSigV10
/// @notice Standalone M-of-N multisig wallet for ETH and calldata transactions.
contract SimpleMultiSigV10 {
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 numConfirmations;
    }

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public numConfirmationsRequired;

    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public isConfirmed;

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
        require(isOwner[msg.sender], "Not owner");
        _;
    }

    modifier txExists(uint256 txId) {
        require(txId < transactions.length, "Transaction does not exist");
        _;
    }

    modifier notExecuted(uint256 txId) {
        require(!transactions[txId].executed, "Transaction already executed");
        _;
    }

    modifier notConfirmed(uint256 txId) {
        require(!isConfirmed[txId][msg.sender], "Transaction already confirmed");
        _;
    }

    /// @notice Initializes owners and required confirmations.
    /// @param _owners Owner addresses for this wallet.
    /// @param _numConfirmationsRequired Number of confirmations required.
    constructor(address[] memory _owners, uint256 _numConfirmationsRequired) {
        require(_owners.length > 0, "Owners required");
        require(_numConfirmationsRequired > 0, "Invalid threshold");
        require(
            _numConfirmationsRequired <= _owners.length,
            "Threshold exceeds owners"
        );

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        numConfirmationsRequired = _numConfirmationsRequired;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    /// @notice Submits a transaction proposal.
    /// @param to Destination address.
    /// @param value ETH value to send.
    /// @param data Calldata to execute.
    function submitTransaction(
        address to,
        uint256 value,
        bytes calldata data
    ) external onlyOwner {
        uint256 txId = transactions.length;

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

    /// @notice Confirms an existing transaction.
    /// @param txId Transaction id.
    function confirmTransaction(
        uint256 txId
    ) external onlyOwner txExists(txId) notExecuted(txId) notConfirmed(txId) {
        Transaction storage transaction = transactions[txId];
        transaction.numConfirmations += 1;
        isConfirmed[txId][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, txId);
    }

    /// @notice Revokes caller confirmation for a pending transaction.
    /// @param txId Transaction id.
    function revokeConfirmation(
        uint256 txId
    ) external onlyOwner txExists(txId) notExecuted(txId) {
        require(isConfirmed[txId][msg.sender], "Transaction not confirmed");

        Transaction storage transaction = transactions[txId];
        transaction.numConfirmations -= 1;
        isConfirmed[txId][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, txId);
    }

    /// @notice Executes a confirmed transaction.
    /// @param txId Transaction id.
    function executeTransaction(
        uint256 txId
    ) external onlyOwner txExists(txId) notExecuted(txId) {
        Transaction storage transaction = transactions[txId];

        require(
            transaction.numConfirmations >= numConfirmationsRequired,
            "Cannot execute transaction"
        );

        transaction.executed = true;

        (bool success,) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "Transaction failed");

        emit ExecuteTransaction(msg.sender, txId);
    }

    /// @notice Returns the list of owners.
    /// @return Wallet owners.
    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    /// @notice Returns total number of submitted transactions.
    /// @return Number of transactions.
    function getTransactionCount() external view returns (uint256) {
        return transactions.length;
    }
}
