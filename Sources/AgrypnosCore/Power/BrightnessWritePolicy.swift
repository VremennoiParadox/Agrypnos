public struct DisplayRecord: Equatable, Sendable {
    public var isBuiltIn: Bool
    public var isOnline: Bool

    public init(isBuiltIn: Bool, isOnline: Bool) {
        self.isBuiltIn = isBuiltIn
        self.isOnline = isOnline
    }
}

public enum BrightnessWritePolicy: Sendable {
    /// Only the built-in panel. One NSScreen is not a proxy: lid-closed plus
    /// an external often reports a single screen, and that screen is the external.
    public static func shouldWrite(displays: [DisplayRecord]) -> Bool {
        displays.contains { $0.isBuiltIn && $0.isOnline }
    }
}
