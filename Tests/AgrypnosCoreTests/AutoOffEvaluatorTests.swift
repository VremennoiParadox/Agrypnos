import XCTest
@testable import AgrypnosCore

final class AutoOffEvaluatorTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 5_000)

    func testTimerExpiry() {
        let reason = AutoOffEvaluator.reason(
            engaged: true,
            timerEnd: now.addingTimeInterval(-1),
            safety: SafetyInputs(batteryPercent: 80, onBatteryDischarging: false, thermalSerious: false, lowPowerMode: false),
            batteryFloorPercent: 15,
            userForcedThisSession: true,
            now: now
        )
        XCTAssertEqual(reason, .timerExpired)
    }

    func testBatteryFloorOnlyWhileDischarging() {
        let discharging = AutoOffEvaluator.reason(
            engaged: true,
            timerEnd: nil,
            safety: SafetyInputs(batteryPercent: 10, onBatteryDischarging: true, thermalSerious: false, lowPowerMode: false),
            batteryFloorPercent: 15,
            userForcedThisSession: true
        )
        XCTAssertEqual(discharging, .batteryFloor)

        let onAC = AutoOffEvaluator.reason(
            engaged: true,
            timerEnd: nil,
            safety: SafetyInputs(batteryPercent: 10, onBatteryDischarging: false, thermalSerious: false, lowPowerMode: false),
            batteryFloorPercent: 15,
            userForcedThisSession: true
        )
        XCTAssertNil(onAC)
    }

    func testThermalAlwaysWins() {
        let reason = AutoOffEvaluator.reason(
            engaged: true,
            timerEnd: nil,
            safety: SafetyInputs(batteryPercent: 90, onBatteryDischarging: false, thermalSerious: true, lowPowerMode: false),
            batteryFloorPercent: 15,
            userForcedThisSession: true
        )
        XCTAssertEqual(reason, .thermal)
    }

    func testLowPowerModeHonorsUserForceExceptBatteryFloor() {
        let lpm = AutoOffEvaluator.reason(
            engaged: true,
            timerEnd: nil,
            safety: SafetyInputs(batteryPercent: 50, onBatteryDischarging: true, thermalSerious: false, lowPowerMode: true),
            batteryFloorPercent: 15,
            userForcedThisSession: false
        )
        XCTAssertEqual(lpm, .lowPowerMode)

        let forced = AutoOffEvaluator.reason(
            engaged: true,
            timerEnd: nil,
            safety: SafetyInputs(batteryPercent: 50, onBatteryDischarging: true, thermalSerious: false, lowPowerMode: true),
            batteryFloorPercent: 15,
            userForcedThisSession: true
        )
        XCTAssertNil(forced)
    }

    func testIdleEngineNeverAutoOffs() {
        XCTAssertNil(
            AutoOffEvaluator.reason(
                engaged: false,
                timerEnd: now,
                safety: SafetyInputs(batteryPercent: 1, onBatteryDischarging: true, thermalSerious: true, lowPowerMode: true),
                batteryFloorPercent: 15,
                userForcedThisSession: false
            )
        )
    }
}
