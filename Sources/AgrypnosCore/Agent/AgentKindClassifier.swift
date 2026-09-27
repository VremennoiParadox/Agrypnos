public enum AgentKindClassifier: Sendable {
    public static func classify(processName: String) -> AgentKind? {
        let lowered = processName.lowercased()
        let n = basename(processName)
        if n == "cursor-agent" || n.hasPrefix("cursor-agent") { return .cursor }
        if n == "cursor" || n.hasPrefix("cursor") { return .cursor }

        if isClaudeDesktop(lowered) { return nil }

        if isClaudeCodeCLI(basename: n, loweredCommand: lowered) { return .claudeCode }
        if n == "codex" || n.hasPrefix("codex") { return .codex }
        if isCodexNodeWrapper(basename: n, loweredCommand: lowered) { return .codex }

        if isOpenCodeDesktop(basename: n, loweredCommand: lowered) { return nil }
        if isOpenCodeCLI(basename: n, loweredCommand: lowered) { return .openCode }
        return nil
    }

    static func basename(_ processName: String) -> String {
        let trimmed = processName.trimmingCharacters(in: .whitespaces)
        let first = trimmed.split(whereSeparator: { $0 == " " || $0 == "\t" }).first.map(String.init) ?? trimmed
        let slash = first.lastIndex(of: "/")
        let name = slash.map { String(first[$0...].dropFirst()) } ?? first
        return name.lowercased()
    }

    public static func cpuCountsTowardBusy(processName: String) -> Bool {
        switch classify(processName: processName) {
        case .claudeCode, .codex:
            return true
        case .cursor, .openCode, .none:
            return false
        }
    }

    static func isClaudeDesktop(_ lowered: String) -> Bool {
        if lowered.contains("claude helper") { return true }
        if lowered.contains(".app/") && lowered.contains("claude") { return true }
        return false
    }

    static func isClaudeCodeCLI(basename n: String, loweredCommand: String) -> Bool {
        if loweredCommand.contains("claude helper") { return false }
        if n == "claude" { return true }
        if n.hasPrefix("claude") { return true }
        if n == "node" || n == "nodejs" {
            return loweredCommand.contains("@anthropic-ai/claude")
                || loweredCommand.contains("claude-code")
        }
        return false
    }

    static func isCodexNodeWrapper(basename n: String, loweredCommand: String) -> Bool {
        guard n == "node" || n == "nodejs" else { return false }
        return invokesCLI(loweredCommand, name: "codex")
    }

    static func isOpenCodeDesktop(basename n: String, loweredCommand: String) -> Bool {
        if n == "opencode-cli" || n.hasPrefix("opencode-cli") { return false }
        if loweredCommand.contains("opencode helper") { return true }
        if loweredCommand.contains(".app/") && loweredCommand.contains("opencode") { return true }
        return false
    }

    static func isOpenCodeCLI(basename n: String, loweredCommand: String) -> Bool {
        if n == "opencode" || n.hasPrefix("opencode") { return true }
        if n == "node" || n == "nodejs" || n == "bun" {
            return invokesCLI(loweredCommand, name: "opencode")
        }
        return false
    }

    /// CLI install path or a token whose basename is exactly `name`. Not a longer segment.
    static func invokesCLI(_ loweredCommand: String, name: String) -> Bool {
        let tokens = loweredCommand.split(whereSeparator: \.isWhitespace)
        for token in tokens {
            let parts = token.split(separator: "/").map(String.init)
            if parts.last == name { return true }
            if let i = parts.firstIndex(of: name), i + 1 < parts.count, parts[i + 1] == "bin" {
                return true
            }
        }
        return false
    }
}
