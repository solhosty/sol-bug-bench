// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract StableCoin is ERC20 {
    event TokensMinted(address indexed to, uint256 amount);

    constructor() ERC20("StableCoin", "STC") {
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }

    function decimals() public pure override returns (uint8) {
        return 1;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }
}

contract TokenStreamer {
    error InvalidAmount();
    error InvalidRecipient();
    error InvalidStreamDuration();
    error StreamNotFound();
    error NotStreamRecipient();
    error StreamEnded();

    struct Stream {
        address recipient;
        uint256 totalDeposited;
        uint256 totalWithdrawn;
        uint256 startTime;
        uint256 endTime;
        bool exists;
    }

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

    StableCoin public immutable token;
    uint256 public nextStreamId;
    mapping(uint256 => Stream) public streams;
    mapping(address => uint256[]) private userStreams;

    uint256 public constant MIN_STREAM_DURATION = 1 hours;
    uint256 public constant MAX_STREAM_DURATION = 365 days;

    constructor(StableCoin stableCoin) {
        token = stableCoin;
        nextStreamId = 1;
    }

    function createStream(address recipient, uint256 amount, uint256 duration)
        external
        returns (uint256 streamId)
    {
        if (amount == 0) revert InvalidAmount();
        if (recipient == address(0)) revert InvalidRecipient();
        if (duration < MIN_STREAM_DURATION || duration > MAX_STREAM_DURATION) {
            revert InvalidStreamDuration();
        }

        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        streamId = nextStreamId++;
        streams[streamId] = Stream({
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
        if (amount == 0) revert InvalidAmount();
        Stream storage stream = streams[streamId];
        if (!stream.exists) revert StreamNotFound();
        if (block.timestamp >= stream.endTime) revert StreamEnded();

        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        stream.totalDeposited += amount;

        emit StreamDeposit(streamId, msg.sender, amount);
    }

    function withdrawFromStream(uint256 streamId) external {
        Stream storage stream = streams[streamId];
        if (!stream.exists) revert StreamNotFound();
        if (msg.sender != stream.recipient) revert NotStreamRecipient();

        uint256 amount = getAvailableTokens(streamId);
        if (amount == 0) revert InvalidAmount();

        stream.totalWithdrawn += amount;
        require(token.transfer(msg.sender, amount), "Transfer failed");

        emit StreamWithdrawal(streamId, msg.sender, amount);
    }

    function getStreamRate(uint256 streamId) public view returns (uint256) {
        Stream memory stream = streams[streamId];
        if (!stream.exists) return 0;

        uint256 duration = stream.endTime - stream.startTime;
        return stream.totalDeposited / duration;
    }

    function getAvailableTokens(uint256 streamId) public view returns (uint256) {
        Stream memory stream = streams[streamId];
        if (!stream.exists) return 0;

        uint256 currentTime = block.timestamp;
        if (currentTime > stream.endTime) {
            currentTime = stream.endTime;
        }
        if (currentTime <= stream.startTime) {
            return 0;
        }

        uint256 duration = stream.endTime - stream.startTime;
        uint256 elapsed = currentTime - stream.startTime;
        uint256 vested = (stream.totalDeposited * elapsed) / duration;

        if (vested <= stream.totalWithdrawn) {
            return 0;
        }

        return vested - stream.totalWithdrawn;
    }

    function getStreamInfo(uint256 streamId)
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
        Stream memory stream = streams[streamId];
        if (!stream.exists) revert StreamNotFound();

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
