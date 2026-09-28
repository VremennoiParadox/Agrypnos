import Foundation

public struct AgentSettleTracker: Equatable, Sendable {
    public enum Activity: Equatable, Sendable {
        case quiet
        case busy
        case settling
        case settled
    }

    /// Three normal poll intervals. Missing measurements are not observed idle.
    public static let maximumObservationGap: TimeInterval = 15
    public var grace: TimeInterval
    public private(set) var lastBusyAt: Date?
    public private(set) var sawBusy: Bool
    public private(set) var lastObservedAt: Date?
    public private(set) var settleBaselineAt: Date?

    public init(grace: TimeInterval = UserPreferences.defaultAgentSettleGrace) {
        self.grace = grace
        self.lastBusyAt = nil
        self.sawBusy = false
        self.lastObservedAt = nil
        self.settleBaselineAt = nil
    }

    public mutating func reset() {
        lastBusyAt = nil
        sawBusy = false
        interruptObservations()
    }

    /// Keep busy facts from this arm; require a new quiet wait after observations resume.
    public mutating func interruptObservations() {
        lastObservedAt = nil
        settleBaselineAt = nil
    }

    /// Status and other readers. Does not record busy or extend observation continuity.
    public func activity(busy: Bool, now: Date) -> Activity {
        if busy { return .busy }
        guard sawBusy else { return .quiet }
        guard observationIsContinuous(at: now), let baseline = settleBaselineAt else { return .settling }
        return now.timeIntervalSince(baseline) >= grace ? .settled : .settling
    }

    public mutating func observe(busy: Bool, now: Date) -> Activity {
        if busy {
            lastBusyAt = now
            sawBusy = true
            settleBaselineAt = now
        } else if !observationIsContinuous(at: now) {
            settleBaselineAt = now
        }
        lastObservedAt = now
        return activity(busy: busy, now: now)
    }

    private func observationIsContinuous(at now: Date) -> Bool {
        guard let lastObservedAt else { return false }
        let gap = now.timeIntervalSince(lastObservedAt)
        return gap >= 0 && gap <= Self.maximumObservationGap
    }
}
