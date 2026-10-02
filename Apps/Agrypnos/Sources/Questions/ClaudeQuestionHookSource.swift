import Foundation
import Darwin
#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

@MainActor
final class ClaudeQuestionHookSource {
    typealias Submit = @MainActor (QuestionAnswer) async -> QuestionDelivery
    typealias ReturnLocal = @MainActor () async -> Void
    typealias Receive = @MainActor (QuestionBatch, @escaping Submit, @escaping ReturnLocal) -> Bool
    private let socketURL: URL
    private let uptime: () -> TimeInterval
    private let receive: Receive
    private var listener: DispatchSourceRead?
    private var bound = false
    init(socketURL: URL, uptime: @escaping () -> TimeInterval, receive: @escaping Receive) {
        self.socketURL = socketURL; self.uptime = uptime; self.receive = receive
    }
    func start() throws {
        close(try OpenCodePrivateFiles.directory(socketURL.deletingLastPathComponent(), privateOnly: true))
        var info = stat()
        if lstat(socketURL.path, &info) == 0 {
            guard (info.st_mode & S_IFMT) == S_IFSOCK, info.st_uid == getuid() else {
                throw ClaudeAskUserQuestionPayload.Error.invalidRequest
            }
            unlink(socketURL.path)
        }
        var address = sockaddr_un()
        let path = Array(socketURL.path.utf8) + [0]
        guard path.count <= MemoryLayout.size(ofValue: address.sun_path) else {
            throw ClaudeAskUserQuestionPayload.Error.invalidRequest
        }
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: path) }
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw ClaudeAskUserQuestionPayload.Error.invalidRequest }
        var ok = false
        defer { if !ok { close(fd); if bound { unlink(socketURL.path); bound = false } } }
        let bindOK = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindOK == 0 else { throw ClaudeAskUserQuestionPayload.Error.invalidRequest }
        bound = true
        guard chmod(socketURL.path, 0o600) == 0, listen(fd, 8) == 0 else {
            throw ClaudeAskUserQuestionPayload.Error.invalidRequest
        }
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .main)
        source.setEventHandler { [weak self] in self?.accept(fd) }
        source.setCancelHandler { close(fd) }
        listener = source; source.resume(); ok = true
    }
    private func accept(_ listenerFD: Int32) {
        let client = Darwin.accept(listenerFD, nil, nil)
        guard client >= 0 else { return }
        var uid = uid_t(), gid = gid_t()
        guard getpeereid(client, &uid, &gid) == 0, uid == getuid() else { close(client); return }
        Task { @MainActor in await self.serve(client) }
    }
    private func serve(_ fd: Int32) async {
        defer { close(fd) }
        var stdin = Data()
        var buffer = [UInt8](repeating: 0, count: 8192)
        while true {
            let n = Darwin.read(fd, &buffer, buffer.count)
            if n == 0 { break }
            guard n > 0 else { return }
            stdin.append(buffer, count: n)
            guard stdin.count <= 256 * 1024 else { return }
        }
        guard let batch = try? ClaudeAskUserQuestionPayload.decode(stdin, receivedUptime: uptime()) else {
            _ = Darwin.write(fd, (ClaudeAskUserQuestionPayload.nativeFallback as NSData).bytes,
                ClaudeAskUserQuestionPayload.nativeFallback.count)
            return
        }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            var resumed = false
            func finish(_ body: Data) {
                guard !resumed else { return }
                resumed = true
                _ = body.withUnsafeBytes { Darwin.write(fd, $0.baseAddress!, body.count) }
                cont.resume()
            }
            let submitted = receive(batch, { answer in
                let body = (try? ClaudeAskUserQuestionPayload.stdout(original: stdin, answer: answer))
                    ?? ClaudeAskUserQuestionPayload.nativeFallback
                finish(body)
                return .returnedToHook
            }, {
                finish(ClaudeAskUserQuestionPayload.nativeFallback)
            })
            if !submitted {
                finish(ClaudeAskUserQuestionPayload.nativeFallback)
            }
        }
    }
    func stop() {
        listener?.cancel(); listener = nil
        if bound { unlink(socketURL.path); bound = false }
    }
}
