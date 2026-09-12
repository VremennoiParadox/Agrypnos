import Foundation

public enum HygieneRestore: Sendable {
    /// Mid-watch lid open restores brightness over this many seconds.
    public static let lidOpenRampDuration: TimeInterval = 2

    /// Restore only a captured keyboard brightness. Nil means capture failed — never write 0 as a guess.
    public static func keyboardBrightnessToRestore(captured: Double?) -> Double? {
        captured
    }

    public static func displayBrightnessToRestore(captured: Double?, floor: Double) -> Double {
        max(captured ?? floor, floor)
    }
}
