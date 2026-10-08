import XCTest
@testable import AgrypnosCore

final class DiscordBotOutboundTests: XCTestCase {
    func testTimerAndIdleKeepTheirSentence() {
        XCTAssertEqual(
            DiscordBotOutbound.body(reason: .timerExpired, willSleep: false),
            "Agrypnos: your watch timer ended."
        )
        XCTAssertEqual(
            DiscordBotOutbound.body(reason: .agentsSettled, willSleep: false),
            AgrypnosCopy.notifIdleBody
        )
    }

    func testSleepAppendsOneClauseToTheWatchEndSentence() {
        XCTAssertEqual(
            DiscordBotOutbound.body(reason: .timerExpired, willSleep: true),
            "Agrypnos: your watch timer ended. Asking the Mac to sleep."
        )
        XCTAssertEqual(
            DiscordBotOutbound.body(reason: .agentsSettled, willSleep: true),
            AgrypnosCopy.notifIdleBody + " Asking the Mac to sleep."
        )
    }

    func testSleepOnlyReasonsMessageOnlyWhenTheMacWillSleep() {
        XCTAssertEqual(
            DiscordBotOutbound.body(reason: .user, willSleep: true),
            "Agrypnos: Keep the watch is off. Asking the Mac to sleep."
        )
        XCTAssertEqual(
            DiscordBotOutbound.body(reason: .batteryFloor, willSleep: true),
            "Agrypnos: battery auto-off. Asking the Mac to sleep."
        )
        XCTAssertEqual(
            DiscordBotOutbound.body(reason: .thermal, willSleep: true),
            "Agrypnos: thermal pressure turned the watch off. Asking the Mac to sleep."
        )
        XCTAssertEqual(
            DiscordBotOutbound.body(reason: .lowPowerMode, willSleep: true),
            "Agrypnos: Low Power Mode turned the watch off. Asking the Mac to sleep."
        )
        XCTAssertEqual(
            DiscordBotOutbound.body(reason: nil, willSleep: true),
            "Agrypnos: asking the Mac to sleep."
        )
        for reason in [DisengageReason.user, .batteryFloor, .thermal, .lowPowerMode] {
            XCTAssertNil(DiscordBotOutbound.body(reason: reason, willSleep: false))
        }
        XCTAssertNil(DiscordBotOutbound.body(reason: nil, willSleep: false))
    }

    func testQuestionAndWakeHoldFailureDoNotGetASecondSentence() {
        XCTAssertNil(DiscordBotOutbound.body(reason: .questionUnanswered, willSleep: true))
        XCTAssertNil(DiscordBotOutbound.body(reason: .questionUnanswered, willSleep: false))
        XCTAssertNil(DiscordBotOutbound.body(reason: .wakeHoldFailed, willSleep: true))
        XCTAssertNil(DiscordBotOutbound.body(reason: .wakeHoldFailed, willSleep: false))
    }

    func testBodiesDoNotClaimTheMacSlept() {
        let reasons: [DisengageReason?] = [
            .timerExpired, .agentsSettled, .user, .batteryFloor, .thermal, .lowPowerMode, nil
        ]
        for reason in reasons {
            for willSleep in [false, true] {
                let body = DiscordBotOutbound.body(reason: reason, willSleep: willSleep) ?? ""
                XCTAssertFalse(body.lowercased().contains("mac is asleep"))
                XCTAssertFalse(body.lowercased().contains("agent stopped"))
                XCTAssertFalse(body.lowercased().contains("job finished"))
            }
        }
    }
}
