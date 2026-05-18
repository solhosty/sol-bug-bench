// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title MultiSigWallet
 * @dev Basic multi-signature wallet with fixed owners and a confirmation threshold.
 */
contract MultiSigWallet {
    struct Transaction {
        address target;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmationCount;
    }

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public immutable threshold;

    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public confirmations;

    event Deposit(address indexed sender, uint256 amount, uint256 balance);
    event SubmitTransaction(
        address indexed owner,
        uint256 indexed txIndex,
        address indexed target,
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

    /**
     * @notice Deploys the wallet with a fixed owner set and threshold.
     * @param _owners Owner addresses allowed to manage and execute transactions.
     * @param _threshold Number of confirmations required for execution.
     */
    constructor(address[] memory _owners, uint256 _threshold) {
        require(_owners.length > 0, "Owners required");
        require(
            _threshold > 0 && _threshold <= _owners.length,
            "Invalid threshold"
        );

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner not unique");
            isOwner[owner] = true;
            owners.push(owner);
        }

        threshold = _threshold;
    }

    /**
     * @notice Accepts ETH deposits into the wallet.
     */
    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    /**
     * @notice Submits a transaction proposal for owner confirmations.
     * @param target Destination address to call during execution.
     * @param value ETH amount to send with the call.
     * @param data Calldata payload for arbitrary function calls.
     * @return txIndex Index assigned to the submitted transaction.
     */
    function submitTransaction(
        address target,
        uint256 value,
        bytes calldata data
    ) external onlyOwner returns (uint256 txIndex) {
        txIndex = transactions.length;
        transactions.push(
            Transaction({
                target: target,
                value: value,
                data: data,
                executed: false,
                confirmationCount: 0
            })
        );

        emit SubmitTransaction(msg.sender, txIndex, target, value, data);
    }

    /**
     * @notice Confirms a pending transaction.
     * @param txIndex The index of the transaction to confirm.
     */
    function confirmTransaction(
        uint256 txIndex
    ) external onlyOwner txExists(txIndex) notExecuted(txIndex) {
        require(!confirmations[txIndex][msg.sender], "Already confirmed");

        confirmations[txIndex][msg.sender] = true;
        transactions[txIndex].confirmationCount += 1;

        emit ConfirmTransaction(msg.sender, txIndex);
    }

    /**
     * @notice Revokes a previously made confirmation.
     * @param txIndex The index of the transaction to revoke confirmation for.
     */
    function revokeConfirmation(
        uint256 txIndex
    ) external onlyOwner txExists(txIndex) notExecuted(txIndex) {
        require(confirmations[txIndex][msg.sender], "Not confirmed");

        confirmations[txIndex][msg.sender] = false;
        transactions[txIndex].confirmationCount -= 1;

        emit RevokeConfirmation(msg.sender, txIndex);
    }

    /**
     * @notice Executes a confirmed transaction once threshold is reached.
     * @param txIndex The index of the transaction to execute.
     */
    function executeTransaction(
        uint256 txIndex
    ) external onlyOwner txExists(txIndex) notExecuted(txIndex) {
        Transaction storage txn = transactions[txIndex];
        require(
            txn.confirmationCount >= threshold,
            "Insufficient confirmations"
        );

        (bool success, ) = txn.target.call{value: txn.value}(txn.data);
        require(success, "Transaction failed");

        txn.executed = true;

        emit ExecuteTransaction(msg.sender, txIndex);
    }

    /**
     * @notice Returns the number of owners configured at deployment.
     * @return count Number of owner addresses.
     */
    function getOwnersCount() external view returns (uint256 count) {
        count = owners.length;
    }

    /**
     * @notice Returns the number of submitted transactions.
     * @return count Number of transactions.
     */
    function getTransactionCount() external view returns (uint256 count) {
        count = transactions.length;
    }
}
