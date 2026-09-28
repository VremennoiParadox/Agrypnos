import Foundation

/// A measurement's completion time is not the time its callback happened to arrive.
public struct AgentProbeObservation: Equatable, Sendable {
    public var snapshot: AgentSnapshot
    public var startedAt: Date
    public var completedAt: Date
    public var complete: Bool

    public init(snapshot: AgentSnapshot, startedAt: Date, completedAt: Date, complete: Bool) {
        self.snapshot = snapshot
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.complete = complete
    }

    /// Partial positive evidence protects the watch; an incomplete negative proves no idle.
    public func settleBusy(included: Set<AgentKind>, now: Date) -> Bool? {
        let duration = completedAt.timeIntervalSince(startedAt)
        let age = now.timeIntervalSince(completedAt)
        guard duration >= 0, duration <= AgentSettleTracker.maximumObservationGap,
              age >= 0, age < AgentSnapshotCache.reuseWindow else { return nil }
        if snapshot.anyBusy(included: included) { return true }
        return complete ? false : nil
    }
}
