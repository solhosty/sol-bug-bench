// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StableCoin is ERC20, Ownable {
    event TokensMinted(address indexed to, uint256 amount);

    constructor() ERC20("USD Stable", "USDS") Ownable(msg.sender) {
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }

    function decimals() public pure override returns (uint8) {
        return 1;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }
}

contract TokenStreamer {
    error InvalidAmount();
    error ZeroStreamRate();
    error StreamNotFound();
    error InvalidStreamDuration();
    error NotStreamRecipient();
    error StreamEnded();
    error InvalidRecipient();
    error NotStreamCreator();
    error NotStreamParticipant();
    error EmptyStream();

    event StreamCreated(
        uint256 indexed streamId,
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        uint256 duration
    );
    event StreamWithdrawal(
        uint256 indexed streamId,
        address indexed recipient,
        uint256 amount
    );
    event StreamDeposit(
        uint256 indexed streamId,
        address indexed sender,
        uint256 amount
    );
    event StreamCancelled(
        uint256 indexed streamId,
        address indexed canceller,
        uint256 recipientPayout,
        uint256 creatorRefund
    );
    event StreamRecipientUpdated(
        uint256 indexed streamId,
        address indexed oldRecipient,
        address indexed newRecipient
    );

    struct Stream {
        address creator;
        address recipient;
        uint256 totalDeposited;
        uint256 totalWithdrawn;
        uint256 startTime;
        uint256 endTime;
        bool exists;
    }

    StableCoin public immutable stablecoin;
    uint256 public nextStreamId = 1;

    mapping(uint256 => Stream) private streams;
    mapping(address => uint256[]) private userStreams;

    constructor(StableCoin stablecoin_) {
        stablecoin = stablecoin_;
    }

    function createStream(
        address recipient,
        uint256 amount,
        uint256 duration
    ) external returns (uint256 streamId) {
        if (recipient == address(0)) {
            revert InvalidRecipient();
        }
        if (amount == 0) {
            revert InvalidAmount();
        }
        if (duration < 1 hours || duration > 365 days) {
            revert InvalidStreamDuration();
        }
        if (amount / duration == 0) {
            revert ZeroStreamRate();
        }

        bool success = stablecoin.transferFrom(msg.sender, address(this), amount);
        require(success, "Transfer failed");

        streamId = nextStreamId;
        nextStreamId += 1;

        streams[streamId] = Stream({
            creator: msg.sender,
            recipient: recipient,
            totalDeposited: amount,
            totalWithdrawn: 0,
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            exists: true
        });

        userStreams[recipient].push(streamId);

        emit StreamCreated(streamId, msg.sender, recipient, amount, duration);
    }

    function addToStream(uint256 streamId, uint256 amount) external {
        Stream storage stream = streams[streamId];

        if (!stream.exists) {
            revert StreamNotFound();
        }
        if (stream.creator != msg.sender) {
            revert NotStreamCreator();
        }
        if (amount == 0) {
            revert InvalidAmount();
        }
        if (block.timestamp >= stream.endTime) {
            revert StreamEnded();
        }
        uint256 duration = stream.endTime - stream.startTime;
        uint256 elapsed = block.timestamp - stream.startTime;
        uint256 vested = (stream.totalDeposited * elapsed) / duration;
        uint256 unvested = stream.totalDeposited - vested;
        uint256 remainingDuration = duration - elapsed;

        uint256 newTotalDeposited = stream.totalDeposited + amount;
        if (newTotalDeposited / duration == 0) {
            revert ZeroStreamRate();
        }

        uint256 newUnvested = unvested + amount;
        uint256 newRemainingDuration =
            (remainingDuration * newUnvested + unvested - 1) / unvested;

        bool success = stablecoin.transferFrom(msg.sender, address(this), amount);
        require(success, "Transfer failed");

        stream.totalDeposited = newTotalDeposited;
        stream.endTime = block.timestamp + newRemainingDuration;

        emit StreamDeposit(streamId, msg.sender, amount);
    }

    function withdrawFromStream(uint256 streamId) external {
        Stream storage stream = streams[streamId];

        if (!stream.exists) {
            revert StreamNotFound();
        }
        if (stream.recipient != msg.sender) {
            revert NotStreamRecipient();
        }

        uint256 available = getAvailableTokens(streamId);
        if (available == 0) {
            revert InvalidAmount();
        }

        stream.totalWithdrawn += available;

        bool success = stablecoin.transfer(msg.sender, available);
        require(success, "Transfer failed");

        emit StreamWithdrawal(streamId, msg.sender, available);
    }

    function cancelStream(uint256 streamId) external {
        Stream storage stream = streams[streamId];

        if (!stream.exists) {
            revert StreamNotFound();
        }
        if (msg.sender != stream.creator && msg.sender != stream.recipient) {
            revert NotStreamParticipant();
        }

        uint256 totalRemaining = stream.totalDeposited - stream.totalWithdrawn;
        if (totalRemaining == 0) {
            revert EmptyStream();
        }

        uint256 recipientPayout = getAvailableTokens(streamId);
        uint256 creatorRefund = totalRemaining - recipientPayout;

        if (recipientPayout > 0) {
            stream.totalWithdrawn += recipientPayout;
        }
        stream.exists = false;

        if (recipientPayout > 0) {
            bool recipientTransferSuccess = stablecoin.transfer(
                stream.recipient,
                recipientPayout
            );
            require(recipientTransferSuccess, "Transfer failed");
        }

        if (creatorRefund > 0) {
            bool creatorTransferSuccess = stablecoin.transfer(
                stream.creator,
                creatorRefund
            );
            require(creatorTransferSuccess, "Transfer failed");
        }

        emit StreamCancelled(
            streamId,
            msg.sender,
            recipientPayout,
            creatorRefund
        );
    }

    function updateStreamRecipient(uint256 streamId, address newRecipient) external {
        Stream storage stream = streams[streamId];

        if (!stream.exists) {
            revert StreamNotFound();
        }
        if (stream.creator != msg.sender) {
            revert NotStreamCreator();
        }
        if (newRecipient == address(0)) {
            revert InvalidRecipient();
        }

        address oldRecipient = stream.recipient;
        stream.recipient = newRecipient;
        userStreams[newRecipient].push(streamId);

        emit StreamRecipientUpdated(streamId, oldRecipient, newRecipient);
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

        uint256 duration = stream.endTime - stream.startTime;
        uint256 elapsed;
        if (block.timestamp >= stream.endTime) {
            elapsed = duration;
        } else if (block.timestamp <= stream.startTime) {
            elapsed = 0;
        } else {
            elapsed = block.timestamp - stream.startTime;
        }

        uint256 vested = (stream.totalDeposited * elapsed) / duration;
        if (vested <= stream.totalWithdrawn) {
            return 0;
        }
        return vested - stream.totalWithdrawn;
    }

    function getStreamInfo(
        uint256 streamId
    )
        external
        view
        returns (
            address recipient,
            uint256 totalDeposited,
            uint256 totalWithdrawn,
            uint256 startTime,
            uint256 endTime,
            bool exists
        )
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

    function getUserStreams(address user) external view returns (uint256[] memory) {
        return userStreams[user];
    }
}
