public struct PopoverSlot: Equatable, Sendable {
    public let y: Int
    public let height: Int

    public init(y: Int, height: Int) {
        self.y = y
        self.height = height
    }

    public var maxY: Int { y + height }
}

/// Top-down popover math. AppKit places views; this file owns the y-offsets.
public struct PopoverStackLayout: Equatable, Sendable {
    public static let width = 328
    public static let pad = 16
    public static let inset = 12
    public static let cardGap = 10
    public static let sectionSwitcherY = 38
    public static let sectionSwitcherHeight = 24
    public static var firstCardY: Int {
        sectionSwitcherY + sectionSwitcherHeight + cardGap
    }
    public static let maxVisibleHeight = 720
    public static let quitReserve = 36
    public static let switchRowHeight = 32
    public static let titleRowHeight = 24
    public static let segmentRowHeight = 28
    public static let sliderBlockHeight = 48
    public static let durationCardHeight = 136
    public static let batteryCardHeight = 88
    public static let loginCardHeight = 44
    public static let secretFieldRowHeight = 28
    public static let switchRowLabelHeight = 22

    public static var loginSwitchRowY: Int {
        (loginCardHeight - switchRowLabelHeight) / 2
    }

    public static func switchControlY(labelY: Double, switchHeight: Double) -> Double {
        labelY + (Double(switchRowLabelHeight) - switchHeight) / 2
    }

    public static let hygieneKeyboardY = 10
    public static var hygieneFloorY: Int { hygieneKeyboardY + switchRowHeight }
    public static var hygieneHelpY: Int { hygieneFloorY + switchRowHeight }
    public static var hygieneSliderY: Int { hygieneHelpY + PopoverCopyLayout.helpHeightPoints }
    public static var hygieneMinMaxY: Int { hygieneSliderY + 24 }

    public static let prefTitleY = 12
    public static var prefHelpY: Int { prefTitleY + titleRowHeight }
    public static var prefControlY: Int { prefHelpY + PopoverCopyLayout.helpHeightPoints }
    public static var prefMinMaxY: Int { prefControlY + 24 }
    public static var settleControlY: Int { prefHelpY + PopoverCopyLayout.settleHelpHeightPoints }
    public static var settleMinMaxY: Int { settleControlY + 24 }
    public static let panelPowerControlY = prefTitleY
    public static var panelPowerCaptionY: Int { panelPowerControlY + segmentRowHeight }
    public static var panelPowerHelpY: Int { panelPowerCaptionY + PopoverCopyLayout.panelPowerCaptionHeightPoints }

    public static func includeSwitchY(index: Int) -> Int {
        prefControlY + index * switchRowHeight
    }

    public static var notifEnableHelpY: Int { prefTitleY + titleRowHeight }
    public static var notifEnableSwitchY: Int {
        notifEnableHelpY + PopoverCopyLayout.notifEnableHelpHeightPoints
    }
    public static var notifDiscordFieldY: Int { prefHelpY + PopoverCopyLayout.helpHeightPoints }
    public static var notifDiscordStatusY: Int { notifDiscordFieldY + secretFieldRowHeight }
    public static var notifTelegramTokenY: Int {
        prefTitleY + titleRowHeight + PopoverCopyLayout.notifTelegramHelpHeightPoints
    }
    public static var notifTelegramChatY: Int { notifTelegramTokenY + secretFieldRowHeight }
    public static var notifTelegramInboundSwitchY: Int {
        prefHelpY + PopoverCopyLayout.notifTelegramInboundHelpHeightPoints
    }
    public static var notifDiscordInboundTokenY: Int {
        prefHelpY + PopoverCopyLayout.notifDiscordInboundHelpHeightPoints
    }
    public static var notifDiscordInboundChannelY: Int {
        notifDiscordInboundTokenY + secretFieldRowHeight
    }
    public static var notifDiscordInboundSwitchY: Int {
        notifDiscordInboundChannelY + secretFieldRowHeight
    }
    public static var notifSetupHelpY: Int { prefTitleY + titleRowHeight }

