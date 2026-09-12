public struct HotkeyChord: Equatable, Sendable, Codable {
    public var keyCode: UInt32
    public var option: Bool
    public var command: Bool
    public var shift: Bool
    public var control: Bool

    public init(
        keyCode: UInt32,
        option: Bool,
        command: Bool,
        shift: Bool = false,
        control: Bool = false
    ) {
        self.keyCode = keyCode
        self.option = option
        self.command = command
        self.shift = shift
        self.control = control
    }

    /// Option-Command-A (ANSI A is Carbon key code 0).
    public static let defaultToggle = HotkeyChord(keyCode: 0, option: true, command: true)

    public var carbonModifiers: UInt32 {
        var value: UInt32 = 0
        if command { value |= 1 << 8 }
        if shift { value |= 1 << 9 }
        if option { value |= 1 << 11 }
        if control { value |= 1 << 12 }
        return value
    }

    public var display: String {
        var glyphs = ""
        if control { glyphs += "⌃" }
        if option { glyphs += "⌥" }
        if shift { glyphs += "⇧" }
        if command { glyphs += "⌘" }
        glyphs += Self.keyLabel(keyCode)
        return glyphs
    }

    static func keyLabel(_ keyCode: UInt32) -> String {
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 13: return "W"
        default: return "?"
        }
    }
}
