public enum WatchCommand: Equatable, Sendable {
    case engage
    case disengage(DisengageReason)
    /// Kept so Core can prove we never emit it on the armed-watch path.
    case requestDisplaySleep
    case requestKeyboardBacklightOff
    case applyBrightnessFloor
    case restoreKeyboardBacklight
    case rampBrightnessRestore
}

public enum WatchMode: Equatable, Sendable {
    case idle
    case indefinite
    case timed
    case untilAgentsSettle
}
