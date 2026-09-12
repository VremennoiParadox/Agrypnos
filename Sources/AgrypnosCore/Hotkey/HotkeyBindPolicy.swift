public struct HotkeyBindResolution: Equatable, Sendable {
    public var chord: HotkeyChord
    public var registered: Bool
    public var shouldPersist: Bool

    public init(chord: HotkeyChord, registered: Bool, shouldPersist: Bool) {
        self.chord = chord
        self.registered = registered
        self.shouldPersist = shouldPersist
    }
}

/// Persist a remap only after a bindable chord actually registers. Keep the previous chord otherwise.
public enum HotkeyBindPolicy: Sendable {
    public static func resolve(
        attempted: HotkeyChord,
        previous: HotkeyChord,
        registered: Bool
    ) -> HotkeyBindResolution {
        guard attempted.isBindable, registered else {
            return HotkeyBindResolution(chord: previous, registered: false, shouldPersist: false)
        }
        return HotkeyBindResolution(chord: attempted, registered: true, shouldPersist: true)
    }
}
