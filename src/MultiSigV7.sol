// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title MultiSigV7
 * @dev Standalone m-of-n multisig wallet for ETH and calldata transactions.
 */
contract MultiSigV7 {
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
        uint256 indexed txIndex,
        address indexed to,
        uint256 value,
        bytes data
    );
    event ConfirmTransaction(address indexed owner, uint256 indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint256 indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint256 indexed txIndex);

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not owner");
        _;
    }

    modifier txExists(uint256 txIndex) {
        require(txIndex < transactions.length, "Transaction does not exist");
        _;
    }

    modifier notExecuted(uint256 txIndex) {
        require(!transactions[txIndex].executed, "Transaction already executed");
        _;
    }

    modifier notConfirmed(uint256 txIndex) {
        require(!isConfirmed[txIndex][msg.sender], "Transaction already confirmed");
        _;
    }

    /**
     * @dev Initializes owners and required confirmation threshold.
     * @param _owners Owner addresses for the wallet.
     * @param _numConfirmationsRequired Number of confirmations required to execute.
     */
    constructor(address[] memory _owners, uint256 _numConfirmationsRequired) {
        require(_owners.length > 0, "Owners required");
        require(_numConfirmationsRequired > 0, "Invalid threshold");
        require(_numConfirmationsRequired <= _owners.length, "Threshold exceeds owners");

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

    /**
     * @dev Submits a new transaction proposal.
     * @param to Destination address.
     * @param value ETH value to send.
     * @param data Calldata to include in the call.
     */
    function submitTransaction(
        address to,
        uint256 value,
        bytes calldata data
    ) external onlyOwner {
        require(to != address(0), "Invalid target");

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
     * @dev Confirms a submitted transaction.
     * @param txIndex Transaction index.
     */
    function confirmTransaction(
        uint256 txIndex
    ) external onlyOwner txExists(txIndex) notExecuted(txIndex) notConfirmed(txIndex) {
        Transaction storage transaction = transactions[txIndex];
        transaction.numConfirmations += 1;
        isConfirmed[txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, txIndex);
    }

    /**
     * @dev Revokes an owner's prior confirmation for a transaction.
     * @param txIndex Transaction index.
     */
    function revokeConfirmation(
        uint256 txIndex
    ) external onlyOwner txExists(txIndex) notExecuted(txIndex) {
        require(isConfirmed[txIndex][msg.sender], "Transaction not confirmed");

        Transaction storage transaction = transactions[txIndex];
        transaction.numConfirmations -= 1;
        isConfirmed[txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, txIndex);
    }

    /**
     * @dev Executes a confirmed transaction using checks-effects-interactions.
     * @param txIndex Transaction index.
     */
    function executeTransaction(
        uint256 txIndex
    ) external onlyOwner txExists(txIndex) notExecuted(txIndex) {
        Transaction storage transaction = transactions[txIndex];

        require(
            transaction.numConfirmations >= numConfirmationsRequired,
            "Cannot execute transaction"
        );

        transaction.executed = true;

        (bool success,) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "Transaction failed");

        emit ExecuteTransaction(msg.sender, txIndex);
    }

    /**
     * @dev Returns number of submitted transactions.
     */
    function getTransactionCount() external view returns (uint256) {
        return transactions.length;
    }

    /**
     * @dev Returns owner addresses.
     */
    function getOwners() external view returns (address[] memory) {
        return owners;
    }
}
