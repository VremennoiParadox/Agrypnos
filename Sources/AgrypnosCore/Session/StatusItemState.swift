import Foundation

/// Menu-bar extra while armed: a non-countdown status.
/// Sticky How long is remembered only. Agents idle-after-wait turns Keep the watch
/// off; that is not a remaining-time clock.
public enum StatusItemState: Equatable, Sendable {
    case off
    case armed
    case agents

    public static func from(engaged: Bool, duration: DurationOption) -> StatusItemState {
        guard engaged else { return .off }
        switch duration {
        case .untilAgentsSettle:
            return .agents
        case .indefinite, .oneHour, .threeHours, .custom:
            return .armed
        }
    }

    /// Remaining-time digits only if this returns a date Core will actually turn the watch off.
    /// Sticky How long is remembered only; do not read `timerEnd` as that clock.
    public static func autoOffEndClock(
        engaged: Bool,
        duration: DurationOption,
        timerEnd: Date?
    ) -> Date? {
        guard engaged else { return nil }
        _ = timerEnd
        switch duration {
        case .indefinite, .oneHour, .threeHours, .custom, .untilAgentsSettle:
            return nil
        }
    }

    public static func remainingSeconds(
        engaged: Bool,
        duration: DurationOption,
        timerEnd: Date?,
        now: Date
    ) -> Int? {
        guard let end = autoOffEndClock(
            engaged: engaged,
            duration: duration,
            timerEnd: timerEnd
        ) else {
            return nil
        }
        return max(0, Int(end.timeIntervalSince(now).rounded()))
    }
}

extension WatchEngine {
    public var statusItemState: StatusItemState {
        .from(engaged: engaged, duration: preferences.duration)
    }

    public func statusItemRemainingSeconds(now: Date) -> Int? {
        StatusItemState.remainingSeconds(
            engaged: engaged,
            duration: preferences.duration,
            timerEnd: timerEnd,
            now: now
        )
    }
}
