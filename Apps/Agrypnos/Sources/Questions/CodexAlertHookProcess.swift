import Foundation
import Darwin
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
        _ = try? exchange(stdin, socketURL: socketURL, connectTimeout: connectTimeout)
        return Data()
    }

    private static func exchange(_ payload: Data, socketURL: URL, connectTimeout: TimeInterval) throws {
        guard payload.count <= 256 * 1024 else { return }
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return }
        defer { close(fd) }
        var address = sockaddr_un()
        let path = Array(socketURL.path.utf8) + [0]
        guard path.count <= MemoryLayout.size(ofValue: address.sun_path) else { return }
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: path) }
        let deadline = Date().addingTimeInterval(connectTimeout)
        var connected = false
        while Date() < deadline {
            let result = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
                }
            }
            if result == 0 { connected = true; break }
            usleep(50_000)
        }
        guard connected else { return }
        var uid = uid_t(), gid = gid_t()
        guard getpeereid(fd, &uid, &gid) == 0, uid == getuid() else { return }
        try writeAll(fd, payload)
        shutdown(fd, SHUT_WR)
        _ = readAll(fd)
    }

    private static func writeAll(_ fd: Int32, _ data: Data) {
        data.withUnsafeBytes { raw in
            var sent = 0
            while sent < data.count {
                let n = Darwin.write(fd, raw.baseAddress!.advanced(by: sent), data.count - sent)
                guard n > 0 else { return }
                sent += n
            }
        }
    }

    private static func readAll(_ fd: Int32) -> Data {
        var out = Data()
        var buffer = [UInt8](repeating: 0, count: 8192)
        while true {
            let n = Darwin.read(fd, &buffer, buffer.count)
            if n == 0 { return out }
            guard n > 0 else { return out }
            out.append(buffer, count: n)
            guard out.count <= 256 * 1024 else { return out }
        }
    }
}
