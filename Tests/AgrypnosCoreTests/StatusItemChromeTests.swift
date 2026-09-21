import XCTest
@testable import AgrypnosCore

final class StatusItemChromeTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 10_000)

    func testOffIsImageOnlyWithAnEmptyTitle() {
        let chrome = StatusItemChrome.make(
            state: .off,
            remainingSeconds: 3_600
        )
        XCTAssertEqual(chrome.title, "")
        XCTAssertEqual(chrome.title, AgrypnosCopy.statusItemTitle(.off))
        XCTAssertEqual(chrome.accessibilityTitle, AgrypnosCopy.appName)
        XCTAssertEqual(chrome.length, .square)
        XCTAssertEqual(chrome.imagePosition, .imageOnly)
        assertNoCountdownFiction(chrome.title)
        assertNoCountdownFiction(chrome.accessibilityTitle)
    }

    func testArmedHowLongShowsArmedWithGlyphAndNoCountdown() {
        for duration in [DurationOption.indefinite, .oneHour, .threeHours, .customMinutes(33)] {
            let state = StatusItemState.from(engaged: true, duration: duration)
            let chrome = StatusItemChrome.make(
                state: state,
                remainingSeconds: 3_540
            )
            XCTAssertEqual(state, .armed)
            XCTAssertEqual(chrome.title, "Armed.")
            XCTAssertEqual(chrome.title, AgrypnosCopy.statusItemArmed)
            XCTAssertEqual(chrome.accessibilityTitle, "Agrypnos, Armed.")
            XCTAssertEqual(chrome.length, .variable)
            XCTAssertEqual(chrome.imagePosition, .imageLeading)
            assertNoCountdownFiction(chrome.title)
            assertNoCountdownFiction(chrome.accessibilityTitle)
        }
    }

    func testAgentsHowLongShowsAgentsWithGlyphAndNoCountdown() {
        let chrome = StatusItemChrome.make(
            state: .agents,
            remainingSeconds: 120
        )
        XCTAssertEqual(chrome.title, "Agents.")
        XCTAssertEqual(chrome.title, AgrypnosCopy.statusItemAgents)
        XCTAssertEqual(chrome.accessibilityTitle, "Agrypnos, Agents.")
        XCTAssertEqual(chrome.length, .variable)
        XCTAssertEqual(chrome.imagePosition, .imageLeading)
        assertNoCountdownFiction(chrome.title)
        assertNoCountdownFiction(chrome.accessibilityTitle)
    }

    func testNilRemainingSecondsDoesNotInventDigits() {
        for state in [StatusItemState.off, .armed, .agents] {
            let chrome = StatusItemChrome.make(state: state, remainingSeconds: nil)
            XCTAssertEqual(chrome.title, AgrypnosCopy.statusItemTitle(state))
            assertNoCountdownFiction(chrome.title)
            assertNoCountdownFiction(chrome.accessibilityTitle)
        }
    }

    func testChromeFollowsTheEngineAndIgnoresTimerEndDigits() {
        var prefs = UserPreferences.default
        prefs.duration = .oneHour
        var engine = WatchEngine(preferences: prefs)

        var chrome = StatusItemChrome.make(
            state: engine.statusItemState,
            remainingSeconds: engine.statusItemRemainingSeconds(now: t0)
        )
        XCTAssertEqual(chrome.title, "")
        XCTAssertEqual(chrome.length, .square)
        XCTAssertEqual(chrome.imagePosition, .imageOnly)

        _ = engine.userSetEngaged(true, now: t0)
        XCTAssertEqual(engine.timerEnd, t0.addingTimeInterval(3_600))
        XCTAssertNil(engine.statusItemRemainingSeconds(now: t0.addingTimeInterval(60)))
        chrome = StatusItemChrome.make(
            state: engine.statusItemState,
            remainingSeconds: 3_540
        )
        XCTAssertEqual(chrome.title, "Armed.")
        XCTAssertEqual(chrome.length, .variable)
        XCTAssertEqual(chrome.imagePosition, .imageLeading)
        assertNoCountdownFiction(chrome.title)

        _ = engine.userSetDuration(.untilAgentsSettle, now: t0)
        chrome = StatusItemChrome.make(
            state: engine.statusItemState,
            remainingSeconds: engine.statusItemRemainingSeconds(now: t0)
        )
        XCTAssertEqual(chrome.title, "Agents.")
        assertNoCountdownFiction(chrome.title)

        _ = engine.userSetEngaged(false, now: t0.addingTimeInterval(1))
        chrome = StatusItemChrome.make(
            state: engine.statusItemState,
            remainingSeconds: engine.statusItemRemainingSeconds(now: t0.addingTimeInterval(1))
        )
        XCTAssertEqual(chrome.title, "")
        XCTAssertEqual(chrome.length, .square)
        XCTAssertEqual(engine.preferences.duration, .untilAgentsSettle)
    }

    func testChromeCopyIsPlainAndNeverACountdown() {
        for chrome in [
            StatusItemChrome.make(state: .off, remainingSeconds: nil),
            StatusItemChrome.make(state: .armed, remainingSeconds: 125),
            StatusItemChrome.make(state: .agents, remainingSeconds: 0),
        ] {
            assertNoCountdownFiction(chrome.title)
            assertNoCountdownFiction(chrome.accessibilityTitle)
            XCTAssertFalse(chrome.title.lowercased().contains("watt"))
            XCTAssertFalse(chrome.accessibilityTitle.lowercased().contains("watt"))
            XCTAssertFalse(chrome.title.lowercased().contains("1.76"))
            XCTAssertFalse(chrome.title.contains("1h left"))
        }
    }

    private func assertNoCountdownFiction(
        _ text: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
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
