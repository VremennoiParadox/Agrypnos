import Foundation

public enum AgrypnosCopy: Sendable {
    public static let appName = "Agrypnos"
    public static let keepWatch = "Keep the watch"
    public static let durationLabel = "How long"
    public static let minutesLabel = "Minutes"
    public static let minutesPlaceholder = "33"
    public static let shortcutLabel = "Shortcut"
    public static let hotkeyRecording = "Listening…"
    public static let hotkeyRecordingHint = "Press a chord. Esc cancels."
    public static let keyboardDark = "Keyboard backlight off"
    public static let brightnessFloor = "Brightness floor"
    public static let brightnessFloorHelp =
        "Dim panel: when the lid closes, brightness drops to this percent."
    public static let settleGrace = "Wait after agents go idle"
    public static let settleGraceHelp =
        "How long to wait after local busy signals stop, before the idle-after-wait POST. Then Keep the watch turns off. Buffer so a quiet gap mid-run (no file write / low CPU) doesn’t look finished. Not still thinking — we only see local process and session activity."
    public static let agentInclude = "Which tools count as busy."
    public static let agentIncludeHelp =
        "Only selected tools count as busy. Keep at least one on."
    public static let countTerminalSessions = "Count terminal sessions as busy"
    public static let countTerminalSessionsHelp =
        "Terminal session files can keep the watch on if this is on. Default off so a noisy terminal doesn’t hold wake."
    public static let lidOpenRamp = "Brightness return when lid opens"
    public static let lidOpenRampHelp =
        "How long brightness takes to come back when the lid opens."
    public static let batteryFloor = "Auto-off at low battery"
    public static let thermalAutoOff = "Thermal auto-off"
    public static let thermalAutoOffHelp = "Thermal pressure turns the watch off."
    public static let launchAtLogin = "Launch at login"
    public static let quit = "Quit Agrypnos"
    public static let agentsHint =
        "Watch turns off after local busy signals stay idle through the wait (battery / thermal still apply)."
    public static let timedHint =
        "Stays on until you turn it off (battery / thermal still apply)."
    // User-armed watches do not auto-off on Low Power Mode, so it is not listed here.
    public static let indefiniteHint =
        "Stays on until you turn it off (battery / thermal still apply)."

    public static func indefiniteHint(thermalAutoOff: Bool) -> String {
        if thermalAutoOff {
            return AgrypnosCopy.indefiniteHint
        }
        return "Stays on until you turn it off (battery still applies)."
    }

    public static func agentsHint(thermalAutoOff: Bool) -> String {
        if thermalAutoOff {
            return AgrypnosCopy.agentsHint
        }
        return "Watch turns off after local busy signals stay idle through the wait (battery still applies)."
    }

    public static let captionOff = "Keeps the Mac awake with the lid closed."
    public static let grantNeeded = "The lid-close grant isn’t installed yet. macOS will ask once."
    public static let timerEnded = "Timer ended. Watch turned off."
    public static let batteryEnded = "Battery floor reached. Watch turned off."
    public static let thermalEnded = "Thermal pressure. Watch turned off."
    public static let agentsEnded = "Agents idle. Watch turned off."
    public static let lpmEnded = "Low Power Mode. Watch turned off."

    public static func captionPrepared(floor: Int, panelPowerMode: PanelPowerMode = .default) -> String {
        switch panelPowerMode {
        case .floor:
            return "Armed. Waiting for lid close — then brightness floor, keyboard backlight off. Auto-off at \(floor)% battery."
        case .displaySleep:
            return "Armed. Waiting for lid close — then the panel sleeps + keyboard backlight off. Keep the watch still holds the Mac awake."
        }
    }

    public static func captionLidClosed(floor: Int, panelPowerMode: PanelPowerMode = .default) -> String {
        switch panelPowerMode {
        case .floor:
            return "Lid closed. Brightness floor + keyboard backlight off. Auto-off at \(floor)% battery."
        case .displaySleep:
            return "Lid closed. Panel sleeps + keyboard backlight off. Keep the watch still holds the Mac awake. Auto-off at \(floor)% battery."
        }
    }

    public static func hotkeyHint(_ chord: HotkeyChord, registered: Bool = true) -> String {
        if !chord.isBindable {
            return "That chord needs Option, Command, or Control."
        }
        if registered {
            return "\(chord.display) toggles the watch"
        }
        return "\(chord.display) is not registered. Use the menu bar."
    }

    public static func durationHint(
        option: DurationOption,
        engaged: Bool,
        remainingSeconds: Int?,
        thermalAutoOff: Bool = true
    ) -> String {
        _ = engaged
        _ = remainingSeconds
        switch option {
        case .untilAgentsSettle:
            return agentsHint(thermalAutoOff: thermalAutoOff)
        case .oneHour, .threeHours, .custom, .indefinite:
            return indefiniteHint(thermalAutoOff: thermalAutoOff)
        }
    }

