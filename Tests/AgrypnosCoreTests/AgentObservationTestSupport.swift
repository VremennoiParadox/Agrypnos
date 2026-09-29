import XCTest
@testable import AgrypnosCore

/// Model the regular idle polls between a busy signal and the assertion's deadline.
func observeHealthyIdle(_ engine: inout WatchEngine, before end: Date, file: StaticString = #filePath, line: UInt = #line) {
    guard let start = engine.settle.lastObservedAt else { return }
    let safety = SafetyInputs(batteryPercent: 90, onBatteryDischarging: false, thermalSerious: false, lowPowerMode: false)
    var next = start.addingTimeInterval(5)
    while next < end {
        XCTAssertTrue(engine.tick(now: next, safety: safety, agents: AgentSnapshot(reports: [])).isEmpty, file: file, line: line)
        next = next.addingTimeInterval(5)
    }
}
