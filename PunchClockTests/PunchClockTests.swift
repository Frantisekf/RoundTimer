//
//  PunchClockTests.swift
//  PunchClockTests
//
//  Created by Frantisek Farkas on 07.01.2026.
//

import XCTest
@testable import PunchClock

final class PunchClockTests: XCTestCase {

    // MARK: - Preset Tests

    func testPresetInitialization() throws {
        let preset = Preset(
            name: "Test Preset",
            prepareTime: 10,
            roundTime: 180,
            restTime: 60,
            numberOfRounds: 3
        )

        XCTAssertEqual(preset.name, "Test Preset")
        XCTAssertEqual(preset.prepareTime, 10)
        XCTAssertEqual(preset.roundTime, 180)
        XCTAssertEqual(preset.restTime, 60)
        XCTAssertEqual(preset.numberOfRounds, 3)
    }

    func testDefaultPresetsExist() throws {
        let presets = Preset.defaultPresets

        XCTAssertFalse(presets.isEmpty)
        XCTAssertTrue(presets.contains { $0.name == "Boxing Standard" })
        XCTAssertTrue(presets.contains { $0.name == "MMA Style" })
        XCTAssertTrue(presets.contains { $0.name == "Muay Thai" })
        XCTAssertTrue(presets.contains { $0.name == "BJJ Rolling" })
    }

    func testBoxingPresetValues() throws {
        let boxing = Preset.boxingStandard

        XCTAssertEqual(boxing.name, "Boxing Standard")
        XCTAssertEqual(boxing.roundTime, 180) // 3 minutes
        XCTAssertEqual(boxing.restTime, 60)   // 1 minute
        XCTAssertEqual(boxing.numberOfRounds, 12)
    }

    func testBJJPresetValues() throws {
        let bjj = Preset.bjjRolling

        XCTAssertEqual(bjj.name, "BJJ Rolling")
        XCTAssertEqual(bjj.roundTime, 360) // 6 minutes
        XCTAssertEqual(bjj.restTime, 60)   // 1 minute
        XCTAssertEqual(bjj.numberOfRounds, 5)
    }

    // MARK: - Timer State Tests

    func testTimerStateInitialValues() throws {
        let state = TimerState()

        XCTAssertEqual(state.phase, .idle)
        XCTAssertEqual(state.timeRemaining, 0)
        // A workout starts on round 1, and TimerState has said so for a while; this
        // assertion still expected 0. Nothing caught it because CI builds but never runs
        // the tests.
        XCTAssertEqual(state.currentRound, 1)
        XCTAssertFalse(state.isRunning)
    }

    func testTimerPhaseRawValues() throws {
        XCTAssertEqual(TimerPhase.idle.rawValue, "idle")
        XCTAssertEqual(TimerPhase.prepare.rawValue, "prepare")
        XCTAssertEqual(TimerPhase.round.rawValue, "round")
        XCTAssertEqual(TimerPhase.rest.rawValue, "rest")
        XCTAssertEqual(TimerPhase.finished.rawValue, "finished")
    }

    // MARK: - Preset Store Tests

    func testPresetStoreInitialization() throws {
        let store = PresetStore()

        XCTAssertFalse(store.presets.isEmpty)
    }

    func testPresetStoreAddPreset() throws {
        let store = PresetStore()
        let initialCount = store.presets.count

        let newPreset = Preset(
            name: "Custom Test",
            prepareTime: 5,
            roundTime: 120,
            restTime: 30,
            numberOfRounds: 5
        )

        store.addPreset(newPreset)

        XCTAssertEqual(store.presets.count, initialCount + 1)
        XCTAssertTrue(store.presets.contains { $0.name == "Custom Test" })
    }

    func testPresetStoreDeletePreset() throws {
        let store = PresetStore()
        let initialCount = store.presets.count

        if let firstPreset = store.presets.first {
            store.deletePreset(firstPreset)
            XCTAssertEqual(store.presets.count, initialCount - 1)
        }
    }

    // MARK: - Time Formatting Tests

    func testTotalWorkoutTime() throws {
        let preset = Preset(
            name: "Test",
            prepareTime: 10,
            roundTime: 180,
            restTime: 60,
            numberOfRounds: 3
        )

        // Total = prepare + (rounds * roundTime) + ((rounds - 1) * restTime)
        // Total = 10 + (3 * 180) + (2 * 60) = 10 + 540 + 120 = 670 seconds
        let expectedTotal = 10 + (3 * 180) + (2 * 60)
        let actualTotal = preset.prepareTime + (preset.numberOfRounds * preset.roundTime) + ((preset.numberOfRounds - 1) * preset.restTime)

        XCTAssertEqual(actualTotal, expectedTotal)
    }
}
