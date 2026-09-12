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
        Self.labels[keyCode] ?? "Key\(keyCode)"
    }

    private static let labels: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        10: "§", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9",
        26: "7", 27: "-", 28: "8", 29: "0", 30: "]",
        31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return", 37: "L", 38: "J",
        39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M",
        47: ".", 48: "Tab", 49: "Space", 50: "`", 51: "Delete",
        64: "F17", 65: "Num.", 67: "Num*", 69: "Num+", 71: "Clear",
        72: "Vol+", 73: "Vol-", 74: "Mute",
        75: "Num/", 76: "Enter", 78: "Num-", 79: "F18", 80: "F19", 81: "Num=",
        82: "Num0", 83: "Num1", 84: "Num2", 85: "Num3", 86: "Num4", 87: "Num5",
        88: "Num6", 89: "Num7", 90: "F20", 91: "Num8", 92: "Num9",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11",
        105: "F13", 106: "F16", 107: "F14", 109: "F10", 111: "F12", 113: "F15",
        114: "Help", 115: "Home", 116: "PageUp", 117: "FwdDel", 118: "F4",
        119: "End", 120: "F2", 121: "PageDown", 122: "F1",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]
}
