import XCTest
@testable import AgrypnosCore

final class PanelPowerModeSwitchTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 10_000)

    func testSwitchAToBWhileArmedAndClosedSleepsDisplayNotFloor() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: true)
        XCTAssertEqual(engine.preferences.panelPowerMode, .floor)
        XCTAssertTrue(engine.lidCloseConfirmed)

        let commands = engine.userSetPanelPowerMode(.displaySleep)
        XCTAssertEqual(engine.preferences.panelPowerMode, .displaySleep)
        XCTAssertTrue(commands.contains(.requestDisplaySleep))
        XCTAssertFalse(commands.contains(.applyBrightnessFloor))
        XCTAssertFalse(commands.contains(.requestSleep))
        XCTAssertTrue(engine.engaged)
    }

    func testSwitchBToAWhileArmedAndClosedWakesThenFloors() {
        var prefs = UserPreferences.default
        prefs.panelPowerMode = .displaySleep
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: true)

        let commands = engine.userSetPanelPowerMode(.floor)
        XCTAssertEqual(engine.preferences.panelPowerMode, .floor)
        XCTAssertTrue(commands.contains(.wakeDisplay))
        XCTAssertTrue(commands.contains(.applyBrightnessFloor))
        XCTAssertFalse(commands.contains(.requestDisplaySleep))
        XCTAssertFalse(commands.contains(.requestSleep))
    }

    func testSwitchWhileLidOpenDoesNotApplyHygiene() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: false)
        let commands = engine.userSetPanelPowerMode(.displaySleep)
        XCTAssertEqual(engine.preferences.panelPowerMode, .displaySleep)
        XCTAssertTrue(commands.isEmpty)
        XCTAssertFalse(engine.lidHygieneApplied)
    }

    func testSwitchUnconfirmedCloseDoesNotApplyHygiene() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: false)
        XCTAssertTrue(engine.observeLid(closed: true, now: t0).isEmpty)
        XCTAssertFalse(engine.lidCloseConfirmed)
        XCTAssertTrue(engine.userSetPanelPowerMode(.displaySleep).isEmpty)
    }

    func testSwitchWhileDisengagedOnlyStoresTheMode() {
        var engine = WatchEngine(preferences: .default)
        XCTAssertTrue(engine.userSetPanelPowerMode(.displaySleep).isEmpty)
        XCTAssertEqual(engine.preferences.panelPowerMode, .displaySleep)
        XCTAssertTrue(engine.userSetPanelPowerMode(.displaySleep).isEmpty)
    }
}
