import Foundation

/// Reuse the last Agents probe for `/status` and a late tick. One poll window.
public struct AgentSnapshotCache: Equatable, Sendable {
    public static let reuseWindow: TimeInterval = 5

    public var snapshot: AgentSnapshot?
    public var capturedAt: Date?
    public var included: Set<AgentKind>?

    public init() {
        snapshot = nil
        capturedAt = nil
        included = nil
    }

    public mutating func store(
        _ snapshot: AgentSnapshot,
        included: Set<AgentKind>,
        at now: Date
    ) {
        self.snapshot = snapshot
        self.included = included
        capturedAt = now
    }

    public func reusable(at now: Date, included: Set<AgentKind>) -> AgentSnapshot? {
        guard let snapshot, let capturedAt, let stored = self.included else { return nil }
        guard stored == included else { return nil }
        guard now.timeIntervalSince(capturedAt) < Self.reuseWindow else { return nil }
        return snapshot
    }

    public mutating func invalidate() {
        snapshot = nil
        capturedAt = nil
        included = nil
    }
}