    public static func notification(for reason: DisengageReason) -> String {
        switch reason {
        case .user: return "Watch turned off."
        case .timerExpired: return timerEnded
        case .batteryFloor: return batteryEnded
        case .thermal: return thermalEnded
        case .agentsSettled: return agentsEnded
        case .lowPowerMode: return lpmEnded
        }
    }

    public static let lastWatchEndNone = "No watch has ended yet."

    public static func lastWatchEndReason(_ reason: DisengageReason) -> String {
        switch reason {
        case .user: return "you turned it off"
        case .timerExpired: return "the timer ended"
        case .batteryFloor: return "the battery floor was reached"
        case .thermal: return "thermal pressure turned the watch off"
        case .agentsSettled: return "local busy signals stayed idle after the wait"
        case .lowPowerMode: return "Low Power Mode was on"
        }
    }

    public static func lastWatchEndCaption(when: String, reason: DisengageReason) -> String {
        "Last watch ended at \(when), because \(lastWatchEndReason(reason))."
    }

    public static func lastWatchEndClock(
        endedAt: Date, now: Date, calendar: Calendar = .current, locale: Locale = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        formatter.timeStyle = .short
        formatter.dateStyle = calendar.isDate(endedAt, inSameDayAs: now) ? .none : .medium
        return formatter.string(from: endedAt)
    }

    public static func lastWatchEndCaption(
        event: LastWatchEnd?, now: Date, calendar: Calendar = .current, locale: Locale = .current
    ) -> String {
        guard let event else { return lastWatchEndNone }
        let when = lastWatchEndClock(endedAt: event.endedAt, now: now, calendar: calendar, locale: locale)
        return lastWatchEndCaption(when: when, reason: event.reason)
    }

    public static let leftoverNotify =
        "SleepDisabled was already on. Agrypnos adopted it. Lid close still uses brightness floor + keyboard backlight off."
    public static let leftoverNotifySleepPanel =
        "SleepDisabled was already on. Agrypnos adopted it. Lid close still sleeps the panel + keyboard backlight off. Keep the watch still holds the Mac awake."

    public static func leftoverNotify(for panelPowerMode: PanelPowerMode) -> String {
        switch panelPowerMode {
        case .floor: return leftoverNotify
        case .displaySleep: return leftoverNotifySleepPanel
        }
    }

    public static let notifEnabled = "Idle-after-wait POST"
    public static let notifEnabledHelp =
        "POST to your Discord webhook and/or message your Telegram bot after Agents stay idle through the wait. Off by default."
    public static let notifDiscord = "Discord webhook URL"
    public static let notifDiscordHelp = "POST to your webhook. Leave empty to skip Discord."
    public static let notifTelegramToken = "Telegram bot token"
    public static let notifTelegramChatId = "Telegram chat id"
    public static let notifTelegram = "Telegram"
    public static let notifTelegramTokenShort = "Token"
    public static let notifTelegramChatShort = "Chat id"
    public static let notifDiscordPlaceholder = "paste webhook URL"
    public static let notifTelegramTokenPlaceholder = "paste bot token"
    public static let notifTelegramChatPlaceholder = "from getUpdates"
    public static let notifTelegramHelp =
        "Message your Telegram bot. Needs token; chat id from getUpdates. Agrypnos does not run a shared bot."
    public static let notifTelegramInbound = "Telegram inbound"
    public static let notifTelegramInboundHelp =
        "Commands on your Telegram bot: /arm, /disarm, /status, /help. Details in Setup instructions."
    public static let notifDiscordInbound = "Discord inbound"
    public static let notifDiscordInboundHelp =
        "Commands on your Discord bot: /arm, /disarm, /status, /help. Needs your bot token + channel id. Details in Setup instructions."
    public static let notifDiscordInboundTokenShort = "Token"
    public static let notifDiscordInboundChannelShort = "Channel"
    public static let notifDiscordInboundToken = "Discord bot token"
    public static let notifDiscordInboundChannelId = "Discord channel id"
    public static let notifDiscordInboundTokenPlaceholder = "paste bot token"
    public static let notifDiscordInboundChannelPlaceholder = "channel id"
    public static let notifDiscordInboundTokenInvalid =
        "That is not a Discord bot token. Nothing was saved."
    public static let notifDiscordInboundChannelInvalid =
        "That is not a Discord channel id. Nothing was saved."
    public static let notifClear = "Clear secrets"
    public static func revealAccess(label: String, revealed: Bool) -> String {
        "\(revealed ? "Hide" : "Show") \(label)"
    }
    public static let notifSaveFailed = "Couldn't save that secret."
    public static let notifDiscordPostFailed = "Couldn't POST to your webhook."
    public static let notifTelegramPostFailed = "Couldn't message your Telegram bot."
    public static let notifTelegramChatInvalid =
        "That is not a Telegram chat id. Nothing was saved."
    public static let notifTelegramTokenInvalid =
        "That is not a Telegram bot token. Nothing was saved."
    public static let notifDiscordInvalid =
        "That is not a Discord webhook URL. Nothing was saved."
    public static let notifSetup = "Setup instructions…"
    public static let notifIdleBody =
        "Agrypnos: local busy signals went idle after the wait."
    public static let statusItemArmed = "Armed."
    public static let statusItemAgents = "Agents."
    public static let menuTooltipOff = "Agrypnos: watch is off."
    public static let menuTooltipOn =
        "Agrypnos: armed. Waiting for lid close — then brightness floor + keyboard backlight off."
    public static let menuTooltipArmed =
        "Agrypnos: armed. Waiting for lid close — then brightness floor + keyboard backlight off. On battery."
    public static let menuTooltipLidClosed =
        "Agrypnos: lid closed. Brightness floor + keyboard backlight off."
    public static let menuTooltipLeftover =
        "Agrypnos: adopted leftover SleepDisabled. Waiting for lid close — then brightness floor + keyboard backlight off."
    public static let menuTooltipLeftoverLidClosed =
        "Agrypnos: adopted leftover SleepDisabled. Lid closed. Brightness floor + keyboard backlight off."
    public static let menuTooltipOnSleepPanel =
        "Agrypnos: armed. Waiting for lid close — then the panel sleeps + keyboard backlight off. Keep the watch still holds the Mac awake."
    public static let menuTooltipArmedSleepPanel =
        "Agrypnos: armed. Waiting for lid close — then the panel sleeps + keyboard backlight off. Keep the watch still holds the Mac awake. On battery."
    public static let menuTooltipLidClosedSleepPanel =
        "Agrypnos: lid closed. Panel sleeps + keyboard backlight off. Keep the watch still holds the Mac awake."
    public static let menuTooltipLeftoverSleepPanel =
        "Agrypnos: adopted leftover SleepDisabled. Waiting for lid close — then the panel sleeps + keyboard backlight off. Keep the watch still holds the Mac awake."
    public static let menuTooltipLeftoverLidClosedSleepPanel =
        "Agrypnos: adopted leftover SleepDisabled. Lid closed. Panel sleeps + keyboard backlight off. Keep the watch still holds the Mac awake."

