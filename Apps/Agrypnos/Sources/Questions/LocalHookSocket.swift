import Foundation
import Darwin

enum LocalHookSocket {
    struct Failure: Error {}
    static let maxBytes = 256 * 1024

    static func connect(url: URL, timeout: TimeInterval) throws -> Int32 {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw Failure() }
        var address = try unixAddress(url)
        let deadline = Date().addingTimeInterval(timeout)
        var connected = false
        while Date() < deadline {
            let result = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
                }
            }
            if result == 0 { connected = true; break }
            usleep(50_000)
        }
        guard connected else { close(fd); throw Failure() }
        var uid = uid_t(), gid = gid_t()
        guard getpeereid(fd, &uid, &gid) == 0, uid == getuid() else { close(fd); throw Failure() }
        return fd
    }

    static func writeAll(_ fd: Int32, _ data: Data) throws {
        try data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            var sent = 0
            while sent < data.count {
                let n = Darwin.write(fd, base.advanced(by: sent), data.count - sent)
                guard n > 0 else { throw Failure() }
                sent += n
            }
        }
    }

    static func readAll(_ fd: Int32) throws -> Data {
        var out = Data()
        var buffer = [UInt8](repeating: 0, count: 8192)
        while true {
            let n = Darwin.read(fd, &buffer, buffer.count)
            if n == 0 { return out }
            guard n > 0 else { throw Failure() }
            out.append(buffer, count: n)
            guard out.count <= maxBytes else { throw Failure() }
        }
    }

    /// Caller owns the returned listening fd. Directory is 0700, socket is 0600.
    static func listen(url: URL) throws -> Int32 {
        close(try OpenCodePrivateFiles.directory(url.deletingLastPathComponent(), privateOnly: true))
        var info = stat()
        if lstat(url.path, &info) == 0 {
            guard (info.st_mode & S_IFMT) == S_IFSOCK, info.st_uid == getuid() else { throw Failure() }
            unlink(url.path)
        }
        var address = try unixAddress(url)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw Failure() }
        let bindOK = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindOK == 0 else { close(fd); throw Failure() }
        guard chmod(url.path, 0o600) == 0, Darwin.listen(fd, 8) == 0 else {
            close(fd)
            unlink(url.path)
            throw Failure()
        }
        return fd
    }

    private static func unixAddress(_ url: URL) throws -> sockaddr_un {
        var address = sockaddr_un()
        let path = Array(url.path.utf8) + [0]
        guard path.count <= MemoryLayout.size(ofValue: address.sun_path) else { throw Failure() }
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: path) }
        return address
    }
}
