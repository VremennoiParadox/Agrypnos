import XCTest
@testable import AgrypnosCore

final class StatusItemStateTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 10_000)

    func testDisengagedIsOffForEveryHowLong() {
        for duration in stickyHowLong {
            XCTAssertEqual(
                StatusItemState.from(engaged: false, duration: duration),
                .off,
                "disengaged \(duration) must be off, not a leftover Agents/armed title"
            )
            XCTAssertEqual(AgrypnosCopy.statusItemTitle(.off), "")
        }
    }

    func testEngagedStickyTimersAreArmedNotACountdown() {
        for duration in [DurationOption.indefinite, .oneHour, .threeHours, .customMinutes(33)] {
            XCTAssertEqual(
                StatusItemState.from(engaged: true, duration: duration),
                .armed
            )
            let title = AgrypnosCopy.statusItemTitle(.armed)
            XCTAssertEqual(title, "Armed.")
            assertNoCountdownFiction(title)
        }
    }

    func testEngagedAgentsHowLongIsAgentsNotACountdown() {
        XCTAssertEqual(
            StatusItemState.from(engaged: true, duration: .untilAgentsSettle),
            .agents
        )
        XCTAssertEqual(AgrypnosCopy.statusItemTitle(.agents), "Agents.")
        assertNoCountdownFiction(AgrypnosCopy.statusItemTitle(.agents))
    }

    func testEngineOffArmedAndAgentsFollowKeepTheWatch() {
        var engine = WatchEngine(preferences: .default)
        XCTAssertEqual(engine.statusItemState, .off)

        _ = engine.userSetEngaged(true, now: t0)
        XCTAssertEqual(engine.statusItemState, .armed)
        XCTAssertEqual(AgrypnosCopy.statusItemTitle(engine.statusItemState), "Armed.")

        _ = engine.userSetDuration(.oneHour, now: t0)
        XCTAssertEqual(engine.statusItemState, .armed)

        _ = engine.userSetDuration(.untilAgentsSettle, now: t0)
        XCTAssertEqual(engine.statusItemState, .agents)
        XCTAssertEqual(AgrypnosCopy.statusItemTitle(engine.statusItemState), "Agents.")

        _ = engine.userSetEngaged(false, now: t0.addingTimeInterval(1))
        XCTAssertEqual(engine.statusItemState, .off)
        XCTAssertEqual(engine.preferences.duration, .untilAgentsSettle)
    }

    func testTimedClockDoesNotBecomeDigitsBecauseStickyTimersDoNotAutoOff() {
        var prefs = UserPreferences.default
        prefs.duration = .oneHour
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0)
        XCTAssertEqual(engine.timerEnd, t0.addingTimeInterval(3600))
        XCTAssertEqual(engine.statusItemState, .armed)
        XCTAssertNil(
            StatusItemState.autoOffEndClock(
                engaged: true,
                duration: .oneHour,
                timerEnd: engine.timerEnd
            )
        )
        XCTAssertNil(
            engine.statusItemRemainingSeconds(now: t0.addingTimeInterval(60))
        )
        XCTAssertNil(
            StatusItemState.remainingSeconds(
                engaged: true,
                duration: .oneHour,
                timerEnd: engine.timerEnd,
                now: t0.addingTimeInterval(3_540)
            )
        )
        let title = AgrypnosCopy.statusItemTitle(engine.statusItemState)
        XCTAssertEqual(title, "Armed.")
        assertNoCountdownFiction(title)
        XCTAssertFalse(title.contains("1h"))
        XCTAssertFalse(title.lowercased().contains("left"))
    }

    func testCustomAndIndefiniteHaveNoAutoOffEndClock() {
        for duration in [DurationOption.indefinite, .threeHours, .customMinutes(33)] {
            let fakeEnd = t0.addingTimeInterval(1_980)
            XCTAssertNil(
                StatusItemState.autoOffEndClock(
                    engaged: true,
                    duration: duration,
                    timerEnd: fakeEnd
                )
            )
            XCTAssertNil(
                StatusItemState.remainingSeconds(
                    engaged: true,
                    duration: duration,
                    timerEnd: fakeEnd,
                    now: t0
                )
            )
            XCTAssertEqual(
                StatusItemState.from(engaged: true, duration: duration),
                .armed
            )
        }
    }

    func testAgentsIdleAfterWaitIsOffNotSettleCountdown() {
        var prefs = UserPreferences.default
        prefs.duration = .untilAgentsSettle
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0)
        XCTAssertEqual(engine.statusItemState, .agents)
        XCTAssertNil(engine.timerEnd)
        XCTAssertNil(
            StatusItemState.autoOffEndClock(
                engaged: true,
                duration: .untilAgentsSettle,
                timerEnd: nil
            )
        )
        XCTAssertNil(engine.statusItemRemainingSeconds(now: t0.addingTimeInterval(30)))

        XCTAssertTrue(
            engine.tick(now: t0.addingTimeInterval(20), safety: .acPower, agents: .busy).isEmpty
        )
        XCTAssertEqual(engine.statusItemState, .agents)
        XCTAssertNil(engine.statusItemRemainingSeconds(now: t0.addingTimeInterval(20)))

        _ = engine.tick(
            now: t0.addingTimeInterval(20 + 120),
            safety: .acPower,
            agents: .idle
        )
        XCTAssertFalse(engine.engaged)
        XCTAssertEqual(engine.statusItemState, .off)
        XCTAssertEqual(engine.preferences.duration, .untilAgentsSettle)
        XCTAssertNil(engine.statusItemRemainingSeconds(now: t0.addingTimeInterval(20 + 120)))
        assertNoCountdownFiction(AgrypnosCopy.statusItemTitle(engine.statusItemState))
    }

    func testStatusItemCopyIsPlainAndNeverACountdown() {
        XCTAssertEqual(AgrypnosCopy.statusItemArmed, "Armed.")
        XCTAssertEqual(AgrypnosCopy.statusItemAgents, "Agents.")
        for text in [
            AgrypnosCopy.statusItemArmed,
            AgrypnosCopy.statusItemAgents,
            AgrypnosCopy.statusItemTitle(.off),
            AgrypnosCopy.statusItemTitle(.armed),
            AgrypnosCopy.statusItemTitle(.agents),
        ] {
            assertNoCountdownFiction(text)
            XCTAssertFalse(text.lowercased().contains("watt"))
            XCTAssertFalse(text.lowercased().contains("1.76"))
        }
    }

    private var stickyHowLong: [DurationOption] {
        [.indefinite, .oneHour, .threeHours, .untilAgentsSettle, .customMinutes(33)]
    }

    private func assertNoCountdownFiction(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        let lower = text.lowercased()
        XCTAssertFalse(lower.contains("left"), "countdown fiction: \(text)", file: file, line: line)
        XCTAssertFalse(lower.contains("remaining"), "countdown fiction: \(text)", file: file, line: line)
        XCTAssertNil(
            text.rangeOfCharacter(from: .decimalDigits),
            "status-item digits need a real auto-off end clock: \(text)",
            file: file,
            line: line
        )
        XCTAssertFalse(text.contains(":"), "ticking clock fiction: \(text)", file: file, line: line)
    }
}

private extension SafetyInputs {
    static let acPower = SafetyInputs(
        batteryPercent: 90,
        onBatteryDischarging: false,
        thermalSerious: false,
        lowPowerMode: false
    )
}

private extension AgentSnapshot {
    static let idle = AgentSnapshot(reports: [])
    static let busy = AgentSnapshot(reports: [
        AgentReport(
            kind: .claudeCode,
            processRunning: true,
            cpuBusy: true,
            recentSessionWrite: true,
            isBusy: true
        )
    ])
}
