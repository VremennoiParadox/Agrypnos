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
    public static let firstCardY = 42
    /// Tall enough for 14" Macs; 13" still gets a scroller instead of clipped quit.
    /// AppKit must use a flipped NSClipView and scroll the document to (0, 0) on open,
    /// or an unflipped clip shows Quit first.
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

    public let watch: PopoverSlot
    public let duration: PopoverSlot
    public let hygiene: PopoverSlot
    public let battery: PopoverSlot
    public let settle: PopoverSlot
    public let ramp: PopoverSlot
    public let login: PopoverSlot
    public let shortcutY: Int
    public let hotkeyHint: PopoverSlot
    public let quitY: Int
    public let contentHeight: Int
    public let popoverHeight: Int

    public var needsScroll: Bool { contentHeight > popoverHeight }

    public static func make() -> PopoverStackLayout {
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
            + PopoverCopyLayout.helpHeightPoints
            + sliderBlockHeight
            + inset
        let rampHeight =
            inset
            + titleRowHeight
            + PopoverCopyLayout.helpHeightPoints
            + segmentRowHeight
            + inset

        var cursor = firstCardY
        func place(_ height: Int) -> PopoverSlot {
            let slot = PopoverSlot(y: cursor, height: height)
            cursor += height + cardGap
            return slot
        }

        let watch = place(watchHeight)
        let duration = place(durationCardHeight)
        let hygiene = place(hygieneHeight)
        let battery = place(batteryCardHeight)
        let settle = place(settleHeight)
        let ramp = place(rampHeight)
        let login = place(loginCardHeight)
        let shortcutY = login.maxY + cardGap
        let hotkeyHint = PopoverSlot(
            y: shortcutY + 26,
            height: PopoverCopyLayout.hotkeyHintHeightPoints
        )
        let quitY = hotkeyHint.maxY + 10
        let contentHeight = quitY + quitReserve
        let popoverHeight = min(contentHeight, maxVisibleHeight)
        return PopoverStackLayout(
            watch: watch,
            duration: duration,
            hygiene: hygiene,
            battery: battery,
            settle: settle,
            ramp: ramp,
            login: login,
            shortcutY: shortcutY,
            hotkeyHint: hotkeyHint,
            quitY: quitY,
            contentHeight: contentHeight,
            popoverHeight: popoverHeight
        )
    }
}
