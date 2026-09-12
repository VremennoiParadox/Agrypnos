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

/// What the runtime should persist, register, and say after a recorder attempt.
public struct HotkeyRemapPlan: Equatable, Sendable {
    public var persist: Bool
    public var chordToRegister: HotkeyChord
    public var failedAttempt: HotkeyChord?
    public var hint: String?

    public init(
        persist: Bool,
        chordToRegister: HotkeyChord,
        failedAttempt: HotkeyChord?,
        hint: String?
    ) {
        self.persist = persist
        self.chordToRegister = chordToRegister
        self.failedAttempt = failedAttempt
        self.hint = hint
    }

    public static func make(
        attempted: HotkeyChord,
        previous: HotkeyChord,
        osRegistered: Bool
    ) -> HotkeyRemapPlan {
        let resolved = HotkeyBindPolicy.resolve(
            attempted: attempted,
            previous: previous,
            registered: osRegistered
        )
        if resolved.shouldPersist {
            return HotkeyRemapPlan(
                persist: true,
                chordToRegister: resolved.chord,
                failedAttempt: nil,
                hint: nil
            )
        }
        return HotkeyRemapPlan(
            persist: false,
            chordToRegister: resolved.chord,
            failedAttempt: attempted,
            hint: AgrypnosCopy.hotkeyHint(attempted, registered: false)
        )
    }
}
