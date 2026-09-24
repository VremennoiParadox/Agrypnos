import Foundation

/// Mutually exclusive panel modes. A = floor + ramp. B = display sleep.
/// B does not turn Keep the watch off and does not sleep the Mac.
public enum PanelPowerMode: String, Equatable, Sendable, CaseIterable {
    /// A (default): brightness floor on confirmed lid-close; lid-open ramp.
    case floor
    /// B: `displaysleepnow` on confirmed lid-close. Panel only. Watch still holds.
    case displaySleep

    public static let `default` = PanelPowerMode.floor

    public var writesBrightnessFloor: Bool { self == .floor }
    public var sleepsDisplay: Bool { self == .displaySleep }
    public var showsLidOpenRamp: Bool { self == .floor }

    /// `/status` line. B is display asleep, not Mac asleep.
    public var statusLine: String {
        switch self {
        case .floor:
            return "Power A: brightness floor + ramp."
        case .displaySleep:
            return "Power B: display asleep."
        }
    }

    public static func shouldWriteFloor(
        armed: Bool,
        lidCloseConfirmed: Bool,
        mode: PanelPowerMode
    ) -> Bool {
        armed && lidCloseConfirmed && mode == .floor
    }

    public static func shouldSleepDisplay(
        armed: Bool,
        lidCloseConfirmed: Bool,
        mode: PanelPowerMode
    ) -> Bool {
        armed && lidCloseConfirmed && mode == .displaySleep
    }

    /// Confirmed lid-close panel work. Never floor + display sleep together.
    /// Keyboard off is independent. Never `.requestSleep` (that is the Mac).
    public static func lidCloseCommands(
        mode: PanelPowerMode,
        applyBrightnessFloor: Bool,
        keyboardBacklightOff: Bool
    ) -> [WatchCommand] {
        var commands: [WatchCommand] = []
        switch mode {
        case .floor:
            if applyBrightnessFloor { commands.append(.applyBrightnessFloor) }
        case .displaySleep:
            commands.append(.requestDisplaySleep)
        }
        if keyboardBacklightOff { commands.append(.requestKeyboardBacklightOff) }
        return commands
    }

    /// Lid-open restore. Ramp only from the floor path. B wakes the panel.
    public static func lidOpenCommands(
        mode: PanelPowerMode,
        applyBrightnessFloor: Bool,
        keyboardBacklightOff: Bool
    ) -> [WatchCommand] {
        var commands: [WatchCommand] = []
        switch mode {
        case .floor:
            if applyBrightnessFloor { commands.append(.rampBrightnessRestore) }
        case .displaySleep:
            commands.append(.wakeDisplay)
        }
        if keyboardBacklightOff { commands.append(.restoreKeyboardBacklight) }
        return commands
    }

    /// Open-lid / disarm must not leave B's panel asleep. Adapter wakes it.
    /// Assumption: `caffeinate -u -t 1` after `pmset displaysleepnow`. Needs a Mac.
    public static func disengageDisplayCommand(mode: PanelPowerMode) -> WatchCommand? {
        mode == .displaySleep ? .wakeDisplay : nil
    }
}

/// Copy UI can bind later. Not a popover control.
public enum PanelPowerChrome: Sendable {
    public static let titles = ["Dim panel", "Sleep panel"]

    public static func selectedSegment(mode: PanelPowerMode) -> Int {
        mode == .floor ? 0 : 1
    }

    public static func mode(selectingSegment index: Int) -> PanelPowerMode? {
        switch index {
        case 0: return .floor
        case 1: return .displaySleep
        default: return nil
        }
    }

    public static func showsLidOpenRamp(_ mode: PanelPowerMode) -> Bool {
        mode.showsLidOpenRamp
    }

    public static func caption(_ mode: PanelPowerMode) -> String {
        switch mode {
        case .floor:
            return "Brightness floor on confirmed lid close + lid-open ramp. Panel stays on, dimmed."
        case .displaySleep:
            return "Panel sleeps on confirmed lid close. Keep the watch still holds the Mac awake."
        }
    }

    public static func help(_ mode: PanelPowerMode) -> String {
        switch mode {
        case .floor:
            return "Confirmed lid close sets the brightness floor. The panel stays on, dimmed."
        case .displaySleep:
            return "Confirmed lid close sleeps the panel. Keep the watch still holds the Mac awake. Brightness return is hidden because it only applies after the floor path."
        }
    }
}
