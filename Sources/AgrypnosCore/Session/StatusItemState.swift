import Foundation

/// Menu-bar extra while armed: a non-countdown status.
/// Timed watches use a real deadline; Agents settle is not a countdown.
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
    /// Only timed modes expose the deadline; the menu-bar title stays unchanged.
    public static func autoOffEndClock(
        engaged: Bool,
        duration: DurationOption,
        timerEnd: Date?
    ) -> Date? {
        guard engaged else { return nil }
        switch duration {
        case .oneHour, .threeHours, .custom: return timerEnd
        case .indefinite, .untilAgentsSettle: return nil
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
        let seconds = max(0, end.timeIntervalSince(now).rounded(.up))
        // Custom minutes can exceed Int's seconds range; keep rendering bounded.
        return seconds >= Double(Int.max) ? Int.max : Int(seconds)
    }
}

extension WatchEngine {
    public var statusItemState: StatusItemState {
        .from(engaged: engaged || holdingForIdlePost, duration: preferences.duration)
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
