import Foundation

public struct AgentSettleTracker: Equatable, Sendable {
    public enum Activity: Equatable, Sendable {
        case quiet
        case busy
        case settling
        case settled
    }

    public var grace: TimeInterval
    public private(set) var lastBusyAt: Date?
    public private(set) var sawBusy: Bool

    public init(grace: TimeInterval = 90) {
        self.grace = grace
        self.lastBusyAt = nil
        self.sawBusy = false
    }

    public mutating func reset() {
        lastBusyAt = nil
        sawBusy = false
    }

    public mutating func observe(busy: Bool, now: Date) -> Activity {
        if busy {
            lastBusyAt = now
            sawBusy = true
            return .busy
        }
        guard sawBusy, let last = lastBusyAt else { return .quiet }
        if now.timeIntervalSince(last) >= grace { return .settled }
        return .settling
    }
}
