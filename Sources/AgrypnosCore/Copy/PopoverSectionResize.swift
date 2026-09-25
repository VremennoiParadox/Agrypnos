/// Section-switch size. AppKit animates `NSPopover.contentSize` from this plan.
/// Ease-in-out, not a bounce spring. Cards keep their own frames — no stretch.
/// Only the destination section is visible; never keep outgoing cards to fill glass.
public struct PopoverSectionResize: Equatable, Sendable {
    public enum Timing: Equatable, Sendable {
        case none
        case easeInEaseOut
    }

    /// AppKit's default `NSAnimationContext` duration. Apple-standard, not custom bounce.
    public static let standardDurationSeconds = 0.25

    public let from: PopoverSection
    public let to: PopoverSection
    public let fromHeight: Int
    public let toHeight: Int
    public let fromContentHeight: Int
    public let toContentHeight: Int
    public let animatesHeight: Bool
    public let durationSeconds: Double
    public let timing: Timing
    public let allowsImplicitAnimation: Bool
    public let hidesOutgoingImmediately: Bool
    public let incomingCards: [PopoverCard]
    public let outgoingCards: [PopoverCard]
    public let documentHeightDuringMotion: Int

    public static func make(
        from: PopoverSection,
        to: PopoverSection,
        animated: Bool,
        currentHeight: Int? = nil,
        panelPowerMode: PanelPowerMode = .default
    ) -> PopoverSectionResize {
        let fromLayout = PopoverStackLayout.make(section: from, panelPowerMode: panelPowerMode)
        let toLayout = PopoverStackLayout.make(section: to, panelPowerMode: panelPowerMode)
        let fromHeight = fromLayout.popoverHeight
        let toHeight = toLayout.popoverHeight
        let fromContentHeight = fromLayout.contentHeight
        let toContentHeight = toLayout.contentHeight
        // Mid-ease the window can still be the previous section's size.
        let liveHeight = currentHeight ?? fromHeight
        let animatesHeight = animated && toHeight != liveHeight
        return PopoverSectionResize(
            from: from,
            to: to,
            fromHeight: fromHeight,
            toHeight: toHeight,
            fromContentHeight: fromContentHeight,
            toContentHeight: toContentHeight,
            animatesHeight: animatesHeight,
            durationSeconds: animatesHeight ? standardDurationSeconds : 0,
            timing: animatesHeight ? .easeInEaseOut : .none,
            allowsImplicitAnimation: animatesHeight,
            hidesOutgoingImmediately: true,
            incomingCards: to.cards,
            outgoingCards: from.cards,
            documentHeightDuringMotion: toContentHeight
        )
    }
}
