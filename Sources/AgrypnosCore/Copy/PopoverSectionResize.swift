/// Section-switch size. AppKit animates `NSPopover.contentSize` from this plan.
/// Ease-in-out, not a bounce spring. Cards keep their own frames — no stretch.
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
    public let clipsOutgoingUntilComplete: Bool
    public let hidesOutgoingImmediately: Bool
    public let incomingCards: [PopoverCard]
    public let outgoingCards: [PopoverCard]
    public let documentHeightDuringMotion: Int

    public static func make(
        from: PopoverSection,
        to: PopoverSection,
        animated: Bool
    ) -> PopoverSectionResize {
        let fromLayout = PopoverStackLayout.make(section: from)
        let toLayout = PopoverStackLayout.make(section: to)
        let fromHeight = fromLayout.popoverHeight
        let toHeight = toLayout.popoverHeight
        let fromContentHeight = fromLayout.contentHeight
        let toContentHeight = toLayout.contentHeight
        let animatesHeight = animated && from != to && fromHeight != toHeight
        let clipsOutgoing = animatesHeight && toHeight < fromHeight
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
            clipsOutgoingUntilComplete: clipsOutgoing,
            hidesOutgoingImmediately: !clipsOutgoing,
            incomingCards: to.cards,
            outgoingCards: from.cards,
            documentHeightDuringMotion: clipsOutgoing
                ? max(fromContentHeight, toContentHeight)
                : toContentHeight
        )
    }
}
