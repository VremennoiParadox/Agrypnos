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
    public static let timedHint = "Then the watch stands down."
    public static let indefiniteHint = "Until you say otherwise — plus safety nets."
    public static let captionOff = "Sleeps with you when the lid closes."
    public static let grantNeeded = "The lid-close grant isn’t installed yet. macOS will ask once."
    public static let timerEnded = "Timer ended. The watch stands down."
    public static let batteryEnded = "Battery floor. The watch stands down."
    public static let thermalEnded = "Thermal pressure. The watch stands down."
    public static let agentsEnded = "Agents settled. Sleep can return."
    public static let lpmEnded = "Low Power Mode. The watch stands down."

    public static func captionPrepared(floor: Int) -> String {
        "Prepared. Waiting for the lid — I'll floor the panel and kill the keys. Turns off at \(floor)% battery."
    }

    public static func captionLidClosed(floor: Int) -> String {
        "Lid's down. Brightness floored, keys dark. Turns off at \(floor)% battery."
    }

    public static func hotkeyHint(_ chord: HotkeyChord, registered: Bool = true) -> String {
        if registered {
            return "\(chord.display) toggles the watch"
        }
        return "\(chord.display) is not registered. Use the menu bar."
    }

    public static func durationHint(option: DurationOption, engaged: Bool, remainingSeconds: Int?) -> String {
        switch option {
        case .untilAgentsSettle:
            return agentsHint
        case .oneHour, .threeHours:
            if engaged, let remaining = remainingSeconds {
                let clamped = max(0, remaining)
                return String(format: "Auto-off in %d:%02d", clamped / 60, clamped % 60)
            }
            return timedHint
        case .indefinite:
            return indefiniteHint
        }
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
    public static let menuTooltipOn = "Agrypnos: prepared. Waiting for the lid."
    public static let menuTooltipArmed = "Agrypnos: prepared. Waiting for the lid. On battery."
    public static let menuTooltipLidClosed = "Agrypnos: lid down. Brightness floored, keys dark."
    public static let menuTooltipLeftover = "Agrypnos: adopted leftover SleepDisabled."

    public static func leftoverCaption(floor: Int) -> String {
        "Leftover SleepDisabled. Watch adopted it. Turns off at \(floor)% battery."
    }

    public static func watchCaption(
        engaged: Bool,
        leftover: Bool,
        floor: Int,
        lidClosed: Bool = false
    ) -> String {
        if !engaged { return captionOff }
        if leftover { return leftoverCaption(floor: floor) }
        if lidClosed { return captionLidClosed(floor: floor) }
        return captionPrepared(floor: floor)
    }

    public static func menuTooltip(
        engaged: Bool,
        leftover: Bool,
        onBattery: Bool,
        lidClosed: Bool
    ) -> String {
        if !engaged { return menuTooltipOff }
        if leftover { return menuTooltipLeftover }
        if lidClosed { return menuTooltipLidClosed }
        return onBattery ? menuTooltipArmed : menuTooltipOn
    }
}
