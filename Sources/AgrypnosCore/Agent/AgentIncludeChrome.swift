public enum AgentIncludeChrome: Sendable {
    public static var defaultIncluded: Set<AgentKind> { Set(AgentKind.allCases) }
    public static var titles: [String] { AgentKind.allCases.map(\.displayName) }

    /// Nil means the toggle would empty the set — reject and keep the previous selection.
    public static func toggling(_ kind: AgentKind, in included: Set<AgentKind>) -> Set<AgentKind>? {
        var next = included
        if next.contains(kind) {
            next.remove(kind)
            if next.isEmpty { return nil }
        } else {
            next.insert(kind)
        }
        return next
    }
}

struct AgentIncludeFlags: Codable {
    var cursor: Bool?
    var claudeCode: Bool?
    var codex: Bool?
    var openCode: Bool?

    init(_ kinds: Set<AgentKind>) {
        cursor = kinds.contains(.cursor)
        claudeCode = kinds.contains(.claudeCode)
        codex = kinds.contains(.codex)
        openCode = kinds.contains(.openCode)
    }

    func asSet() -> Set<AgentKind> {
        var result: Set<AgentKind> = []
        if cursor ?? true { result.insert(.cursor) }
        if claudeCode ?? true { result.insert(.claudeCode) }
        if codex ?? true { result.insert(.codex) }
        if openCode ?? true { result.insert(.openCode) }
        return UserPreferences.clampIncludedAgentKinds(result)
    }

    static func decode(from container: KeyedDecodingContainer<UserPreferences.CodingKeys>) throws -> Set<AgentKind> {
        guard container.contains(.includedAgentKinds) else {
            return AgentIncludeChrome.defaultIncluded
        }
        if let flags = try? container.decode(AgentIncludeFlags.self, forKey: .includedAgentKinds) {
            return flags.asSet()
        }
        if let listed = try? container.decode([AgentKind].self, forKey: .includedAgentKinds) {
            if listed.isEmpty { return AgentIncludeChrome.defaultIncluded }
            var kinds = Set(listed)
            let legacyThree: Set<AgentKind> = [.cursor, .claudeCode, .codex]
            if kinds == legacyThree { kinds.insert(.openCode) }
            return UserPreferences.clampIncludedAgentKinds(kinds)
        }
        return AgentIncludeChrome.defaultIncluded
    }
}
