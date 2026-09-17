public enum WatchCommand: Equatable, Sendable {
    case engage
    case assertSleepDisabled
    case disengage(DisengageReason)
    case requestKeyboardBacklightOff
    case applyBrightnessFloor
    case restoreKeyboardBacklight
    case rampBrightnessRestore
    /// Lid already shut: dropping SleepDisabled does not start sleep; ask the Mac to.
    case requestSleep
    /// One-shot outbound after Agents idle-after-wait. Mac reads secrets and POSTs.
    case postIdleAfterWaitNotif
}

public enum WatchMode: Equatable, Sendable {
    case idle
    case indefinite
    case timed
    case untilAgentsSettle
}
