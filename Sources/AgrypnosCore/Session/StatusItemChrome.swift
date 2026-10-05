import Foundation

/// Menu-bar extra: glyph plus a non-countdown title.
/// The countdown lives in the How long card; the menu bar keeps its quiet title.
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

    public var accessibilityTitle: String {
        title.isEmpty ? AgrypnosCopy.appName : "\(AgrypnosCopy.appName), \(title)"
    }

    public init(title: String, length: Length, imagePosition: ImagePosition) {
        self.title = title
        self.length = length
        self.imagePosition = imagePosition
    }

    public static func make(
        state: StatusItemState,
        remainingSeconds: Int?
    ) -> StatusItemChrome {
        _ = remainingSeconds
        let title = AgrypnosCopy.statusItemTitle(state)
        if title.isEmpty {
            return StatusItemChrome(
                title: "",
                length: .square,
                imagePosition: .imageOnly
            )
        }
        return StatusItemChrome(
            title: title,
            length: .variable,
            imagePosition: .imageLeading
        )
    }
}
