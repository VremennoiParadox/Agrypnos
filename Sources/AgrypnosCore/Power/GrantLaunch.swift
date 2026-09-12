public enum GrantLaunch: Sendable {
    /// Admin osascript for the sudoers grant. Nil if username or script path would widen the command.
    public static func osascriptSource(username: String, scriptPath: String) -> String? {
        guard SudoersGrant.isSafeUsername(username) else { return nil }
        guard isSafeScriptPath(scriptPath) else { return nil }
        let shell = "AGRYPNOS_USER='\(username)' /bin/bash '\(scriptPath)' --yes"
        let escaped = shell
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "do shell script \"\(escaped)\" with administrator privileges"
    }

    static func isSafeScriptPath(_ path: String) -> Bool {
        guard !path.isEmpty else { return false }
        return !path.contains("'")
            && !path.contains("\"")
            && !path.contains("\\")
            && !path.contains("\n")
            && !path.contains("\r")
    }
}
