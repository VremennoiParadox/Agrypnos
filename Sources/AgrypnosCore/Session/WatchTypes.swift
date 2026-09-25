public enum WatchCommand: Equatable, Sendable {
    case engage
    case assertSleepDisabled
    case disengage(DisengageReason)
    case requestKeyboardBacklightOff
    case applyBrightnessFloor
    case restoreKeyboardBacklight
    case rampBrightnessRestore
    /// Power B: sleep the panel/display only (`pmset displaysleepnow`). Not Mac sleep.
    case requestDisplaySleep
    /// Power B: wake the panel after display sleep. Not Mac sleep, not a floor write.
    /// Adapter: smallest honest wake (`caffeinate -u -t 1`). Needs a Mac to prove.
    case wakeDisplay
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
