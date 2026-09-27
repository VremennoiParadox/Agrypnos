import XCTest
@testable import AgrypnosCore

final class WatchDisarmRollbackTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 10_000)

    func testRollbackUsesLidFromDisengageNotTheZeroedEngineFlag() {
        var prefs = UserPreferences.default
        prefs.applyBrightnessFloor = true
        prefs.keyboardBacklightOff = true
        prefs.panelPowerMode = .floor
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: true)
        XCTAssertTrue(engine.lidCloseConfirmed)

        let commands = engine.userSetEngaged(false, now: t0.addingTimeInterval(1), lidClosed: true)
        XCTAssertTrue(commands.contains(.requestSleep))
        XCTAssertFalse(engine.lidClosed)
        XCTAssertFalse(engine.lidCloseConfirmed)

        // Runtime used to pass engine.lidClosed after reset (false). Rollback must ignore that.
        let rollback = engine.rollbackDisarmFailure(now: t0.addingTimeInterval(2), lidClosed: false)
        XCTAssertTrue(engine.engaged)
        XCTAssertTrue(engine.lidCloseConfirmed)
        XCTAssertTrue(rollback.contains(.engage))
        XCTAssertTrue(rollback.contains(.applyBrightnessFloor))
        XCTAssertTrue(rollback.contains(.requestKeyboardBacklightOff))
        XCTAssertTrue(rollback.contains(.assertSleepDisabled))
    }

    func testRollbackWithOpenLidDoesNotReissueClosedHygiene() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: false)
        _ = engine.userSetEngaged(false, now: t0.addingTimeInterval(1), lidClosed: false)
        let rollback = engine.rollbackDisarmFailure(now: t0.addingTimeInterval(2), lidClosed: false)
        XCTAssertTrue(engine.engaged)
        XCTAssertFalse(engine.lidCloseConfirmed)
        XCTAssertFalse(rollback.contains(.applyBrightnessFloor))
        XCTAssertFalse(rollback.contains(.requestDisplaySleep))
    }
}
