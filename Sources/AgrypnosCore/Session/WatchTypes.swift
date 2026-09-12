public enum WatchCommand: Equatable, Sendable {
    case engage
    case disengage(DisengageReason)
    case requestDisplaySleep
    case requestKeyboardBacklightOff
    case applyBrightnessFloor
}

public enum WatchMode: Equatable, Sendable {
    case idle
    case indefinite
    case timed
    case untilAgentsSettle
}
