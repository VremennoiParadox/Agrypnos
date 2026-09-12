public enum HotkeyCapture: Equatable, Sendable {
    case ignore
    case cancel
    case chord(HotkeyChord)

    /// Carbon virtual key codes for modifier keys and Escape.
    private static let escapeKey: UInt32 = 53
    private static let modifierKeys: Set<UInt32> = [54, 55, 56, 58, 59, 60, 61, 62, 63]

    public static func from(
        keyCode: UInt32,
        option: Bool,
        command: Bool,
        shift: Bool,
        control: Bool
    ) -> HotkeyCapture {
        if keyCode == escapeKey { return .cancel }
        if modifierKeys.contains(keyCode) { return .ignore }
        return .chord(
            HotkeyChord(
                keyCode: keyCode,
                option: option,
                command: command,
                shift: shift,
                control: control
            )
        )
    }
}

public struct HotkeyRecorderChrome: Equatable, Sendable {
    public var buttonTitle: String
    public var hint: String
    public var isRecording: Bool

    public init(buttonTitle: String, hint: String, isRecording: Bool) {
        self.buttonTitle = buttonTitle
        self.hint = hint
        self.isRecording = isRecording
    }

    public static func make(
        liveChord: HotkeyChord,
        registered: Bool,
        isRecording: Bool,
        failedAttempt: HotkeyChord?
    ) -> HotkeyRecorderChrome {
        if isRecording {
            return HotkeyRecorderChrome(
                buttonTitle: AgrypnosCopy.hotkeyRecording,
                hint: AgrypnosCopy.hotkeyRecordingHint,
                isRecording: true
            )
        }
        if let failedAttempt {
            return HotkeyRecorderChrome(
                buttonTitle: liveChord.display,
                hint: AgrypnosCopy.hotkeyHint(failedAttempt, registered: false),
                isRecording: false
            )
        }
        return HotkeyRecorderChrome(
            buttonTitle: liveChord.display,
            hint: AgrypnosCopy.hotkeyHint(liveChord, registered: registered),
            isRecording: false
        )
    }
}
