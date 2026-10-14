//
//  TimerManagerTests.swift
//  PunchClockTests
//
//  Covers what happens to a running workout while the app is suspended — the one piece
//  of timing logic that cannot be checked by using the app, because it only runs after
//  the phone has been locked for long enough to miss a phase.
//

import XCTest

@testable import PunchClock

final class TimerManagerTests: XCTestCase {
    /// 10s prepare, 3 rounds of 3 minutes with a minute between: 660s of work after the
    /// prepare, which makes the arithmetic in these tests easy to follow.
    private let preset = Preset(
        name: "Test",
        prepareTime: 10,
        roundTime: 180,
        restTime: 60,
        numberOfRounds: 3
    )

    private var manager: TimerManager!

    override func setUp() {
        super.setUp()
        manager = TimerManager()
        manager.isMuted = true
    }

    override func tearDown() {
        manager.stop()
        manager = nil
        super.tearDown()
    }

    // MARK: - Starting

    func testStartBeginsInPrepare() {
        manager.start(with: preset)

        XCTAssertEqual(manager.state.phase, .prepare)
        XCTAssertEqual(manager.state.timeRemaining, 10)
        XCTAssertEqual(manager.state.currentRound, 1)
        XCTAssertTrue(manager.state.isRunning)
    }

    func testStartSkipsPrepareWhenThereIsNone() {
        var noPrepare = preset
        noPrepare.prepareTime = 0

        manager.start(with: noPrepare)

        XCTAssertEqual(manager.state.phase, .round, "straight into round 1")
        XCTAssertEqual(manager.state.timeRemaining, 180)
    }

    // MARK: - Catching up after the app was suspended

    func testCatchesUpPartWayIntoTheFirstRound() {
        manager.start(with: preset)

        // 100s gone: the 10s prepare elapsed and 90s of round 1 with it.
        manager.catchUpPhases(missedSeconds: 100, preset: preset)

        XCTAssertEqual(manager.state.phase, .round)
        XCTAssertEqual(manager.state.currentRound, 1)
        XCTAssertEqual(manager.state.timeRemaining, 80)
    }

    func testCatchesUpIntoTheRestAfterRoundOne() {
        manager.start(with: preset)

        // Past the whole of round 1 (180s) and 20s into the rest.
        manager.catchUpPhases(missedSeconds: 200, preset: preset)

        XCTAssertEqual(manager.state.phase, .rest)
        XCTAssertEqual(manager.state.currentRound, 1, "the round only advances when rest ends")
        XCTAssertEqual(manager.state.timeRemaining, 40)
    }

    func testCatchesUpAcrossSeveralRounds() {
        manager.start(with: preset)

        // round 1 + rest + round 2 + rest = 480s, then 30s into round 3.
        manager.catchUpPhases(missedSeconds: 510, preset: preset)

        XCTAssertEqual(manager.state.phase, .round)
        XCTAssertEqual(manager.state.currentRound, 3)
        XCTAssertEqual(manager.state.timeRemaining, 150)
    }

    func testAWorkoutMissedEntirelyEndsFinished() {
        manager.start(with: preset)

        manager.catchUpPhases(missedSeconds: 10_000, preset: preset)

        XCTAssertEqual(manager.state.phase, .finished)
        XCTAssertFalse(manager.state.isRunning)
        XCTAssertEqual(manager.state.timeRemaining, 0)
    }

    func testCatchUpLeavesTheWorkoutRunning() {
        manager.start(with: preset)

        manager.catchUpPhases(missedSeconds: 200, preset: preset)

        XCTAssertTrue(manager.state.isRunning, "coming back to a live workout, not a stopped one")
    }

    // MARK: - Controls

    func testPauseStopsTheClockAndResumeCarriesOn() {
        manager.start(with: preset)
        let remaining = manager.state.timeRemaining

        manager.pause()
        XCTAssertFalse(manager.state.isRunning)
        XCTAssertEqual(manager.state.timeRemaining, remaining, "pausing does not consume time")

        manager.resume()
        XCTAssertTrue(manager.state.isRunning)
        XCTAssertEqual(manager.state.timeRemaining, remaining)
    }

    func testSkipPhaseMovesOnWithoutWaiting() {
        manager.start(with: preset)
        XCTAssertEqual(manager.state.phase, .prepare)

        manager.skipPhase()

        XCTAssertEqual(manager.state.phase, .round)
        XCTAssertEqual(manager.state.timeRemaining, 180)
    }

    func testAddTimeExtendsTheCurrentPhase() {
        manager.start(with: preset)
        let before = manager.state.timeRemaining

        manager.addTime(30)

        XCTAssertEqual(manager.state.timeRemaining, before + 30)
    }

    func testStopReturnsToIdle() {
        manager.start(with: preset)

        manager.stop()

        XCTAssertEqual(manager.state.phase, .idle)
        XCTAssertFalse(manager.state.isRunning)
    }
}
