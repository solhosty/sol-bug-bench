// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Minimal Multi-Signature Wallet
/// @notice Owners can submit, confirm, revoke, and execute transactions.
contract MultiSig {
    /// @notice Emitted when the wallet receives ETH.
    event Deposit(address indexed sender, uint256 amount, uint256 balance);
    /// @notice Emitted when an owner creates a new transaction proposal.
    event SubmitTransaction(
        address indexed owner,
        uint256 indexed txIndex,
        address indexed to,
        uint256 value,
        bytes data
    );
    /// @notice Emitted when an owner confirms a pending transaction.
    event ConfirmTransaction(address indexed owner, uint256 indexed txIndex);
    /// @notice Emitted when an owner revokes an existing confirmation.
    event RevokeConfirmation(address indexed owner, uint256 indexed txIndex);
    /// @notice Emitted once a confirmed transaction is executed.
    event ExecuteTransaction(address indexed owner, uint256 indexed txIndex);

    /// @dev Tracks the payload and confirmation progress for each proposal.
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 numConfirmations;
    }

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public required;

    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public isConfirmed;

    /// @dev Restricts access to registered wallet owners.
    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    /// @dev Ensures the transaction index points to an existing proposal.
    modifier txExists(uint256 _txIndex) {
        require(_txIndex < transactions.length, "tx does not exist");
        _;
    }

    /// @dev Prevents re-executing a proposal that already succeeded.
    modifier notExecuted(uint256 _txIndex) {
        require(!transactions[_txIndex].executed, "tx already executed");
        _;
    }

    /// @dev Ensures each owner can confirm a proposal at most once.
    modifier notConfirmed(uint256 _txIndex) {
        require(!isConfirmed[_txIndex][msg.sender], "tx already confirmed");
        _;
    }

    /// @param _owners Set of wallet owners allowed to manage proposals.
    /// @param _required Number of confirmations required for execution.
    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0, "owners required");
        require(
            _required > 0 && _required <= _owners.length,
            "invalid required confirmations"
        );

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        required = _required;
    }

    /// @notice Allows the wallet to receive native ETH transfers.
    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    /// @notice Creates a new transaction proposal.
    /// @param _to Destination address for the call.
    /// @param _value ETH amount to send with the call.
    /// @param _data Calldata payload for the destination contract.
    function submitTransaction(
        address _to,
        uint256 _value,
        bytes memory _data
    ) external onlyOwner {
        uint256 txIndex = transactions.length;

        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                numConfirmations: 0
            })
        );

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    /// @notice Confirms a transaction proposal.
    /// @param _txIndex Proposal index in the transactions array.
    function confirmTransaction(
        uint256 _txIndex
    )
        external
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        transaction.numConfirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    /// @notice Revokes a prior confirmation from the caller.
    /// @param _txIndex Proposal index in the transactions array.
    function revokeConfirmation(
        uint256 _txIndex
    ) external onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        require(isConfirmed[_txIndex][msg.sender], "tx not confirmed");

        Transaction storage transaction = transactions[_txIndex];

        transaction.numConfirmations -= 1;
        isConfirmed[_txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    /// @notice Executes a proposal once it has enough confirmations.
    /// @param _txIndex Proposal index in the transactions array.
    function executeTransaction(
        uint256 _txIndex
    ) external txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];

        require(
            transaction.numConfirmations >= required,
            "cannot execute tx"
        );

        transaction.executed = true;

        (bool success,) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "tx failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    /// @notice Returns the number of submitted proposals.
    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
    }
}
