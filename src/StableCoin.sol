// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract StableCoin is ERC20 {
    event TokensMinted(address indexed to, uint256 amount);

    constructor() ERC20("StableCoin", "STBL") {
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
    error StreamNotFound();
    error InvalidStreamDuration();
    error NotStreamRecipient();
    error StreamEnded();
    error InvalidRecipient();

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
    event StreamDeposit(uint256 indexed streamId, address indexed sender, uint256 amount);

    struct Stream {
        address recipient;
        uint256 totalDeposited;
        uint256 totalWithdrawn;
        uint256 startTime;
        uint256 endTime;
        bool exists;
    }

    StableCoin public immutable token;
    uint256 public nextStreamId = 1;

    mapping(uint256 => Stream) private streams;
    mapping(uint256 => address) private streamOwners;
    mapping(address => uint256[]) private userStreams;

    constructor(StableCoin token_) {
        token = token_;
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

        token.transferFrom(msg.sender, address(this), amount);

        streamId = nextStreamId++;
        streams[streamId] = Stream({
            recipient: recipient,
            totalDeposited: amount,
            totalWithdrawn: 0,
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            exists: true
        });
        streamOwners[streamId] = msg.sender;
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
        if (block.timestamp > stream.endTime) {
            revert StreamEnded();
        }

        token.transferFrom(msg.sender, address(this), amount);
        stream.totalDeposited += amount;

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

        uint256 amount = getAvailableTokens(streamId);
        if (amount == 0) {
            return;
        }

        stream.totalWithdrawn += amount;
        bool success = token.transfer(msg.sender, amount);
        require(success, "Transfer failed");

        emit StreamWithdrawal(streamId, msg.sender, amount);
    }

    function getStreamRate(uint256 streamId) public view returns (uint256) {
        Stream memory stream = streams[streamId];
        if (!stream.exists) {
            return 0;
        }

        uint256 duration = stream.endTime - stream.startTime;
        return stream.totalDeposited / duration;
    }

    function getAvailableTokens(uint256 streamId) public view returns (uint256) {
        Stream memory stream = streams[streamId];
        if (!stream.exists) {
            return 0;
        }

        if (block.timestamp >= stream.endTime) {
            return stream.totalDeposited - stream.totalWithdrawn;
        }

        uint256 elapsed = block.timestamp - stream.startTime;
        uint256 duration = stream.endTime - stream.startTime;
        uint256 unlocked = (stream.totalDeposited * elapsed) / duration;
        if (unlocked <= stream.totalWithdrawn) {
            return 0;
        }

        uint256 available = unlocked - stream.totalWithdrawn;
        uint256 remaining = stream.totalDeposited - stream.totalWithdrawn;
        if (available > remaining) {
            return remaining;
        }
        return available;
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
        Stream memory stream = streams[streamId];
        if (!stream.exists) {
            revert StreamNotFound();
        }

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
