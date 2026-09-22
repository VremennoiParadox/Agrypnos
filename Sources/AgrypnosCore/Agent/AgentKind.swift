public enum AgentKind: String, Codable, CaseIterable, Sendable, Equatable, Hashable {
    case cursor
    case claudeCode
    case codex
    case openCode

    public var displayName: String {
        switch self {
        case .cursor: return "Cursor"
        case .claudeCode: return "Claude Code"
        case .codex: return "Codex"
        case .openCode: return "OpenCode"
        }
    }
}
