import Foundation

public enum HygieneRestore: Sendable {
    /// Default mid-watch lid-open ramp when prefs are missing. Live path reads user 1/2/3s.
    public static let lidOpenRampDuration: TimeInterval = 2

    public static func lidOpenRampDuration(seconds: Int) -> TimeInterval {
        TimeInterval(UserPreferences.clampLidOpenRamp(seconds))
    }

    /// Restore only a captured keyboard brightness. Nil means capture failed — never write 0 as a guess.
    public static func keyboardBrightnessToRestore(captured: Double?) -> Double? {
        captured
    }

    /// Restore only a captured display brightness. Nil means capture failed — never write the floor as a guess.
    /// Exact capture — do not lift a dimmer captured level up to the floor.
    public static func displayBrightnessToRestore(captured: Double?, floor: Double) -> Double? {
        _ = floor
        return captured
    }

    /// Closed-lid sleepnow: do not turn the panel or keyboard back on first.
    public static func shouldRestoreAfterDisengage(
        lidCloseConfirmed: Bool,
        nextCommandIsSleep: Bool
    ) -> Bool {
        if lidCloseConfirmed, nextCommandIsSleep { return false }
        return true
    }
}
