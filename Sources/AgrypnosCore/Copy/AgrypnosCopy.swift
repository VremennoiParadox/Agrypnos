public enum AgrypnosCopy: Sendable {
    public static let appName = "Agrypnos"
    public static let keepWatch = "Keep the watch"
    public static let durationLabel = "How long"
    public static let keyboardDark = "Keyboard backlight off"
    public static let brightnessFloor = "Brightness floor"
    public static let batteryFloor = "Auto-off at low battery"
    public static let launchAtLogin = "Launch at login"
    public static let quit = "Quit Agrypnos"
    public static let agentsHint = "Busy stays awake. When they settle, sleep may return."
    public static let captionOff = "Sleeps with you when the lid closes."
    public static let grantNeeded = "The lid-close grant isn’t installed yet. macOS will ask once."
    public static let timerEnded = "Timer ended. The watch stands down."
    public static let batteryEnded = "Battery floor. The watch stands down."
    public static let thermalEnded = "Thermal pressure. The watch stands down."
    public static let agentsEnded = "Agents settled. Sleep can return."
    public static let lpmEnded = "Low Power Mode. The watch stands down."

    public static func captionOn(floor: Int) -> String {
        "Armed. Lid close floors brightness and keys. Turns off at \(floor)% battery."
    }

    public static func hotkeyHint(_ chord: HotkeyChord, registered: Bool = true) -> String {
        if registered {
            return "\(chord.display) toggles the watch"
        }
        return "\(chord.display) is not registered. Use the menu bar."
    }

    public static func notification(for reason: DisengageReason) -> String {
        switch reason {
        case .user: return "Watch down."
        case .timerExpired: return timerEnded
        case .batteryFloor: return batteryEnded
        case .thermal: return thermalEnded
        case .agentsSettled: return agentsEnded
        case .lowPowerMode: return lpmEnded
        }
    }

    public static let leftoverNotify =
        "SleepDisabled was already on. Agrypnos adopted it and re-applied the watch."
    public static let menuTooltipOff = "Agrypnos: watch is down."
    public static let menuTooltipOn = "Agrypnos: lid can fall. Machine stays up."
    public static let menuTooltipArmed = "Agrypnos: lid can fall. On battery."
    public static let menuTooltipLeftover = "Agrypnos: adopted leftover SleepDisabled."

    public static func leftoverCaption(floor: Int) -> String {
        "Leftover SleepDisabled. Watch adopted it. Turns off at \(floor)% battery."
    }

    public static func watchCaption(engaged: Bool, leftover: Bool, floor: Int) -> String {
        if !engaged { return captionOff }
        if leftover { return leftoverCaption(floor: floor) }
        return captionOn(floor: floor)
    }
}
