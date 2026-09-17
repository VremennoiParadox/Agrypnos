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
}
