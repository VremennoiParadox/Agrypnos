import XCTest
@testable import AgrypnosCore

final class QuestionWatchTests: XCTestCase {
    private let safe = SafetyInputs(batteryPercent: 90, onBatteryDischarging: false, thermalSerious: false, lowPowerMode: false)
    private var busy: AgentSnapshot { AgentSnapshot(reports: [AgentReport(kind: .cursor, processRunning: true, cpuBusy: false, recentSessionWrite: true, isBusy: true)]) }
    private var idle: AgentSnapshot { AgentSnapshot(reports: []) }

    func testQuestionHoldSuppressesAgentsSettleWithoutLosingBusyHistory() {
        var preferences = UserPreferences.default
        preferences.duration = .untilAgentsSettle
        preferences.notifEnabled = true
        var engine = WatchEngine(preferences: preferences)
        _ = engine.userSetEngaged(true, now: Date(timeIntervalSince1970: 0))
        _ = engine.tick(now: Date(timeIntervalSince1970: 1), safety: safe, agents: busy)
        for second in stride(from: 5, through: 125, by: 5) {
            XCTAssertFalse(engine.tick(now: Date(timeIntervalSince1970: TimeInterval(second)), safety: safe, agents: idle,
                questionWait: QuestionWaitDecision(action: .hold, timeouts: [])).contains { if case .disengage = $0 { return true }; return false })
        }
        XCTAssertTrue(engine.engaged)
        XCTAssertTrue(engine.settle.sawBusy)
        XCTAssertNil(engine.settle.settleBaselineAt)
    }

    func testUnansweredEndUsesOwnReasonWithoutIdlePostOrChangingMode() {
        var preferences = UserPreferences.default
        preferences.duration = .untilAgentsSettle
        preferences.notifEnabled = true
        var engine = WatchEngine(preferences: preferences)
        _ = engine.userSetEngaged(true, now: Date(timeIntervalSince1970: 0))
        _ = engine.tick(now: Date(timeIntervalSince1970: 1), safety: safe, agents: busy)
        let commands = engine.tick(now: Date(timeIntervalSince1970: 600), safety: safe, agents: idle,
            questionWait: QuestionWaitDecision(action: .endUnanswered, timeouts: []))
        XCTAssertTrue(commands.contains(.disengage(.questionUnanswered)))
        XCTAssertFalse(commands.contains(.postIdleAfterWaitNotif))
        XCTAssertEqual(engine.preferences.duration, .untilAgentsSettle)
        XCTAssertEqual(engine.preferences.lastWatchEnd?.reason, .questionUnanswered)
    }

    func testSafetyWinsAndDeferredTimeoutKeepsKernelReassertion() {
        var engine = WatchEngine()
        _ = engine.userSetEngaged(true, now: Date(timeIntervalSince1970: 0))
        let decision = QuestionWaitDecision(action: .deferTimeout, timeouts: [])
        XCTAssertEqual(engine.tick(now: Date(timeIntervalSince1970: 600), safety: safe, agents: idle,
            kernelSleepDisabled: false, questionWait: decision), [.assertSleepDisabled])
        let hot = SafetyInputs(batteryPercent: 90, onBatteryDischarging: false, thermalSerious: true, lowPowerMode: false)
        XCTAssertTrue(engine.tick(now: Date(timeIntervalSince1970: 601), safety: hot, agents: idle,
            questionWait: QuestionWaitDecision(action: .endUnanswered, timeouts: [])).contains(.disengage(.thermal)))
    }

    func testExtraAgentProbeOnlyWhileQuestionDecisionNeedsIt() {
        XCTAssertEqual(WatchTickProbe.needed(engaged: true, mode: .indefinite, questionTimeoutPending: false), .safety)
        XCTAssertEqual(WatchTickProbe.needed(engaged: true, mode: .indefinite, questionTimeoutPending: true), .safetyAndAgents)
        XCTAssertEqual(WatchTickProbe.needed(engaged: false, mode: .idle, questionTimeoutPending: true), .none)
    }
}
