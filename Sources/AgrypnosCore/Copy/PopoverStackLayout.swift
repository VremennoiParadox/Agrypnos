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

    public let section: PopoverSection
    public let sectionSwitcher: PopoverSlot
    public let watch: PopoverSlot?
    public let duration: PopoverSlot?
    public let hygiene: PopoverSlot?
    public let battery: PopoverSlot?
    public let settle: PopoverSlot?
    public let ramp: PopoverSlot?
    public let thermal: PopoverSlot?
    public let login: PopoverSlot?
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
        case .hygiene: return hygiene
        case .battery: return battery
        case .settle: return settle
        case .ramp: return ramp
        case .thermal: return thermal
        case .login: return login
        }
    }

    public static func make(section: PopoverSection = .default) -> PopoverStackLayout {
        let watchHeight = inset + 28 + PopoverCopyLayout.captionHeightPoints + inset
        let hygieneHeight =
            hygieneKeyboardY
            + 2 * switchRowHeight
            + PopoverCopyLayout.helpHeightPoints
            + sliderBlockHeight
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

        func height(for card: PopoverCard) -> Int {
            switch card {
            case .watch: return watchHeight
            case .duration: return durationCardHeight
            case .hygiene: return hygieneHeight
            case .battery: return batteryCardHeight
            case .settle: return settleHeight
            case .ramp: return rampHeight
            case .thermal: return thermalHeight
            case .login: return loginCardHeight
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
            hygiene: placed[.hygiene],
            battery: placed[.battery],
            settle: placed[.settle],
            ramp: placed[.ramp],
            thermal: placed[.thermal],
            login: placed[.login],
            shortcutY: shortcutY,
            hotkeyHint: hotkeyHint,
            quitY: quitY,
            contentHeight: contentHeight,
            popoverHeight: popoverHeight
        )
    }
}
