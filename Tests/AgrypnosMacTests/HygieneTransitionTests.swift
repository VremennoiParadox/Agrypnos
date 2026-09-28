import XCTest
import AgrypnosCore
@testable import AgrypnosMac

@MainActor
final class HygieneTransitionTests: XCTestCase {
    func testSwitchToBRestoresAppliedFloorBeforeSleepingPanel() {
        let f = RuntimeFixture()
        var writes: [Double] = []
        var restoredBeforePanelSleep = false
        f.runtime.hygieneDevices = HygieneDevices(canSetBrightness: { true }, brightness: { 0.8 },
            setBrightness: { writes.append($0) }, keyboard: { 0.6 }, setKeyboard: { _ in }, wakeDisplay: {})
        f.runtime.engine.preferences.applyBrightnessFloor = true
        f.runtime.savedBrightness = 0.8
        _ = f.runtime.engine.userSetEngaged(true, now: Date(), lidClosed: true)
        f.runtime.apply([.applyBrightnessFloor])
        XCTAssertEqual(writes, [0.15])
        f.runtime.setPanelPowerMode(.displaySleep)
        restoredBeforePanelSleep = writes == [0.15, 0.8] && f.panelSleepRequests == 1
        XCTAssertTrue(restoredBeforePanelSleep)
        XCTAssertEqual(f.runtime.preferences.panelPowerMode, .displaySleep)
        XCTAssertTrue(f.runtime.engaged)
    }

    func testDisablingAppliedHygieneRestoresCapturedValues() {
        let f = RuntimeFixture()
        var brightness: [Double] = []
        var keyboard: [Double] = []
        f.runtime.hygieneDevices = HygieneDevices(canSetBrightness: { true }, brightness: { 0.8 },
            setBrightness: { brightness.append($0) }, keyboard: { 0.6 }, setKeyboard: { keyboard.append($0) }, wakeDisplay: {})
        f.runtime.engine.preferences.applyBrightnessFloor = true
        f.runtime.engine.preferences.keyboardBacklightOff = true
        f.runtime.savedBrightness = 0.8
        f.runtime.savedKeyboard = 0.6
        _ = f.runtime.engine.userSetEngaged(true, now: Date(), lidClosed: true)
        f.runtime.apply([.applyBrightnessFloor, .requestKeyboardBacklightOff])
        f.runtime.setHygiene(keyboard: false, floor: false)
        XCTAssertEqual(brightness, [0.15, 0.8])
        XCTAssertEqual(keyboard, [0, 0.6])
        f.runtime.setEngaged(false)
        XCTAssertEqual(brightness, [0.15, 0.8])
        XCTAssertEqual(keyboard, [0, 0.6])
    }

    func testCapturedButUnappliedValuesAreNotRestored() {
        let f = RuntimeFixture()
        var brightness: [Double] = []
        var keyboard: [Double] = []
        f.runtime.hygieneDevices = HygieneDevices(canSetBrightness: { true }, brightness: { 0.8 },
            setBrightness: { brightness.append($0) }, keyboard: { 0.6 }, setKeyboard: { keyboard.append($0) }, wakeDisplay: {})
        f.runtime.savedBrightness = 0.8
        f.runtime.savedKeyboard = 0.6
        f.runtime.engine.preferences.applyBrightnessFloor = true
        f.runtime.engine.preferences.keyboardBacklightOff = true
        f.runtime.restoreHygiene()
        XCTAssertTrue(brightness.isEmpty)
        XCTAssertTrue(keyboard.isEmpty)
    }

    func testNilCaptureNeverWritesGuessedRestore() {
        let f = RuntimeFixture()
        var brightness: [Double] = []
        f.runtime.hygieneDevices = HygieneDevices(canSetBrightness: { true }, brightness: { nil },
            setBrightness: { brightness.append($0) }, keyboard: { nil }, setKeyboard: { _ in }, wakeDisplay: {})
        f.runtime.engine.preferences.applyBrightnessFloor = true
        _ = f.runtime.engine.userSetEngaged(true, now: Date(), lidClosed: true)
        f.runtime.apply([.applyBrightnessFloor])
        f.runtime.setPanelPowerMode(.displaySleep)
        XCTAssertEqual(brightness, [0.15])
    }
}
