import XCTest
@testable import AgrypnosCore

final class WatchCountdownCopyTests: XCTestCase {
    func testCountdownFormatsHoursMinutesSecondsAndClampsZero() {
        XCTAssertEqual(AgrypnosCopy.countdown(seconds: 3600), "1:00:00")
        XCTAssertEqual(AgrypnosCopy.countdown(seconds: 10800), "3:00:00")
        XCTAssertEqual(AgrypnosCopy.countdown(seconds: 125), "0:02:05")
        XCTAssertEqual(AgrypnosCopy.countdown(seconds: -1), "0:00:00")
    }

    func testTimedCardShowsSelectionBeforeArmAndRealTimeWhileArmed() {
        XCTAssertEqual(AgrypnosCopy.durationCountdown(option: .oneHour, engaged: false, remainingSeconds: nil), "Timer 1:00:00")
        XCTAssertEqual(AgrypnosCopy.durationCountdown(option: .customMinutes(33), engaged: false, remainingSeconds: nil), "Timer 0:33:00")
        XCTAssertEqual(AgrypnosCopy.durationCountdown(option: .oneHour, engaged: true, remainingSeconds: 125), "Time left 0:02:05")
        XCTAssertNil(AgrypnosCopy.durationCountdown(option: .indefinite, engaged: true, remainingSeconds: 125))
        XCTAssertNil(AgrypnosCopy.durationCountdown(option: .untilAgentsSettle, engaged: true, remainingSeconds: 125))
    }

    func testStatusUsesLiveDeadlineAndDropsRemainingTimeAfterDisarm() {
        let now = Date(timeIntervalSince1970: 10000)
        var engine = WatchEngine(preferences: UserPreferences(duration: .threeHours))
        _ = engine.userSetEngaged(true, now: now)
        let text = TelegramWatchStatusCopy.reply(engine.telegramWatchStatus(now: now.addingTimeInterval(60)), now: now.addingTimeInterval(60))
        XCTAssertTrue(text.contains("Time left 2:59:00."))
        XCTAssertFalse(text.contains("Selected tools:"))
        _ = engine.userSetEngaged(false, now: now.addingTimeInterval(61))
        let off = TelegramWatchStatusCopy.reply(engine.telegramWatchStatus(now: now.addingTimeInterval(62)), now: now.addingTimeInterval(62))
        XCTAssertFalse(off.contains("Time left"))
    }

    func testLargeCustomMinutesDoNotOverflowCountdownRendering() {
        XCTAssertEqual(AgrypnosCopy.durationCountdown(option: .customMinutes(Int.max), engaged: false, remainingSeconds: nil),
                       "Timer 153722867280912930:07:00")
        XCTAssertEqual(AgrypnosCopy.countdown(seconds: Int.max), "2562047788015215:30:07")
        let now = Date(timeIntervalSince1970: 10000)
        var engine = WatchEngine(preferences: UserPreferences(duration: .customMinutes(Int.max)))
        _ = engine.userSetEngaged(true, now: now)
        XCTAssertEqual(engine.statusItemRemainingSeconds(now: now), Int.max)
    }
}
