import XCTest
import AgrypnosCore
@testable import AgrypnosMac

@MainActor
final class RuntimeFixture {
    var lidClosed = true
    var kernelHeld = true
    var kernelWriteHook: ((Bool) -> Void)?
    var kernelUnknown = false
    var kernelWriteSucceeds = true
    var sleepRequests = 0
    var panelSleepRequests = 0
    var messages: [String] = []
    var postContinuation: CheckedContinuation<Void, Never>?
    var questionUptime: TimeInterval = 0
    var questionNotices: [String] = []
    var questionNoticeContinuation: CheckedContinuation<Void, Never>?
    var runtime: WatchRuntime!
    let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: "agrypnos-test-" + UUID().uuidString)!
        runtime = WatchRuntime(
            store: PreferencesStore(defaults: defaults),
            readLid: { [unowned self] in self.lidClosed },
            readKernel: { [unowned self] in self.kernelUnknown ? .unknown : (self.kernelHeld ? .held : .clear) },
            setKernel: { [unowned self] held in
                guard self.kernelWriteSucceeds else { return .failed("fixture failure") }
                self.kernelHeld = held; self.kernelWriteHook?(held); return .ok },
            runCommand: { [unowned self] _, args in
                if args == ["sleepnow"] { self.sleepRequests += 1 }
                if args == ["displaysleepnow"] { self.panelSleepRequests += 1 }
                return (0, "", "")
            },
            postIdle: { [unowned self] _ in
                await withCheckedContinuation { self.postContinuation = $0 }
            },
            notify: { [unowned self] in self.messages.append($0) },
            postQuestionNotice: { [unowned self] message in
                self.questionNotices.append(message)
                await withCheckedContinuation { self.questionNoticeContinuation = $0 }
            }
        )
        runtime.questionUptime = { [unowned self] in self.questionUptime }
        runtime.hygieneDevices = HygieneDevices(canSetBrightness: { true }, brightness: { nil },
            setBrightness: { _ in }, keyboard: { nil }, setKeyboard: { _ in }, wakeDisplay: {})
        runtime.engine.preferences.notifEnabled = true
        runtime.engine.preferences.keyboardBacklightOff = false
        runtime.engine.preferences.applyBrightnessFloor = false
    }

    func beginQuestionWatch() {
        runtime.engine.preferences.duration = .untilAgentsSettle
        let start = Date(timeIntervalSince1970: 0)
        _ = runtime.engine.userSetEngaged(true, now: start, lidClosed: false)
        _ = runtime.engine.observeLid(closed: true, now: start)
        _ = runtime.engine.observeLid(closed: true, now: start.addingTimeInterval(1))
    }

    func waitForQuestionNotice() async {
        for _ in 0..<100 where questionNoticeContinuation == nil { await Task.yield() }
        XCTAssertNotNil(questionNoticeContinuation)
    }

    func completeQuestionNotice() {
        questionNoticeContinuation?.resume()
        questionNoticeContinuation = nil
    }

    func beginClosedLidSettle() {
        runtime.engine.preferences.duration = .untilAgentsSettle
        let start = Date()
        _ = runtime.engine.userSetEngaged(true, now: start, lidClosed: false)
        _ = runtime.engine.observeLid(closed: true, now: start)
        _ = runtime.engine.observeLid(closed: true, now: start.addingTimeInterval(1))
        let busy = AgentSnapshot(reports: [AgentReport(kind: .cursor, processRunning: true, cpuBusy: false,
                                                    recentSessionWrite: true, isBusy: true)])
        let safe = SafetyInputs(batteryPercent: 90, onBatteryDischarging: false,
                                thermalSerious: false, lowPowerMode: false)
        runtime.finishPollTick(now: start, safety: safe, agents: busy, kernel: true, observeAgents: true)
        for seconds in stride(from: 5, through: 125, by: 5) {
            runtime.finishPollTick(now: start.addingTimeInterval(Double(seconds)), safety: safe,
                                   agents: AgentSnapshot(reports: []), kernel: true, observeAgents: true)
        }
        XCTAssertTrue(runtime.engine.holdingForIdlePost)
    }

    func waitForPost() async {
        for _ in 0..<100 where postContinuation == nil { await Task.yield() }
        XCTAssertNotNil(postContinuation)
    }

    func completePost() {
        postContinuation?.resume()
        postContinuation = nil
    }

    func waitForCompletion() async {
        for _ in 0..<100 { await Task.yield() }
    }
}
