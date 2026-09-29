import Foundation

public enum QuestionTimeoutReason: Equatable, Sendable {
    case idle, busy, unknown, anotherQuestion
}

public struct QuestionTimeoutReport: Equatable, Sendable {
    public let key: QuestionKey
    public let reason: QuestionTimeoutReason
}

public struct QuestionWaitDecision: Equatable, Sendable {
    public enum Action: Equatable, Sendable {
        case normal, hold, deferTimeout, endUnanswered
    }
    public let action: Action
    public let timeouts: [QuestionTimeoutReport]
    public static let normal = QuestionWaitDecision(action: .normal, timeouts: [])
}

public struct QuestionWaitPolicy: Sendable {
    private var expired: Set<QuestionKey> = []
    private var reported: Set<QuestionKey> = []
    private var deferred = false
    private var quietSince: TimeInterval?
    private var lastQuietObservation: TimeInterval?

    public init() {}

    public mutating func reset() {
        expired.removeAll()
        reported.removeAll()
        resetQuiet()
        deferred = false
    }

    public mutating func observe(pendingDeadlines: [QuestionKey: TimeInterval],
                                 newlyExpired: Set<QuestionKey>, cleared: Set<QuestionKey>,
                                 now: TimeInterval, busy: Bool?, grace: TimeInterval) -> QuestionWaitDecision {
        guard now.isFinite, now >= 0 else {
            resetQuiet()
            return QuestionWaitDecision(action: expired.isEmpty ? .normal : .deferTimeout, timeouts: [])
        }
        let due = Set(pendingDeadlines.filter { $0.value <= now }.map(\.key))
        expired.formUnion(newlyExpired.union(due))
        expired.subtract(cleared)
        reported.subtract(cleared)
        let hasPending = pendingDeadlines.contains { $0.value > now && !cleared.contains($0.key) && !expired.contains($0.key) }
        let reason: QuestionTimeoutReason = hasPending ? .anotherQuestion : busy == true ? .busy : busy == nil ? .unknown : .idle
        let reports = expired.subtracting(reported).map { QuestionTimeoutReport(key: $0, reason: reason) }
        reported.formUnion(expired)
        if expired.isEmpty {
            deferred = false
            resetQuiet()
            return QuestionWaitDecision(action: hasPending ? .hold : .normal, timeouts: reports)
        }
        if hasPending {
            resetQuiet()
            return QuestionWaitDecision(action: .hold, timeouts: reports)
        }
        guard busy == false else {
            deferred = true
            resetQuiet()
            return QuestionWaitDecision(action: .deferTimeout, timeouts: reports)
        }
        guard deferred else { return QuestionWaitDecision(action: .endUnanswered, timeouts: reports) }
        if let last = lastQuietObservation, now - last >= 0,
           now - last <= AgentSettleTracker.maximumObservationGap {
            // Continue the observed quiet interval.
        } else { quietSince = now }
        lastQuietObservation = now
        let wait = grace.isFinite ? min(900, max(120, grace)) : 120
        let settled = now - (quietSince ?? now) >= wait
        return QuestionWaitDecision(action: settled ? .endUnanswered : .deferTimeout, timeouts: reports)
    }

    private mutating func resetQuiet() {
        quietSince = nil
        lastQuietObservation = nil
    }
}
