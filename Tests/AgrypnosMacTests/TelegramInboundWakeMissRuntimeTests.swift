import XCTest
import AgrypnosCore
@testable import AgrypnosMac

@MainActor
final class TelegramInboundWakeMissRuntimeTests: XCTestCase {
    private func fixture() -> RuntimeFixture {
        let fixture = RuntimeFixture()
        fixture.notifSecrets = NotifSecrets(
            telegramBotToken: "123:token",
            telegramChatId: "99"
        )
        fixture.runtime.inboundPoller.runtime = fixture.runtime
        fixture.runtime.engine.preferences.telegramInboundEnabled = true
        return fixture
    }

    func testLiveFinishStillArms() {
        let fixture = fixture()
        fixture.runtime.store.saveTelegramInboundCursor(TelegramInboundCursor(offset: 40, seeded: true))
        XCTAssertFalse(fixture.runtime.engine.engaged)

        fixture.runtime.finishTelegramInboundPoll(
            generation: 0,
            fetchedToken: "123:token",
            cursor: TelegramInboundCursor(offset: 40, seeded: true),
            updates: [TelegramInboundUpdate(updateId: 41, chatId: "99", text: "/arm")]
        )

        XCTAssertTrue(fixture.runtime.engine.engaged)
        let saved = fixture.runtime.store.loadTelegramInboundCursor()
        XCTAssertTrue(saved.seeded)
        XCTAssertFalse(saved.wakeMiss)
        XCTAssertEqual(saved.offset, 42)
        XCTAssertEqual(saved.drain, .live)
    }

    func testWillSleepBumpsGenerationSoInFlightFinishDoesNotSeedOrEngage() {
        let fixture = fixture()
        fixture.runtime.store.saveTelegramInboundCursor(TelegramInboundCursor(offset: 40, seeded: true))
        _ = fixture.runtime.engine.userSetEngaged(true, now: Date(), lidClosed: false)
        XCTAssertTrue(fixture.runtime.engine.engaged)
        XCTAssertTrue(fixture.runtime.inboundPoller.accepts(generation: 0))

        fixture.runtime.noteMacWillSleep()
        fixture.runtime.finishTelegramInboundPoll(
            generation: 0,
            fetchedToken: "123:token",
            cursor: TelegramInboundCursor(offset: 40, seeded: true),
            updates: [TelegramInboundUpdate(updateId: 41, chatId: "99", text: "/disarm")]
        )

        XCTAssertFalse(fixture.runtime.inboundPoller.accepts(generation: 0))
        XCTAssertTrue(fixture.runtime.engine.engaged)
        XCTAssertEqual(fixture.sleepRequests, 0)
        let saved = fixture.runtime.store.loadTelegramInboundCursor()
        XCTAssertFalse(saved.seeded)
        XCTAssertTrue(saved.wakeMiss)
        XCTAssertEqual(saved.offset, 40)
    }

    func testSleepHoldDoesNotStartLeftoverDrain() {
        let fixture = fixture()
        fixture.runtime.store.saveTelegramInboundCursor(TelegramInboundCursor(offset: 40, seeded: true))
        fixture.runtime.noteMacWillSleep()
        defer { fixture.runtime.inboundPoller.stop() }

        fixture.runtime.inboundPoller.sync()

        let saved = fixture.runtime.store.loadTelegramInboundCursor()
        XCTAssertFalse(saved.seeded)
        XCTAssertTrue(saved.wakeMiss)
        XCTAssertEqual(saved.offset, 40)
        XCTAssertEqual(saved.drain, .wakeMiss)
    }

    func testStoredWakeMissFinishDoesNotSaveFetchedLiveAckOrArm() {
        let fixture = fixture()
        fixture.runtime.store.saveTelegramInboundCursor(
            TelegramInboundCursor(offset: 40, seeded: false, wakeMiss: true)
        )

        fixture.runtime.finishTelegramInboundPoll(
            generation: 0,
            fetchedToken: "123:token",
            cursor: TelegramInboundCursor(offset: 40, seeded: true),
            updates: [TelegramInboundUpdate(updateId: 41, chatId: "99", text: "/arm")]
        )

        XCTAssertFalse(fixture.runtime.engine.engaged)
        let saved = fixture.runtime.store.loadTelegramInboundCursor()
        XCTAssertFalse(saved.seeded)
        XCTAssertTrue(saved.wakeMiss)
        XCTAssertEqual(saved.offset, 42)
        XCTAssertEqual(saved.drain, .wakeMiss)
    }

    func testPostWakeDrainPromotesWithoutApplying() {
        let fixture = fixture()
        fixture.runtime.store.saveTelegramInboundCursor(
            TelegramInboundCursor(offset: 40, seeded: false, wakeMiss: true)
        )
        fixture.runtime.inboundPoller.armPostWakePromotion()

        fixture.runtime.finishTelegramInboundPoll(
            generation: 0,
            fetchedToken: "123:token",
            cursor: TelegramInboundCursor(offset: 40, seeded: false, wakeMiss: true),
            updates: [TelegramInboundUpdate(updateId: 41, chatId: "99", text: "/arm")]
        )

        XCTAssertFalse(fixture.runtime.engine.engaged)
        let saved = fixture.runtime.store.loadTelegramInboundCursor()
        XCTAssertTrue(saved.seeded)
        XCTAssertFalse(saved.wakeMiss)
        XCTAssertEqual(saved.offset, 42)
        XCTAssertEqual(saved.drain, .live)
    }
}
