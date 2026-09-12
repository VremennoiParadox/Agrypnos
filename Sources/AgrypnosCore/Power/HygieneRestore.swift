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

    public static func displayBrightnessToRestore(captured: Double?, floor: Double) -> Double {
        max(captured ?? floor, floor)
    }
}
