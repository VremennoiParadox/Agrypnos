import XCTest
@testable import AgrypnosCore

final class DiscordDeferredSlashTests: XCTestCase {
    func testStaleDeferredSlashDoesNotApplyAfterGenerationBump() {
        XCTAssertTrue(DiscordDeferredSlash.shouldApply(current: 3, captured: 3))
        XCTAssertFalse(DiscordDeferredSlash.shouldApply(current: 4, captured: 3))
        XCTAssertFalse(DiscordDeferredSlash.shouldApply(current: 1, captured: 0))
        XCTAssertTrue(
            DiscordDeferredSlash.shouldApply(current: 4, captured: 4)
                == TelegramInboundGeneration.allowsApply(current: 4, captured: 4)
        )
        XCTAssertTrue(DiscordDeferredSlash.shouldReplyMissedWhileAsleep(current: 4, captured: 3))
        XCTAssertFalse(DiscordDeferredSlash.shouldReplyMissedWhileAsleep(current: 3, captured: 3))
    }

    func testArmAndDisarmUseTheSameGenerationGate() {
        XCTAssertFalse(
            DiscordDeferredSlash.shouldApply(intent: .arm, current: 2, captured: 1)
        )
        XCTAssertFalse(
            DiscordDeferredSlash.shouldApply(intent: .disarm, current: 9, captured: 8)
        )
        XCTAssertTrue(
            DiscordDeferredSlash.shouldApply(intent: .arm, current: 2, captured: 2)
        )
        XCTAssertTrue(
            DiscordDeferredSlash.shouldApply(intent: .status, current: 2, captured: 2)
        )
    }
}
