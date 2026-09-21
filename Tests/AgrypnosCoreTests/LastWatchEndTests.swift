import XCTest
@testable import AgrypnosCore

final class LastWatchEndTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 10_000)

    func testDefaultPreferencesHaveNoLastWatchEnd() {
        XCTAssertNil(UserPreferences.default.lastWatchEnd)
        XCTAssertNil(UserPreferences().lastWatchEnd)
    }

    func testLastWatchEndRoundTripsWithPreferences() throws {
        var prefs = UserPreferences.default
        prefs.lastWatchEnd = LastWatchEnd(endedAt: t0, reason: .batteryFloor)
        let loaded = try JSONDecoder().decode(UserPreferences.self, from: try JSONEncoder().encode(prefs))
        XCTAssertEqual(loaded.lastWatchEnd?.endedAt, t0)
        XCTAssertEqual(loaded.lastWatchEnd?.reason, .batteryFloor)
    }

    func testMissingLastWatchEndKeyDecodesNil() throws {
        let json = """
        {"batteryFloorPercent":15,"duration":"indefinite","keyboardBacklightOff":true,"applyBrightnessFloor":true,"brightnessFloorPercent":15,"agentSettleGrace":120,"sessionFreshness":45,"lidOpenRampSeconds":2,"hotkey":{"keyCode":0,"option":true,"command":true,"shift":false,"control":false},"thermalAutoOff":true,"notifEnabled":false}
        """
        let decoded = try JSONDecoder().decode(UserPreferences.self, from: Data(json.utf8))
        XCTAssertNil(decoded.lastWatchEnd)
    }

    func testLastWatchEndCopyMatchesLockedReasons() {
        XCTAssertEqual(AgrypnosCopy.lastWatchEndNone, "No watch has ended yet.")
        let expected: [(DisengageReason, String)] = [
            (.user, "Last watch ended at 23:04, because you turned it off."),
            (.timerExpired, "Last watch ended at 23:04, because the timer ended."),
            (.batteryFloor, "Last watch ended at 23:04, because the battery floor was reached."),
            (.thermal, "Last watch ended at 23:04, because thermal pressure turned the watch off."),
            (.agentsSettled, "Last watch ended at 23:04, because local busy signals stayed idle after the wait."),
            (.lowPowerMode, "Last watch ended at 23:04, because Low Power Mode was on."),
        ]
        for (reason, line) in expected {
            XCTAssertEqual(AgrypnosCopy.lastWatchEndCaption(when: "23:04", reason: reason), line)
        }
    }

    func testLastWatchEndCopyIsHonestAndFitsThreeLines() {
        let caption = AgrypnosCopy.lastWatchEndCaption(
            when: "September 17, 2026 at 11:04 PM", reason: .agentsSettled
        )
        let blob = (AgrypnosCopy.lastWatchEndNone + "\n" + caption).lowercased()
        for banned in [
            "we put the laptop to sleep", "screen off", "agent finished", "job done",
            "still thinking", "finished working", "ran out of battery", "error occurred",
            "agent stopped", "job finished", "stands down", "°c", "warranty",
        ] {
            XCTAssertFalse(blob.contains(banned), banned)
        }
        XCTAssertTrue(caption.contains("local busy signals"))
        XCTAssertTrue(caption.contains("after the wait"))
        XCTAssertEqual(PopoverCopyLayout.lastWatchEndMaxLines, 3)
        for reason in DisengageReason.allCases {
            let lines = CopyWrap.lineCount(
                AgrypnosCopy.lastWatchEndCaption(when: "September 17, 2026 at 11:04 PM", reason: reason),
                columns: PopoverCopyLayout.innerColumns
            )
            XCTAssertLessThanOrEqual(lines, PopoverCopyLayout.lastWatchEndMaxLines)
        }
    }

    func testLastWatchEndClockOmitsDateOnTheSameCalendarDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let locale = Locale(identifier: "en_GB")
        let ended = calendar.date(from: DateComponents(year: 2026, month: 9, day: 17, hour: 23, minute: 4))!
        let same = calendar.date(from: DateComponents(year: 2026, month: 9, day: 17, hour: 23, minute: 50))!
        let next = calendar.date(from: DateComponents(year: 2026, month: 9, day: 18, hour: 8, minute: 0))!
        let today = AgrypnosCopy.lastWatchEndClock(endedAt: ended, now: same, calendar: calendar, locale: locale)
        let other = AgrypnosCopy.lastWatchEndClock(endedAt: ended, now: next, calendar: calendar, locale: locale)
        XCTAssertFalse(today.contains("2026"))
        XCTAssertFalse(today.contains("Sep"))
        XCTAssertTrue(other.contains("2026"))
        let event = LastWatchEnd(endedAt: ended, reason: .user)
        XCTAssertEqual(
            AgrypnosCopy.lastWatchEndCaption(event: event, now: same, calendar: calendar, locale: locale),
            AgrypnosCopy.lastWatchEndCaption(when: today, reason: .user)
        )
        XCTAssertEqual(
            AgrypnosCopy.lastWatchEndCaption(event: nil, now: same, calendar: calendar, locale: locale),
            AgrypnosCopy.lastWatchEndNone
        )
    }

    func testEveryRealDisengageRecordsLastWatchEnd() {
        func record(_ duration: DurationOption, safety: SafetyInputs, wait: TimeInterval, busyFirst: Bool = false) -> WatchEngine {
            var prefs = UserPreferences.default
            prefs.duration = duration
            var engine = WatchEngine(preferences: prefs)
            _ = engine.userSetEngaged(true, now: t0)
            if busyFirst { _ = engine.tick(now: t0, safety: .acPower, agents: .busy) }
            _ = engine.tick(now: t0.addingTimeInterval(wait), safety: safety, agents: .idle)
            return engine
        }
        var manual = WatchEngine(preferences: .default)
        _ = manual.userSetEngaged(true, now: t0)
        _ = manual.userSetEngaged(false, now: t0.addingTimeInterval(1))
        XCTAssertEqual(manual.preferences.lastWatchEnd, LastWatchEnd(endedAt: t0.addingTimeInterval(1), reason: .user))

        let timer = record(.oneHour, safety: .acPower, wait: 3600)
        XCTAssertNil(timer.preferences.lastWatchEnd)
        XCTAssertTrue(timer.engaged)

        let battery = record(.indefinite, safety: SafetyInputs(batteryPercent: 12, onBatteryDischarging: true, thermalSerious: false, lowPowerMode: false), wait: 1)
        XCTAssertEqual(battery.preferences.lastWatchEnd?.reason, .batteryFloor)

        let thermal = record(.indefinite, safety: SafetyInputs(batteryPercent: 90, onBatteryDischarging: false, thermalSerious: true, lowPowerMode: false), wait: 1)
        XCTAssertEqual(thermal.preferences.lastWatchEnd?.reason, .thermal)

        let agents = record(.untilAgentsSettle, safety: .acPower, wait: 120, busyFirst: true)
        XCTAssertEqual(
            agents.preferences.lastWatchEnd,
            LastWatchEnd(endedAt: t0.addingTimeInterval(120), reason: .agentsSettled)
        )
        XCTAssertFalse(agents.engaged)
        XCTAssertEqual(agents.preferences.duration, .untilAgentsSettle)

        let neverBusy = record(.untilAgentsSettle, safety: .acPower, wait: 120)
        XCTAssertNil(neverBusy.preferences.lastWatchEnd)
        XCTAssertTrue(neverBusy.engaged)

        var leftover = WatchEngine(preferences: .default)
        _ = leftover.adoptLeftoverKernel(now: t0)
        _ = leftover.tick(now: t0.addingTimeInterval(1), safety: .lowPowerDischarging, agents: .idle)
        XCTAssertEqual(leftover.preferences.lastWatchEnd, LastWatchEnd(endedAt: t0.addingTimeInterval(1), reason: .lowPowerMode))
    }

    func testReArmKeepsLastWatchEndUntilTheNextRealEnd() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0)
        _ = engine.userSetEngaged(false, now: t0.addingTimeInterval(5))
        let first = engine.preferences.lastWatchEnd
        _ = engine.userSetEngaged(true, now: t0.addingTimeInterval(10))
        XCTAssertEqual(engine.preferences.lastWatchEnd, first)
        XCTAssertTrue(engine.engaged)
        _ = engine.userSetEngaged(false, now: t0.addingTimeInterval(20))
        XCTAssertEqual(engine.preferences.lastWatchEnd?.endedAt, t0.addingTimeInterval(20))
        _ = engine.userSetEngaged(false, now: t0.addingTimeInterval(30))
        XCTAssertEqual(engine.preferences.lastWatchEnd?.endedAt, t0.addingTimeInterval(20))
    }

    func testForcedLowPowerModeDoesNotRecordAnEnd() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0)
        XCTAssertTrue(engine.tick(now: t0.addingTimeInterval(1), safety: .lowPowerDischarging, agents: .idle).isEmpty)
        XCTAssertTrue(engine.engaged)
        XCTAssertNil(engine.preferences.lastWatchEnd)
    }

    func testRollbackDisarmFailureRestoresPreviousLastWatchEnd() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0)
        _ = engine.userSetEngaged(false, now: t0.addingTimeInterval(5))
        let previous = engine.preferences.lastWatchEnd
        _ = engine.userSetEngaged(true, now: t0.addingTimeInterval(10))
        XCTAssertEqual(
            engine.tick(
                now: t0.addingTimeInterval(11),
                safety: SafetyInputs(
                    batteryPercent: 12,
                    onBatteryDischarging: true,
                    thermalSerious: false,
                    lowPowerMode: false
                ),
                agents: .idle
            ),
            [.disengage(.batteryFloor)]
        )
        XCTAssertEqual(engine.preferences.lastWatchEnd?.reason, .batteryFloor)
        _ = engine.rollbackDisarmFailure(now: t0.addingTimeInterval(12), lidClosed: false)
        XCTAssertTrue(engine.engaged)
        XCTAssertEqual(engine.preferences.lastWatchEnd, previous)
    }
}

private extension SafetyInputs {
    static let acPower = SafetyInputs(
        batteryPercent: 90, onBatteryDischarging: false, thermalSerious: false, lowPowerMode: false
    )
    static let lowPowerDischarging = SafetyInputs(
        batteryPercent: 50, onBatteryDischarging: true, thermalSerious: false, lowPowerMode: true
    )
}

private extension AgentSnapshot {
    static let idle = AgentSnapshot(reports: [])
    static let busy = AgentSnapshot(reports: [
        AgentReport(kind: .claudeCode, processRunning: true, cpuBusy: true, recentSessionWrite: true, isBusy: true)
    ])
}
