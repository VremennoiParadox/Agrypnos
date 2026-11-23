import AppKit

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

/// Collapsible help: each card shows one short line, and its chevron swaps in the full help.
/// The cards it covers are `PopoverHelp.cards`. Which ones are open is remembered.
extension PopoverController {
    static let expandedHelpKey = "agrypnos.popover.expandedHelp"

    static func loadExpandedHelp() -> Set<PopoverCard> {
        let saved = Set(UserDefaults.standard.stringArray(forKey: expandedHelpKey) ?? [])
        return PopoverHelp.cards.filter { saved.contains("\($0)") }
    }

    func saveExpandedHelp() {
        UserDefaults.standard.set(expandedHelp.map { "\($0)" }.sorted(), forKey: Self.expandedHelpKey)
    }

    /// Short line plus chevron at `y`. Controls below it move down when the card opens.
    @discardableResult
    func addCollapsibleHelp(_ help: PopoverCard, in card: CardView, y: CGFloat, ci: CGFloat, cw: CGFloat) -> NSTextField {
        let short = PopoverHelp.short(help)
        let label = PopoverForm.help(short, in: card, y: y, x: ci,
                                     width: cw - CGFloat(PopoverHelp.chevronWidthPoints),
                                     lines: PopoverHelp.lines(short))
        addHelpChevron(help, in: card, label: label, ci: ci, cw: cw)
        return label
    }

    func addHelpChevron(_ help: PopoverCard, in card: CardView, label: NSTextField, ci: CGFloat, cw: CGFloat) {
        let chevron = NSButton(image: Self.chevronImage(expanded: false) ?? NSImage(),
                               target: self, action: #selector(helpChevronTapped(_:)))
        chevron.isBordered = false
        chevron.imagePosition = .imageOnly
        chevron.contentTintColor = .tertiaryLabelColor
        chevron.frame = NSRect(x: ci + cw - 16, y: label.frame.minY, width: 16, height: 16)
        chevron.setAccessibilityLabel("Show details")
        card.addSubview(chevron)
        card.clipsToBounds = true   // the full help opens and closes with the card
        helpViews[help] = (label, chevron)
    }

    static func chevronImage(expanded: Bool) -> NSImage? {
        NSImage(systemSymbolName: expanded ? "chevron.up" : "chevron.down", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 10, weight: .semibold))
    }

    @objc func helpChevronTapped(_ sender: NSButton) {
        guard let help = helpViews.first(where: { $0.value.chevron === sender })?.key else { return }
        stopRecordingIfNeeded()
        if expandedHelp.contains(help) { expandedHelp.remove(help) } else { expandedHelp.insert(help) }
        saveExpandedHelp()
        applyHelpText(help)
        applySection(currentSection)
    }

    /// Swap the short line and the full help, and move whatever sits below it by the height change.
    func applyHelpText(_ help: PopoverCard) {
        guard let (label, chevron) = helpViews[help], let card = label.superview else { return }
        let expanded = expandedHelp.contains(help)
        chevron.image = Self.chevronImage(expanded: expanded)
        chevron.setAccessibilityLabel(expanded ? "Hide details" : "Show details")
        if help == .duration {
            refreshCountdown()
            return
        }
        let text = PopoverHelp.text(help, expanded: expanded)
        let height = CGFloat(PopoverHelp.lines(text) * PopoverCopyLayout.lineHeightPoints)
        let delta = height - label.frame.height
        let bottom = label.frame.maxY
        label.stringValue = text
        label.maximumNumberOfLines = 0
        label.frame.size.height = height
        for view in card.subviews where view !== label && view.frame.minY >= bottom - 0.5 {
            view.frame.origin.y += delta
        }
    }
}
