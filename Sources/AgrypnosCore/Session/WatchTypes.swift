public enum WatchCommand: Equatable, Sendable {
    case engage
    case disengage(DisengageReason)
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
