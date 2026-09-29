import XCTest
import AgrypnosCore
@testable import AgrypnosMac

@MainActor
final class DeferredSleepTests: XCTestCase {
    func testManualOffRetiresPendingPostSleep() async {
        let fixture = RuntimeFixture()
        fixture.beginClosedLidSettle()
        await fixture.waitForPost()
        fixture.lidClosed = false
        fixture.runtime.setEngaged(false)
        fixture.completePost()
        await fixture.waitForCompletion()
        XCTAssertEqual(fixture.sleepRequests, 0)
        XCTAssertFalse(fixture.runtime.engaged)
    }

    func testLidOpenBeforePostCompletionDoesNotSleep() async {
        let fixture = RuntimeFixture()
        fixture.beginClosedLidSettle()
        await fixture.waitForPost()
        fixture.lidClosed = false
        fixture.completePost()
        await fixture.waitForCompletion()
        XCTAssertEqual(fixture.sleepRequests, 0)
        XCTAssertFalse(fixture.runtime.engaged)
    }

    func testClosedLidPostCompletionSleepsOnce() async {
        let fixture = RuntimeFixture()
        fixture.beginClosedLidSettle()
        await fixture.waitForPost()
        fixture.completePost()
        await fixture.waitForCompletion()
        XCTAssertEqual(fixture.sleepRequests, 1)
        XCTAssertFalse(fixture.runtime.engaged)
    }
}
