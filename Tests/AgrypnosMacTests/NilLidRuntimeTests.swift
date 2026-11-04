import XCTest
import AgrypnosCore
@testable import AgrypnosMac

@MainActor
final class NilLidRuntimeTests: XCTestCase {
    func testNilLidPollKeepsConfirmedCloseAndSkipsBrightnessWrite() {
        let f = RuntimeFixture()
        var writes: [Double] = []
        f.runtime.hygieneDevices = HygieneDevices(
            canSetBrightness: { true },
            brightness: { 0.8 },
            setBrightness: { writes.append($0) },
            keyboard: { nil },
            setKeyboard: { _ in },
            wakeDisplay: {}
        )
        f.runtime.engine.preferences.applyBrightnessFloor = true
        f.runtime.savedBrightness = 0.8
        f.runtime.hygieneEffects.floor = true
        confirmClosed(f)
        writes.removeAll()
        f.lidUnknown = true
        f.runtime.pollLid()
        XCTAssertTrue(f.runtime.engine.lidCloseConfirmed)
        XCTAssertTrue(writes.isEmpty)
    }

    func testNilLidBatteryDisengageStillRequestsSleep() {
        let f = RuntimeFixture()
        f.runtime.engine.preferences.notifEnabled = false
        confirmClosed(f)
        f.lidUnknown = true
        finishBattery(f)
        XCTAssertFalse(f.runtime.engaged)
        XCTAssertEqual(f.sleepRequests, 1)
    }

    func testOpenLidBatteryDisengageDoesNotRequestSleep() {
        let f = RuntimeFixture()
        f.runtime.engine.preferences.notifEnabled = false
        confirmClosed(f)
        f.lidClosed = false
        finishBattery(f)
        XCTAssertFalse(f.runtime.engaged)
        XCTAssertEqual(f.sleepRequests, 0)
    }

    func testNilLidUserOffDoesNotRequestSleep() {
        let f = RuntimeFixture()
        f.runtime.engine.preferences.notifEnabled = false
        confirmClosed(f)
        f.lidUnknown = true
        _ = f.runtime.setEngaged(false)
        XCTAssertFalse(f.runtime.engaged)
        XCTAssertEqual(f.sleepRequests, 0)
    }

    func testUnknownLidAtTimerExpiryStillRequestsSleep() {
        let f = RuntimeFixture()
        f.runtime.engine.preferences.notifEnabled = false
        f.runtime.engine.preferences.duration = .customMinutes(1)
        let start = Date()
        _ = f.runtime.engine.userSetEngaged(true, now: start)
        f.lidUnknown = true
        f.runtime.finishPollTick(
            now: start.addingTimeInterval(60),
            safety: SafetyInputs(batteryPercent: 90, onBatteryDischarging: false,
                                  thermalSerious: false, lowPowerMode: false),
            agents: AgentSnapshot(reports: []),
            kernel: true,
            observeAgents: false
        )
        XCTAssertFalse(f.runtime.engaged)
        XCTAssertEqual(f.sleepRequests, 1)
    }

    private func confirmClosed(_ f: RuntimeFixture) {
        let start = Date()
        _ = f.runtime.engine.userSetEngaged(true, now: start, lidClosed: false)
        _ = f.runtime.engine.observeLid(closed: true, now: start)
        _ = f.runtime.engine.observeLid(
            closed: true,
            now: start.addingTimeInterval(LidCloseConfirm.pulseInterval)
        )
        XCTAssertTrue(f.runtime.engine.lidCloseConfirmed)
    }

    private func finishBattery(_ f: RuntimeFixture) {
        f.runtime.finishPollTick(
            now: Date().addingTimeInterval(2),
            safety: SafetyInputs(batteryPercent: 10, onBatteryDischarging: true,
                                  thermalSerious: false, lowPowerMode: false),
            agents: AgentSnapshot(reports: []),
            kernel: true,
            observeAgents: false
        )
    }
}