    public let section: PopoverSection
    public let sectionSwitcher: PopoverSlot
    public let watch: PopoverSlot?
    public let duration: PopoverSlot?
    public let lastWatchEnd: PopoverSlot?
    public let panelPower: PopoverSlot?
    public let hygiene: PopoverSlot?
    public let battery: PopoverSlot?
    public let agentInclude: PopoverSlot?
    public let settle: PopoverSlot?
    public let ramp: PopoverSlot?
    public let thermal: PopoverSlot?
    public let login: PopoverSlot?
    public let notifEnable: PopoverSlot?
    public let notifDiscord: PopoverSlot?
    public let notifDiscordInbound: PopoverSlot?
    public let notifTelegram: PopoverSlot?
    public let notifTelegramInbound: PopoverSlot?
    public let notifSetup: PopoverSlot?
    public let notifClear: PopoverSlot?
    public let shortcutY: Int?
    public let hotkeyHint: PopoverSlot?
    public let quitY: Int?
    public let contentHeight: Int
    public let popoverHeight: Int

    public var needsScroll: Bool { contentHeight > popoverHeight }

    public var stackedCards: [PopoverSlot] {
        section.cards.compactMap { slot($0) }
    }

    public func slot(_ card: PopoverCard) -> PopoverSlot? {
        switch card {
        case .watch: return watch
        case .duration: return duration
        case .lastWatchEnd: return lastWatchEnd
        case .panelPower: return panelPower
        case .hygiene: return hygiene
        case .battery: return battery
        case .agentInclude: return agentInclude
        case .settle: return settle
        case .ramp: return ramp
        case .thermal: return thermal
        case .login: return login
        case .notifEnable: return notifEnable
        case .notifDiscord: return notifDiscord
        case .notifDiscordInbound: return notifDiscordInbound
        case .notifTelegram: return notifTelegram
        case .notifTelegramInbound: return notifTelegramInbound
        case .notifSetup: return notifSetup
        case .notifClear: return notifClear
        }
    }

