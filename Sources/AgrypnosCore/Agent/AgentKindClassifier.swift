public enum AgentKindClassifier: Sendable {
    public static func classify(processName: String) -> AgentKind? {
        let n = processName.lowercased()
        if n == "cursor" || n.hasPrefix("cursor helper") {
            return .cursor
        }
        if n == "claude" || n.hasPrefix("claude ") {
            return .claudeCode
        }
        if n == "codex" || n.hasPrefix("codex-") || n.hasPrefix("codex ") {
            return .codex
        }
        return nil
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
