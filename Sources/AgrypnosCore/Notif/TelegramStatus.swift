import Foundation

/// Live WatchEngine facts for Telegram `/status`. Omit unknown lines in the copy.
public struct TelegramWatchStatus: Equatable, Sendable {
    public var engaged: Bool
    public var duration: DurationOption
    public var lidCloseConfirmed: Bool
    public var includedAgentKinds: Set<AgentKind>
    public var sawBusyThisArm: Bool?
    public var settlingAfterBusy: Bool?
    public var lastWatchEnd: LastWatchEnd?
    public var batteryFloorPercent: Int
    public var thermalAutoOff: Bool
    public var lowPowerMode: Bool?
    public var userForcedThisSession: Bool
    /// Live charge from the same sensor as low-battery auto-off. Nil = omit.
    public var liveBatteryPercent: Int?
    public var liveBatteryDischarging: Bool?
    public var panelPowerMode: PanelPowerMode

    public init(
        engaged: Bool,
        duration: DurationOption,
        lidCloseConfirmed: Bool,
        includedAgentKinds: Set<AgentKind>,
        sawBusyThisArm: Bool?,
        settlingAfterBusy: Bool?,
        lastWatchEnd: LastWatchEnd?,
        batteryFloorPercent: Int,
        thermalAutoOff: Bool,
        lowPowerMode: Bool?,
        userForcedThisSession: Bool,
        liveBatteryPercent: Int? = nil,
        liveBatteryDischarging: Bool? = nil,
        panelPowerMode: PanelPowerMode = .floor
    ) {
        self.engaged = engaged
        self.duration = duration
        self.lidCloseConfirmed = lidCloseConfirmed
        self.includedAgentKinds = includedAgentKinds
        self.sawBusyThisArm = sawBusyThisArm
        self.settlingAfterBusy = settlingAfterBusy
        self.lastWatchEnd = lastWatchEnd
        self.batteryFloorPercent = batteryFloorPercent
        self.thermalAutoOff = thermalAutoOff
        self.lowPowerMode = lowPowerMode
        self.userForcedThisSession = userForcedThisSession
        self.liveBatteryPercent = liveBatteryPercent
        self.liveBatteryDischarging = liveBatteryDischarging
        self.panelPowerMode = panelPowerMode
    }
}

public enum TelegramWatchStatusCopy: Sendable {
    public static func reply(
        _ status: TelegramWatchStatus,
        now: Date,
        calendar: Calendar = .current,
        locale: Locale? = nil
    ) -> String {
        let locale = locale ?? calendar.locale ?? .current
        var lines: [String] = [
            status.engaged ? TelegramInboundCopy.keepOn : TelegramInboundCopy.keepOff,
            "How long is \(status.duration.segmentTitle).",
            status.lidCloseConfirmed
                ? "Lid is confirmed closed."
                : "Lid is open or unconfirmed.",
        ]
        lines.append(status.panelPowerMode.statusLine)
        if status.duration == .untilAgentsSettle {
            lines.append(contentsOf: agentLines(status))
        }
        if let event = status.lastWatchEnd {
            lines.append(
                AgrypnosCopy.lastWatchEndCaption(
                    event: event, now: now, calendar: calendar, locale: locale
                )
            )
        }
        if let battery = batteryLine(status) {
            lines.append(battery)
        }
        let thermal = status.thermalAutoOff ? "on" : "off"
        lines.append(
            "Auto-off at \(status.batteryFloorPercent)% battery. Thermal auto-off is \(thermal)."
        )
        if let lpm = lpmLine(status) {
            lines.append(lpm)
        }
        return lines.joined(separator: "\n")
    }

    static func agentLines(_ status: TelegramWatchStatus) -> [String] {
        var lines: [String] = []
        let names = AgentKind.allCases
            .filter { status.includedAgentKinds.contains($0) }
            .map(\.displayName)
        if !names.isEmpty {
            lines.append("Selected tools: \(names.joined(separator: ", ")).")
        }
        if let saw = status.sawBusyThisArm {
            lines.append(
                saw
                    ? "Local busy signals seen this arm."
                    : "No local busy signals seen this arm."
            )
        }
        if status.settlingAfterBusy == true {
            lines.append("Waiting after local busy signals stop.")
        }
        return lines
    }

    /// Omit when charge % is unknown. Never invent a percent.
    static func batteryLine(_ status: TelegramWatchStatus) -> String? {
        guard let percent = status.liveBatteryPercent else { return nil }
        let source = status.liveBatteryDischarging == true ? "discharging" : "on AC"
        return "Battery \(percent)% · \(source)"
    }

    /// Known LPM only. Forced watch still holding must not read as ended.
    static func lpmLine(_ status: TelegramWatchStatus) -> String? {
        guard status.lowPowerMode == true else { return nil }
        if status.engaged, status.userForcedThisSession {
            return "Low Power Mode is on. Keep the watch is still on."
        }
        return "Low Power Mode is on."
    }
}

extension WatchEngine {
    /// Snapshot for `/status`. Live battery comes from the same `SafetyInputs` as auto-off.
    public func telegramWatchStatus(
        now: Date,
        agentsBusy: Bool? = nil,
        lowPowerMode: Bool? = nil,
        safety: SafetyInputs? = nil
    ) -> TelegramWatchStatus {
        let agentsMode = preferences.duration == .untilAgentsSettle
        var sawBusyThisArm: Bool?
        var settlingAfterBusy: Bool?
        if agentsMode, engaged {
            sawBusyThisArm = settle.sawBusy || agentsBusy == true
            if let busy = agentsBusy {
                settlingAfterBusy = settle.activity(busy: busy, now: now) == .settling
            }
        }
        let livePercent = safety?.batteryPercent
        let liveDischarging: Bool? = livePercent == nil ? nil : safety?.onBatteryDischarging
        return TelegramWatchStatus(
            engaged: engaged,
            duration: preferences.duration,
            lidCloseConfirmed: lidCloseConfirmed,
            includedAgentKinds: preferences.includedAgentKinds,
            sawBusyThisArm: sawBusyThisArm,
            settlingAfterBusy: settlingAfterBusy,
            lastWatchEnd: preferences.lastWatchEnd,
            batteryFloorPercent: preferences.batteryFloorPercent,
            thermalAutoOff: preferences.thermalAutoOff,
            lowPowerMode: lowPowerMode ?? safety?.lowPowerMode,
            userForcedThisSession: userForcedThisSession,
            liveBatteryPercent: livePercent,
            liveBatteryDischarging: liveDischarging,
            panelPowerMode: preferences.panelPowerMode
        )
    }
}
