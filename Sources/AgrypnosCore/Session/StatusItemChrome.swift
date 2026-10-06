import Foundation

/// Fixed-size menu-bar glyph. Live state remains available to accessibility;
/// the countdown lives in the How long card.
public struct StatusItemChrome: Equatable, Sendable {
    public enum Length: Equatable, Sendable {
        case square
        case variable
    }

    public enum ImagePosition: Equatable, Sendable {
        case imageOnly
        case imageLeading
    }

    public let title: String
    public let length: Length
    public let imagePosition: ImagePosition

    public let accessibilityTitle: String

    public init(title: String, length: Length, imagePosition: ImagePosition,
                accessibilityTitle: String? = nil) {
        self.accessibilityTitle = accessibilityTitle
            ?? (title.isEmpty ? AgrypnosCopy.appName : "\(AgrypnosCopy.appName), \(title)")
        self.title = title
        self.length = length
        self.imagePosition = imagePosition
    }

    public static func make(
        state: StatusItemState,
        remainingSeconds: Int?
    ) -> StatusItemChrome {
        _ = remainingSeconds
        let stateTitle = AgrypnosCopy.statusItemTitle(state)
        return StatusItemChrome(
            title: "",
            length: .square,
            imagePosition: .imageOnly,
            accessibilityTitle: stateTitle.isEmpty
                ? AgrypnosCopy.appName : "\(AgrypnosCopy.appName), \(stateTitle)"
        )
    }
}
