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

    /// Naked keys and Shift-only chords steal typing. Option, Command, or Control required.
    public var isBindable: Bool {
        option || command || control
    }

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
        Self.labels[keyCode] ?? "?"
    }

    private static let labels: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 25: "9", 26: "7", 28: "8", 29: "0",
        31: "O", 32: "U", 34: "I", 35: "P", 37: "L", 38: "J", 40: "K",
        45: "N", 46: "M", 49: "Space",
    ]
}
