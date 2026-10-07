import Foundation
import Darwin
#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

@MainActor
final class CodexAlertHookSource {
    typealias Receive = @MainActor (Data) -> Void
    private let socketURL: URL
    private let receive: Receive
    private var listener: DispatchSourceRead?
    private var bound = false

    init(socketURL: URL, receive: @escaping Receive) {
        self.socketURL = socketURL
        self.receive = receive
    }

    func start() throws {
        let fd = try LocalHookSocket.listen(url: socketURL)
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
        guard let stdin = try? LocalHookSocket.readAll(fd) else { return }
        receive(stdin)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        if bound { unlink(socketURL.path); bound = false }
    }
}
