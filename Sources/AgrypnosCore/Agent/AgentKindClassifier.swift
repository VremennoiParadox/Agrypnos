public enum AgentKindClassifier: Sendable {
    public static func classify(processName: String) -> AgentKind? {
        let n = basename(processName)
        if n == "cursor" || n.hasPrefix("cursor") {
            return .cursor
        }
        if n == "claude" || n.hasPrefix("claude") {
            return .claudeCode
        }
        if n == "codex" || n.hasPrefix("codex") {
            return .codex
        }
        return nil
    }

    static func basename(_ processName: String) -> String {
        let trimmed = processName.trimmingCharacters(in: .whitespaces)
        let slash = trimmed.lastIndex(of: "/")
        let name = slash.map { String(trimmed[$0...].dropFirst()) } ?? trimmed
        return name.lowercased()
    }

    public static func cpuCountsTowardBusy(processName: String) -> Bool {
        switch classify(processName: processName) {
        case .claudeCode, .codex:
            return true
        case .cursor, .none:
            return false
        }
    }
}
