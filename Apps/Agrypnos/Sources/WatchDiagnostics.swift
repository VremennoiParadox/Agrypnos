import Foundation
import OSLog

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

/// Transition-only local diagnostics. Never pass paths, process arguments, tasks or secrets.
struct WatchDiagnostics {
    private static let logger = Logger(subsystem: "app.agrypnos.Agrypnos", category: "watch")
    private var lastProbeState: String?
    private var lastTickState: String?
    private var lastKernelState: Bool?

    static func event(_ message: String) {
        logger.debug("\(message, privacy: .public)")
    }

    mutating func probe(_ observation: AgentProbeObservation, busy: Bool?, included: Set<AgentKind>, now: Date) {
        let reports = observation.snapshot.reports.filter { included.contains($0.kind) }.map {
            "\($0.kind.rawValue):process=\($0.processRunning),write=\($0.recentSessionWrite),cpu=\($0.cpuBusy),busy=\($0.isBusy)"
        }.joined(separator: " ")
        let state = "complete=\(observation.complete) accepted=\(busy != nil) \(reports)"
        guard state != lastProbeState else { return }
        lastProbeState = state
        let duration = observation.completedAt.timeIntervalSince(observation.startedAt)
        let age = now.timeIntervalSince(observation.completedAt)
        Self.event("probe measured=\(observation.completedAt.timeIntervalSince1970) duration=\(duration) age=\(age) \(state)")
    }

    mutating func tick(engine: WatchEngine, settle: AgentSettleTracker, busy: Bool, now: Date, kernel: Bool, observed: Bool) {
        if lastKernelState != kernel {
            Self.event("kernel readback held=\(kernel)")
            lastKernelState = kernel
        }
        guard observed else { return }
        let activity = settle.activity(busy: busy, now: now)
        let state = "armed=\(engine.engaged) activity=\(activity) busySeen=\(settle.sawBusy) lidConfirmed=\(engine.lidCloseConfirmed)"
        guard state != lastTickState else { return }
        lastTickState = state
        let elapsed = settle.settleBaselineAt.map { now.timeIntervalSince($0) } ?? 0
        Self.event("settle \(state) elapsed=\(elapsed) grace=\(settle.grace)")
    }

    mutating func interrupt() {
        lastProbeState = nil
        lastTickState = nil
    }
}
