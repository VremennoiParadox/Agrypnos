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
        let fd: Int32
        do { fd = try LocalHookSocket.listen(url: socketURL) }
        catch { throw ClaudeAskUserQuestionPayload.Error.invalidRequest }
        bound = true
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .main)
        source.setEventHandler { [weak self] in self?.accept(fd) }
        source.setCancelHandler { close(fd) }
        listener = source
        source.resume()
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