    public static func statusItemTitle(_ state: StatusItemState) -> String {
        switch state {
        case .off: return ""
        case .armed: return statusItemArmed
        case .agents: return statusItemAgents
        }
    }

    public static func leftoverCaption(
        floor: Int,
        lidClosed: Bool = false,
        panelPowerMode: PanelPowerMode = .default
    ) -> String {
        switch panelPowerMode {
        case .floor:
            if lidClosed {
                return "Leftover SleepDisabled. Lid closed. Brightness floor, keyboard backlight off. Auto-off at \(floor)% battery."
            }
            return "Leftover SleepDisabled. Lid close — then brightness floor, keyboard backlight off. Auto-off at \(floor)% battery."
        case .displaySleep:
            if lidClosed {
                return "Leftover SleepDisabled. Lid closed. Panel sleeps + keyboard backlight off. Keep the watch still holds the Mac awake. Auto-off at \(floor)% battery."
            }
            return "Leftover SleepDisabled. Lid close — then the panel sleeps + keyboard backlight off. Keep the watch still holds the Mac awake."
        }
    }

    public static func watchCaption(
        engaged: Bool,
        leftover: Bool,
        floor: Int,
        lidClosed: Bool,
        panelPowerMode: PanelPowerMode = .default
    ) -> String {
        if !engaged { return captionOff }
        if leftover { return leftoverCaption(floor: floor, lidClosed: lidClosed, panelPowerMode: panelPowerMode) }
        if lidClosed { return captionLidClosed(floor: floor, panelPowerMode: panelPowerMode) }
        return captionPrepared(floor: floor, panelPowerMode: panelPowerMode)
    }

    public static func menuTooltip(
        engaged: Bool,
        leftover: Bool,
        onBattery: Bool,
        lidClosed: Bool,
        panelPowerMode: PanelPowerMode = .default
    ) -> String {
        if !engaged { return menuTooltipOff }
        switch panelPowerMode {
        case .floor:
            if leftover {
                return lidClosed ? menuTooltipLeftoverLidClosed : menuTooltipLeftover
            }
            if lidClosed { return menuTooltipLidClosed }
            return onBattery ? menuTooltipArmed : menuTooltipOn
        case .displaySleep:
            if leftover {
                return lidClosed ? menuTooltipLeftoverLidClosedSleepPanel : menuTooltipLeftoverSleepPanel
            }
            if lidClosed { return menuTooltipLidClosedSleepPanel }
            return onBattery ? menuTooltipArmedSleepPanel : menuTooltipOnSleepPanel
        }
    }
}
