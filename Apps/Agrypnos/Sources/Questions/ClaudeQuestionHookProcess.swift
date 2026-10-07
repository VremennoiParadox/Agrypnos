import Foundation
#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

enum ClaudeQuestionHookProcess {
    static func runIfRequested() -> Bool {
        guard CommandLine.arguments.contains(ClaudeAskUserQuestionPayload.flag) else { return false }
        let stdin = FileHandle.standardInput.readDataToEndOfFile()
        let out = ClaudeAskUserQuestionPayload.helperStdout(stdin: stdin) { payload in
            try exchange(payload, socketURL: ClaudeAskUserQuestionPayload.defaultSocketURL(),
                connectTimeout: ClaudeAskUserQuestionPayload.unavailableFallbackSeconds)
        }
        FileHandle.standardOutput.write(out)
        return true
    }

    static func exchange(_ payload: Data, socketURL: URL, connectTimeout: TimeInterval) throws -> Data {
        guard payload.count <= LocalHookSocket.maxBytes else { throw ClaudeAskUserQuestionPayload.Error.invalidRequest }
        let fd: Int32
        do { fd = try LocalHookSocket.connect(url: socketURL, timeout: connectTimeout) }
        catch { throw ClaudeAskUserQuestionPayload.Error.invalidRequest }
        defer { close(fd) }
        do {
            try LocalHookSocket.writeAll(fd, payload)
            shutdown(fd, SHUT_WR)
            return try LocalHookSocket.readAll(fd)
        } catch {
            throw ClaudeAskUserQuestionPayload.Error.invalidRequest
        }
    }
}
