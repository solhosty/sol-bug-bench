// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20.sol";

contract TokenStreamer {
    error InvalidRecipient();
    error InvalidAmount();
    error InvalidStreamDuration();
    error StreamNotFound();
    error NotStreamRecipient();
    error StreamEnded();

    event StreamCreated(
        uint256 indexed streamId,
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        uint256 duration
    );
    event StreamWithdrawal(
        uint256 indexed streamId, address indexed recipient, uint256 amount
    );
    event StreamDeposit(
        uint256 indexed streamId, address indexed sender, uint256 amount
    );

    uint256 public constant MIN_DURATION = 1 hours;
    uint256 public constant MAX_DURATION = 365 days;

    struct Stream {
        address recipient;
        uint256 totalDeposited;
        uint256 totalWithdrawn;
        uint256 startTime;
        uint256 endTime;
        bool exists;
    }

    ERC20 public immutable token;
    uint256 public nextStreamId;
    mapping(uint256 => Stream) private streams;
    mapping(address => uint256[]) private userStreams;

    constructor(ERC20 token_) {
        token = token_;
    }

    function createStream(address recipient, uint256 amount, uint256 duration)
        external
        returns (uint256 streamId)
    {
        if (recipient == address(0)) {
            revert InvalidRecipient();
        }
        if (amount == 0) {
            revert InvalidAmount();
        }
        if (duration < MIN_DURATION || duration > MAX_DURATION) {
            revert InvalidStreamDuration();
        }

        streamId = ++nextStreamId;
        _initStream(streamId, recipient, amount, duration);
        emit StreamCreated(streamId, msg.sender, recipient, amount, duration);
    }

    function addToStream(uint256 streamId, uint256 amount) external {
        Stream storage stream = streams[streamId];
        if (!stream.exists) {
            revert StreamNotFound();
        }
        if (block.timestamp >= stream.endTime) {
            revert StreamEnded();
        }
        if (amount == 0) {
            revert InvalidAmount();
        }

        bool success = token.transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert("Transfer failed");
        }
        stream.totalDeposited += amount;
        emit StreamDeposit(streamId, msg.sender, amount);
    }

    function withdrawFromStream(uint256 streamId) external {
        Stream storage stream = streams[streamId];
        if (!stream.exists) {
            revert StreamNotFound();
        }
        if (msg.sender != stream.recipient) {
            revert NotStreamRecipient();
        }

        uint256 available = getAvailableTokens(streamId);
        bool success = token.transfer(stream.recipient, available);
        if (!success) {
            revert("Transfer failed");
        }
        stream.totalWithdrawn += available;
        emit StreamWithdrawal(streamId, stream.recipient, available);
    }

    function getStreamInfo(uint256 streamId)
        external
        view
        returns (address, uint256, uint256, uint256, uint256, bool)
    {
        Stream storage stream = streams[streamId];
        return (
            stream.recipient,
            stream.totalDeposited,
            stream.totalWithdrawn,
            stream.startTime,
            stream.endTime,
            stream.exists
        );
    }

    function getStreamRate(uint256 streamId) external view returns (uint256) {
        Stream storage stream = streams[streamId];
        if (!stream.exists) {
            return 0;
        }
        uint256 duration = stream.endTime - stream.startTime;
        return stream.totalDeposited / duration;
    }

    function getAvailableTokens(uint256 streamId) public view returns (uint256) {
        Stream storage stream = streams[streamId];
        if (!stream.exists) {
            return 0;
        }

        uint256 elapsed = block.timestamp - stream.startTime;
        uint256 duration = stream.endTime - stream.startTime;
        if (elapsed > duration) {
            elapsed = duration;
        }

        uint256 accrued = (stream.totalDeposited * elapsed) / duration;
        if (accrued > stream.totalDeposited) {
            accrued = stream.totalDeposited;
        }
        if (accrued <= stream.totalWithdrawn) {
            return 0;
        }
        return accrued - stream.totalWithdrawn;
    }

    function getUserStreams(address user) external view returns (uint256[] memory) {
        return userStreams[user];
    }

    function _initStream(
        uint256 streamId,
        address recipient,
        uint256 amount,
        uint256 duration
    ) internal {
        bool success = token.transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert("Transfer failed");
        }

        Stream storage stream = streams[streamId];
        stream.recipient = recipient;
        stream.totalDeposited = amount;
        stream.totalWithdrawn = 0;
        stream.startTime = block.timestamp;
        stream.endTime = block.timestamp + duration;
        stream.exists = true;

        userStreams[recipient].push(streamId);
    }
}
