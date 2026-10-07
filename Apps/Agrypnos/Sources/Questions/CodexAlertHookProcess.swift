import Foundation
#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

enum CodexAlertHookProcess {
    static let connectTimeout: TimeInterval = 2

    static func defaultSocketURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Agrypnos/codex-alert-hook", isDirectory: true)
            .appendingPathComponent("hook.sock")
    }

    static func runIfRequested() -> Bool {
        guard CommandLine.arguments.contains(CodexAlertHook.flag) else { return false }
        let stdin = FileHandle.standardInput.readDataToEndOfFile()
        FileHandle.standardOutput.write(run(stdin: stdin, socketURL: defaultSocketURL()))
        return true
    }

    static func run(stdin: Data, socketURL: URL) -> Data {
        guard stdin.count <= LocalHookSocket.maxBytes,
              let fd = try? LocalHookSocket.connect(url: socketURL, timeout: connectTimeout) else { return Data() }
        defer { close(fd) }
        try? LocalHookSocket.writeAll(fd, stdin)
        shutdown(fd, SHUT_WR)
        _ = try? LocalHookSocket.readAll(fd)
        return Data()
    }
}
