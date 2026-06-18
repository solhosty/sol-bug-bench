// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/StableCoin.sol";

/// @dev Drives the TokenStreamer through create/add/withdraw/warp sequences.
contract StreamerHandler is Test {
    StableCoin public stablecoin;
    TokenStreamer public streamer;

    uint256[] public streamIds;
    address internal recipient = address(0xBEEF);

    constructor(StableCoin stablecoin_, TokenStreamer streamer_) {
        stablecoin = stablecoin_;
        streamer = streamer_;
    }

    function createStream(uint256 amount, uint256 duration) external {
        amount = bound(amount, 1, 1_000_000);
        duration = bound(duration, 1 hours, 365 days);

        stablecoin.mint(address(this), amount);
        stablecoin.approve(address(streamer), amount);
        uint256 id = streamer.createStream(recipient, amount, duration);
        streamIds.push(id);
    }

    function addToStream(uint256 streamSeed, uint256 amount) external {
        if (streamIds.length == 0) return;
        uint256 id = streamIds[streamSeed % streamIds.length];
        (,,,, uint256 endTime,) = streamer.getStreamInfo(id);
        if (block.timestamp >= endTime) return;
        amount = bound(amount, 1, 1_000_000);

        stablecoin.mint(address(this), amount);
        stablecoin.approve(address(streamer), amount);
        streamer.addToStream(id, amount);
    }

    function withdraw(uint256 streamSeed) external {
        if (streamIds.length == 0) return;
        uint256 id = streamIds[streamSeed % streamIds.length];
        vm.prank(recipient);
        try streamer.withdrawFromStream(id) {} catch {}
    }

    function warp(uint256 secs) external {
        vm.warp(block.timestamp + bound(secs, 1, 30 days));
    }

    function streamCount() external view returns (uint256) {
        return streamIds.length;
    }
}

contract StableCoinInvariantTest is Test {
    StableCoin public stablecoin;
    TokenStreamer public streamer;
    StreamerHandler public handler;

    function setUp() public {
        stablecoin = new StableCoin();
        streamer = new TokenStreamer(stablecoin);
        handler = new StreamerHandler(stablecoin, streamer);
        targetContract(address(handler));
    }

    /// TS-G2: cumulative withdrawals from a stream never exceed its deposits.
    function invariant_TS_G2_withdrawnNeverExceedsDeposited() public view {
        uint256 count = handler.streamCount();
        for (uint256 i = 0; i < count; i++) {
            uint256 id = handler.streamIds(i);
            (, uint256 deposited, uint256 withdrawn,,,) = streamer.getStreamInfo(id);
            assertLe(withdrawn, deposited);
        }
    }

    // --- Violation proofs (expected-broken invariants) ---

    /// SC-G1: stablecoin supply must only grow via an authorized minter.
    function test_SC_G1_anyoneCanMint() public {
        uint256 before = stablecoin.totalSupply();
        address stranger = address(0xDEAD);

        vm.prank(stranger);
        stablecoin.mint(stranger, 1_000_000);

        assertEq(stablecoin.totalSupply(), before + 1_000_000);
    }

    /// SC-G2: a whole unit must equal 10**decimals base units consistently.
    /// `decimals()` returns 1, so integrations assuming 18 mis-scale by 10^17.
    function test_SC_G2_nonStandardDecimals() public view {
        assertEq(stablecoin.decimals(), 1);
        // Constructor minted 1_000_000 whole units -> only 10x in base units.
        assertEq(stablecoin.totalSupply(), 1_000_000 * 10);
    }

    /// TS-F1: tokens added mid-stream must vest only over the remaining
    /// duration. `getAvailableTokens` applies elapsed time to the full
    /// deposited total, so a top-up is retroactively vested.
    function test_TS_F1_addToStreamRetroactivelyVests() public {
        uint256 duration = 1 hours; // 3600s
        stablecoin.mint(address(this), 7200);
        stablecoin.approve(address(streamer), 7200);

        uint256 id = streamer.createStream(address(0xBEEF), 3600, duration);

        vm.warp(block.timestamp + 1800); // halfway
        uint256 availBefore = streamer.getAvailableTokens(id);
        assertEq(availBefore, 1800); // half of the original 3600 vested

        streamer.addToStream(id, 3600); // total deposited now 7200

        // Newly added tokens should be ~unvested; instead half is available.
        uint256 availAfter = streamer.getAvailableTokens(id);
        assertEq(availAfter, 3600);
        assertEq(availAfter - availBefore, 1800); // 1800 of the top-up vested instantly
    }
}
