import Foundation

public enum SessionFileLayout: Sendable {
    public static func roots(home: URL, env: [String: String] = [:]) -> [AgentKind: [URL]] {
        let claudeHome = path(env["CLAUDE_CONFIG_DIR"]) ?? home.appendingPathComponent(".claude")
        let codexHome = path(env["CODEX_HOME"]) ?? home.appendingPathComponent(".codex")
        let dataHome = path(env["XDG_DATA_HOME"]) ?? home.appendingPathComponent(".local/share")
        let openCodeHome = dataHome.appendingPathComponent("opencode")

        var cursorRoots = [
            home.appendingPathComponent(".cursor/projects"),
            home.appendingPathComponent(".cursor/chats"),
            home.appendingPathComponent(".cursor/acp-sessions"),
        ]
        if let xdg = env["XDG_CONFIG_HOME"], !xdg.isEmpty {
            let base = URL(fileURLWithPath: xdg).appendingPathComponent("cursor")
            cursorRoots.append(contentsOf: [
                base.appendingPathComponent("chats"),
                base.appendingPathComponent("projects"),
                base.appendingPathComponent("acp-sessions"),
            ])
        }

        return [
            .claudeCode: [claudeHome.appendingPathComponent("projects")],
            .codex: [codexHome.appendingPathComponent("sessions")],
            .cursor: cursorRoots,
            .openCode: [
                // Official docs: ~/.local/share/opencode (XDG_DATA_HOME). Sessions live under
                // project/<slug>/storage, legacy storage/, and a data-root .db. Prove on a Mac.
                openCodeHome,
            ],
        ]
    }

    public static func classify(_ url: URL) -> AgentKind? {
        let p = url.path
        if p.contains("/.claude/") { return .claudeCode }
        if p.contains("/.codex/") { return .codex }
        if p.contains("/.cursor/") || p.contains("/cursor/chats") || p.contains("/cursor/projects") {
            return .cursor
        }
        if p.contains("/.config/opencode/") { return nil }
        if p.contains("/opencode/") { return .openCode }
        return nil
    }

    public static func isRelevantFile(_ url: URL, kind: AgentKind) -> Bool {
        let ext = url.pathExtension.lowercased()
        let name = url.lastPathComponent
        switch kind {
        case .claudeCode:
            return ext == "jsonl"
        case .codex:
            return ext == "jsonl" && name.hasPrefix("rollout-")
        case .cursor:
            if name == "store.db" || name == "meta.json" { return true }
            let path = url.path
            let inAgentTree =
                path.contains("agent-transcripts")
                || path.contains("/chats/")
                || path.contains("acp-sessions")
                || path.contains("/terminals/")
            return inAgentTree && (ext == "jsonl" || ext == "json" || ext == "txt" || ext == "db")
        case .openCode:
            return isOpenCodeSessionFile(url)
        }
    }

    static func isOpenCodeSessionFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        let name = url.lastPathComponent.lowercased()
        let path = url.path
        if name == "auth.json" { return false }
        if path.contains("/log/") || name.hasSuffix(".log") { return false }
        if path.contains("/.config/opencode/") { return false }
        guard path.contains("/opencode/") else { return false }
        return ext == "json" || ext == "jsonl" || ext == "db"
    }

    public static func isSubagentSessionPath(_ url: URL) -> Bool {
        url.path.contains("/subagents/")
    }

    public static let cursorSubtreeNames = ["agent-transcripts", "terminals"]

    public static func shouldSkipDirectory(_ name: String) -> Bool {
        let n = name.lowercased()
        if n == "node_modules" || n == ".git" || n == "log" { return true }
        if n.hasPrefix(".") && n != ".cursor" { return true }
        return false
    }

    public static func cursorWalkRoots(projectsRoot: URL, projectNames: [String]) -> [URL] {
        projectNames.flatMap { name in
            cursorSubtreeNames.map { projectsRoot.appendingPathComponent(name).appendingPathComponent($0) }
        }
    }

    private static func path(_ raw: String?) -> URL? {
        guard let raw, !raw.isEmpty else { return nil }
        return URL(fileURLWithPath: raw)
    }
}