    public static func make(
        section: PopoverSection = .default,
        panelPowerMode: PanelPowerMode = .default
    ) -> PopoverStackLayout {
        let watchHeight = inset + 28 + PopoverCopyLayout.captionHeightPoints + inset
        let hygieneHeight =
            hygieneKeyboardY
            + 2 * switchRowHeight
            + PopoverCopyLayout.helpHeightPoints
            + sliderBlockHeight
            + inset
        let includeHeight =
            inset
            + titleRowHeight
            + PopoverCopyLayout.helpHeightPoints
            + AgentKind.allCases.count * switchRowHeight
            + inset
        let settleHeight =
            inset
            + titleRowHeight
            + PopoverCopyLayout.settleHelpHeightPoints
            + sliderBlockHeight
            + inset
        let rampHeight =
            inset
            + titleRowHeight
            + PopoverCopyLayout.helpHeightPoints
            + segmentRowHeight
            + inset
        let thermalHeight =
            inset
            + titleRowHeight
            + PopoverCopyLayout.helpHeightPoints
            + switchRowHeight
            + inset
        let notifEnableHeight =
            inset
            + titleRowHeight
            + PopoverCopyLayout.notifEnableHelpHeightPoints
            + switchRowHeight
            + inset
        let notifDiscordHeight =
            inset
            + titleRowHeight
            + PopoverCopyLayout.helpHeightPoints
            + secretFieldRowHeight
            + PopoverCopyLayout.notifDiscordStatusHeightPoints
            + inset
        let notifTelegramHeight =
            inset
            + titleRowHeight
            + PopoverCopyLayout.notifTelegramHelpHeightPoints
            + 2 * secretFieldRowHeight
            + inset
        let notifDiscordInboundHeight =
            inset
            + titleRowHeight
            + PopoverCopyLayout.notifDiscordInboundHelpHeightPoints
            + 2 * secretFieldRowHeight
            + switchRowHeight
            + inset
        let notifTelegramInboundHeight =
            inset
            + titleRowHeight
            + PopoverCopyLayout.notifTelegramInboundHelpHeightPoints
            + switchRowHeight
            + inset
        let notifSetupHeight =
            inset
            + titleRowHeight
            + PopoverCopyLayout.notifSetupHelpHeightPoints
            + inset

        func height(for card: PopoverCard) -> Int {
            switch card {
            case .watch: return watchHeight
            case .duration: return durationCardHeight
            case .lastWatchEnd: return inset + PopoverCopyLayout.lastWatchEndHeightPoints + inset
            case .panelPower:
                var height =
                    inset
                    + segmentRowHeight
                    + PopoverCopyLayout.panelPowerCaptionHeightPoints
                    + inset
                if !PanelPowerChrome.showsLidOpenRamp(panelPowerMode) {
                    height += PopoverCopyLayout.panelPowerHelpHeightPoints
                }
                return height
            case .hygiene: return hygieneHeight
            case .battery: return batteryCardHeight
            case .agentInclude: return includeHeight
            case .settle: return settleHeight
            case .ramp: return rampHeight
            case .thermal: return thermalHeight
            case .login: return loginCardHeight
            case .notifEnable: return notifEnableHeight
            case .notifDiscord: return notifDiscordHeight
            case .notifDiscordInbound: return notifDiscordInboundHeight
            case .notifTelegram: return notifTelegramHeight
            case .notifTelegramInbound: return notifTelegramInboundHeight
            case .notifSetup: return notifSetupHeight
            case .notifClear: return loginCardHeight
            }
        }

        var cursor = firstCardY
        func place(_ height: Int) -> PopoverSlot {
            let slot = PopoverSlot(y: cursor, height: height)
            cursor += height + cardGap
            return slot
        }

        var placed: [PopoverCard: PopoverSlot] = [:]
        for card in section.cards {
            if card == .ramp, !PanelPowerChrome.showsLidOpenRamp(panelPowerMode) {
                continue
            }
            placed[card] = place(height(for: card))
        }

        var shortcutY: Int?
        var hotkeyHint: PopoverSlot?
        var quitY: Int?
        let contentHeight: Int
        if section == .general, let login = placed[.login] {
            shortcutY = login.maxY + cardGap
            let hint = PopoverSlot(
                y: shortcutY! + 26,
                height: PopoverCopyLayout.hotkeyHintHeightPoints
            )
            hotkeyHint = hint
            quitY = hint.maxY + 10
            contentHeight = quitY! + quitReserve
        } else if let last = section.cards.last.flatMap({ placed[$0] }) {
            contentHeight = last.maxY + pad
        } else {
            contentHeight = firstCardY + pad
        }

        let popoverHeight = min(contentHeight, maxVisibleHeight)
        return PopoverStackLayout(
            section: section,
            sectionSwitcher: PopoverSlot(y: sectionSwitcherY, height: sectionSwitcherHeight),
            watch: placed[.watch],
            duration: placed[.duration],
            lastWatchEnd: placed[.lastWatchEnd],
            panelPower: placed[.panelPower],
            hygiene: placed[.hygiene],
            battery: placed[.battery],
            agentInclude: placed[.agentInclude],
            settle: placed[.settle],
            ramp: placed[.ramp],
            thermal: placed[.thermal],
            login: placed[.login],
            notifEnable: placed[.notifEnable],
            notifDiscord: placed[.notifDiscord],
            notifDiscordInbound: placed[.notifDiscordInbound],
            notifTelegram: placed[.notifTelegram],
            notifTelegramInbound: placed[.notifTelegramInbound],
            notifSetup: placed[.notifSetup],
            notifClear: placed[.notifClear],
            shortcutY: shortcutY,
            hotkeyHint: hotkeyHint,
            quitY: quitY,
            contentHeight: contentHeight,
            popoverHeight: popoverHeight
        )
    }
}
