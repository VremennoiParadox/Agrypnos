import Foundation

public enum DiscordBotOutbound: Sendable {
    /// One Discord channel message for this disengage. Nil sends nothing.
    /// `reason == nil` is already-off confirmed-closed disarm.
    public static func body(reason: DisengageReason?, willSleep: Bool) -> String? {
        switch reason {
        case .timerExpired:
            return willSleep
                ? "Agrypnos: your Keep awake timer ended. Asking the Mac to sleep."
                : "Agrypnos: your Keep awake timer ended."
        case .agentsSettled:
            return willSleep
                ? AgrypnosCopy.notifIdleBody + " Asking the Mac to sleep."
                : AgrypnosCopy.notifIdleBody
        case .user:
            return willSleep ? "Agrypnos: Keep awake is off. Asking the Mac to sleep." : nil
        case .batteryFloor:
            return willSleep ? "Agrypnos: battery auto-off. Asking the Mac to sleep." : nil
        case .thermal:
            return willSleep ? "Agrypnos: thermal pressure turned Keep awake off. Asking the Mac to sleep." : nil
        case .lowPowerMode:
            return willSleep ? "Agrypnos: Low Power Mode turned Keep awake off. Asking the Mac to sleep." : nil
        case nil:
            return willSleep ? "Agrypnos: asking the Mac to sleep." : nil
        case .questionUnanswered, .wakeHoldFailed:
            return nil
        }
    }
}
