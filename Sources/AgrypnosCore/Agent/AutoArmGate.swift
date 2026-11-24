import Foundation

/// Auto-on busy count while Keep awake is off. Local busy signals only — not think-detection.
public struct AutoArmGate: Equatable, Sendable {
    public static let busySeconds: TimeInterval = 30
    public private(set) var busySince: Date?
    public private(set) var lastObservedAt: Date?
    /// One session write stays fresh longer than `busySeconds`, so arm only on current evidence:
    /// CPU busy at the arming check, or a newer write than the one that started the count.
    public private(set) var firstWrite: Date?
    /// A watch ended. Arm again only after busy signals go quiet: the next run, not this one.
    public private(set) var waitingForQuiet = false

    public init() {}

    public mutating func watchEnded() {
        waitingForQuiet = true
        restartCount()
    }

    public mutating func restartCount() {
        busySince = nil
        lastObservedAt = nil
    }

    /// True once busy has held for `busySeconds` of continuous checks and still has current evidence.
    /// Nil (incomplete probe) restarts.
    public mutating func observe(busy: Bool?, cpu: Bool, newestWrite: Date?, now: Date) -> Bool {
        let gap = lastObservedAt.map { now.timeIntervalSince($0) }
        lastObservedAt = now
        guard busy == true else {
            busySince = nil
            if busy == false { waitingForQuiet = false }
            return false
        }
        guard !waitingForQuiet else { return false }
        if let gap, gap >= 0, gap <= AgentSettleTracker.maximumObservationGap, let start = busySince {
            let current = cpu || (newestWrite ?? .distantPast) > (firstWrite ?? .distantPast)
            return current && now.timeIntervalSince(start) >= Self.busySeconds
        }
        busySince = now
        firstWrite = newestWrite
        return false
    }
}
