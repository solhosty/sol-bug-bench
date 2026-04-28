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
    error StreamNotFound();
    error InvalidStreamDuration();
    error NotStreamRecipient();
    error StreamEnded();
    error InvalidRecipient();
    error NotAuthorized();
    error StreamAlreadyActive();

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
    event StreamRecipientUpdated(
        uint256 indexed streamId,
        address indexed previousRecipient,
        address indexed newRecipient,
        address updater
    );

    struct Stream {
        address sender;
        address recipient;
        uint256 totalDeposited;
        uint256 totalWithdrawn;
        uint256 startTime;
        uint256 endTime;
        uint256 vestedCheckpoint;
        uint256 unvestedCheckpoint;
        uint256 checkpointTime;
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

        bool success = stablecoin.transferFrom(msg.sender, address(this), amount);
        require(success, "Transfer failed");

        streamId = nextStreamId;
        nextStreamId += 1;

        streams[streamId] = Stream({
            sender: msg.sender,
            recipient: recipient,
            totalDeposited: amount,
            totalWithdrawn: 0,
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            vestedCheckpoint: 0,
            unvestedCheckpoint: amount,
            checkpointTime: block.timestamp,
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
        if (amount == 0) {
            revert InvalidAmount();
        }
        if (block.timestamp >= stream.endTime) {
            revert StreamEnded();
        }

        bool success = stablecoin.transferFrom(msg.sender, address(this), amount);
        require(success, "Transfer failed");

        uint256 vestedAtTopUp = _syncVesting(stream);
        uint256 unvestedAtTopUp = stream.totalDeposited - vestedAtTopUp;

        stream.totalDeposited = vestedAtTopUp + unvestedAtTopUp + amount;
        stream.unvestedCheckpoint = unvestedAtTopUp + amount;

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

    function getStreamRate(uint256 streamId) external view returns (uint256) {
        Stream storage stream = streams[streamId];
        if (!stream.exists) {
            return 0;
        }
        if (block.timestamp >= stream.endTime) {
            return 0;
        }

        uint256 vested = _vestedAmount(stream, block.timestamp);
        uint256 remainingUnvested = stream.totalDeposited - vested;
        uint256 remainingDuration = stream.endTime - block.timestamp;
        return remainingUnvested / remainingDuration;
    }

    function getAvailableTokens(uint256 streamId) public view returns (uint256) {
        Stream storage stream = streams[streamId];
        if (!stream.exists) {
            return 0;
        }

        uint256 vested = _vestedAmount(stream, block.timestamp);
        if (vested <= stream.totalWithdrawn) {
            return 0;
        }
        return vested - stream.totalWithdrawn;
    }

    function updateStreamRecipient(uint256 streamId, address newRecipient) external {
        Stream storage stream = streams[streamId];
        if (!stream.exists) {
            revert StreamNotFound();
        }
        if (newRecipient == address(0)) {
            revert InvalidRecipient();
        }
        if (msg.sender != stream.recipient && msg.sender != stream.sender) {
            revert NotAuthorized();
        }
        if (block.timestamp > stream.startTime || stream.vestedCheckpoint > 0) {
            revert StreamAlreadyActive();
        }

        address previousRecipient = stream.recipient;
        if (previousRecipient == newRecipient) {
            revert InvalidRecipient();
        }

        _removeUserStream(previousRecipient, streamId);
        userStreams[newRecipient].push(streamId);
        stream.recipient = newRecipient;

        emit StreamRecipientUpdated(
            streamId,
            previousRecipient,
            newRecipient,
            msg.sender
        );
    }

    function _vestedAmount(
        Stream storage stream,
        uint256 timestamp
    ) internal view returns (uint256) {
        if (timestamp >= stream.endTime) {
            return stream.vestedCheckpoint + stream.unvestedCheckpoint;
        }
        if (timestamp <= stream.checkpointTime) {
            return stream.vestedCheckpoint;
        }

        uint256 checkpointDuration = stream.endTime - stream.checkpointTime;
        uint256 elapsedSinceCheckpoint = timestamp - stream.checkpointTime;
        uint256 newlyVested =
            (stream.unvestedCheckpoint * elapsedSinceCheckpoint) /
            checkpointDuration;

        return stream.vestedCheckpoint + newlyVested;
    }

    function _syncVesting(Stream storage stream) internal returns (uint256 vestedNow) {
        vestedNow = _vestedAmount(stream, block.timestamp);
        stream.vestedCheckpoint = vestedNow;
        stream.unvestedCheckpoint = stream.totalDeposited - vestedNow;
        stream.checkpointTime = block.timestamp;
    }

    function _removeUserStream(address user, uint256 streamId) internal {
        uint256[] storage streamsForUser = userStreams[user];
        uint256 length = streamsForUser.length;

        for (uint256 i = 0; i < length; i++) {
            if (streamsForUser[i] == streamId) {
                streamsForUser[i] = streamsForUser[length - 1];
                streamsForUser.pop();
                break;
            }
        }
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
