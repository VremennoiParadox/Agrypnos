import Foundation
import Darwin
#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

struct OpenCodeBridgeConnectionID: Hashable { let value = UUID() }
struct OpenCodeBridgeConfiguration {
    let socketURL: URL
    let token: String
    let generation: UUID
}

@MainActor
final class OpenCodeBridgeSocket {
    private let worker: OpenCodeSocketWorker
    init(configuration: OpenCodeBridgeConfiguration,
         receive: @escaping (OpenCodeBridgeConnectionID, OpenCodeBridgeMessage) -> Void,
         disconnected: @escaping (OpenCodeBridgeConnectionID) -> Void) {
        worker = OpenCodeSocketWorker(configuration: configuration, receive: { id, message, completed in
            Task { @MainActor in receive(id, message); completed() }
        }, disconnected: { id, completed in Task { @MainActor in disconnected(id); completed() } })
    }
    func start() throws { try worker.start() }
    func send(_ message: OpenCodeBridgeMessage, to id: OpenCodeBridgeConnectionID) async -> Bool {
        guard let frame = try? message.encodedFrame() else { return false }
        let worker = worker
        return await withCheckedContinuation { continuation in
            worker.queue.async { continuation.resume(returning: worker.enqueue(frame, to: id)) }
        }
    }
    func stop() { worker.stop() }
    deinit { worker.stop() }
}

private final class OpenCodeSocketWorker {
    final class Client {
        let fd: Int32
        let id = OpenCodeBridgeConnectionID()
        var decoder = OpenCodeBridgeFrameDecoder()
        var authenticated = false
        var input: DispatchSourceRead?
        var output: DispatchSourceWrite?
        var pending = Data()
        var deliveries: [(OpenCodeBridgeMessage, Int)] = []
        var deliveryBytes = 0
        var delivering = false
        var closed = false
        init(_ fd: Int32) { self.fd = fd }
    }
    let queue = DispatchQueue(label: "Agrypnos.OpenCode.IPC")
    private let configuration: OpenCodeBridgeConfiguration
    private let receive: (OpenCodeBridgeConnectionID, OpenCodeBridgeMessage, @escaping () -> Void) -> Void
    private let disconnected: (OpenCodeBridgeConnectionID, @escaping () -> Void) -> Void
    private var listener: DispatchSourceRead?
    private var clients: [OpenCodeBridgeConnectionID: Client] = [:]
    private var bound = false

    init(configuration: OpenCodeBridgeConfiguration,
         receive: @escaping (OpenCodeBridgeConnectionID, OpenCodeBridgeMessage, @escaping () -> Void) -> Void,
         disconnected: @escaping (OpenCodeBridgeConnectionID, @escaping () -> Void) -> Void) {
        self.configuration = configuration; self.receive = receive; self.disconnected = disconnected
    }
    func start() throws {
        try queue.sync {
            guard listener == nil else { return }
            let url = configuration.socketURL
            close(try OpenCodePrivateFiles.directory(url.deletingLastPathComponent(), privateOnly: true))
            var address = sockaddr_un()
            let path = Array(url.path.utf8) + [0]
            guard path.count <= MemoryLayout.size(ofValue: address.sun_path), configuration.token.count >= 32 else {
                throw OpenCodePluginSetupError.unsafePath
            }
            var info = stat()
            // Unique per-generation paths: never unlink somebody else's listener, even if owned by this user.
            guard lstat(url.path, &info) != 0, errno == ENOENT else { throw OpenCodePluginSetupError.unsafePath }
            address.sun_family = sa_family_t(AF_UNIX)
            address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
            withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: path) }
            let fd = socket(AF_UNIX, SOCK_STREAM, 0)
            guard fd >= 0 else { throw OpenCodePluginSetupError.writeFailed }
            var success = false
            defer { if !success { close(fd); if bound { unlink(url.path); bound = false } } }
            // BSD bind applies the containing directory's protection; chmod before accepting clients.
            let result = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
            }
            guard result == 0 else { throw OpenCodePluginSetupError.writeFailed }
            bound = true
            guard chmod(url.path, 0o600) == 0, listen(fd, 32) == 0 else { throw OpenCodePluginSetupError.writeFailed }
            configure(fd)
            let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
            source.setEventHandler { [weak self] in self?.acceptClients(fd) }
            source.setCancelHandler { close(fd) }
            listener = source; source.resume(); success = true
        }
    }
    private func configure(_ fd: Int32) {
        _ = fcntl(fd, F_SETFL, O_NONBLOCK)
        var enabled: Int32 = 1
        _ = setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &enabled, socklen_t(MemoryLayout<Int32>.size))
    }
    private func acceptClients(_ listenerFD: Int32) {
        while true {
            let fd = accept(listenerFD, nil, nil)
            guard fd >= 0 else { return }
            var uid = uid_t(), gid = gid_t()
            guard clients.count < 32, getpeereid(fd, &uid, &gid) == 0, uid == getuid() else { close(fd); continue }
            configure(fd)
            let client = Client(fd); clients[client.id] = client
            let input = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
            input.setEventHandler { [weak self, weak client] in if let client { self?.read(client) } }
            input.setCancelHandler { close(fd) }
            client.input = input; input.resume()
            queue.asyncAfter(deadline: .now() + 2) { [weak self, weak client] in
                if let client, !client.authenticated { self?.disconnect(client.id) }
            }
        }
    }
    private func read(_ client: Client) {
        var buffer = [UInt8](repeating: 0, count: 8192)
        while !client.closed {
            let count = Darwin.read(client.fd, &buffer, buffer.count)
            if count < 0, errno == EAGAIN { return }
            guard count > 0 else { disconnect(client.id); return }
            do {
                for message in try client.decoder.append(Data(buffer.prefix(count))) {
                    guard !client.closed else { return }
                    if !client.authenticated {
                        guard case let .hello(version, token, _, generation, host, _, _) = message,
                              version == 1, token == configuration.token,
                              generation == configuration.generation, host == "1.18.32" else { disconnect(client.id); return }
                        client.authenticated = true
                        _ = enqueue(try OpenCodeBridgeMessage.ready(generation: generation).encodedFrame(), to: client.id)
                    } else if case .hello = message { disconnect(client.id); return }
                    let bytes = try message.encodedFrame().count
                    guard client.deliveries.count < 64, client.deliveryBytes + bytes <= 262144 else {
                        disconnect(client.id); return
                    }
                    client.deliveries.append((message, bytes)); client.deliveryBytes += bytes
                    deliverNext(client)
                }
            } catch { disconnect(client.id); return }
        }
    }
    func enqueue(_ data: Data, to id: OpenCodeBridgeConnectionID) -> Bool {
        guard let client = clients[id], !client.closed, client.authenticated else { return false }
        guard client.pending.count + data.count <= 262144 else { disconnect(id); return false }
        client.pending.append(data)
        flush(client)
        return !client.closed
    }
    private func flush(_ client: Client) {
        while !client.pending.isEmpty {
            let sent = client.pending.withUnsafeBytes { Darwin.write(client.fd, $0.baseAddress!, $0.count) }
            if sent < 0, errno == EAGAIN {
                if client.output == nil {
                    let source = DispatchSource.makeWriteSource(fileDescriptor: client.fd, queue: queue)
                    source.setEventHandler { [weak self, weak client] in if let client { self?.flush(client) } }
                    client.output = source; source.resume()
                }
                return
            }
            guard sent > 0 else { disconnect(client.id); return }
            client.pending.removeFirst(sent)
        }
        client.output?.cancel(); client.output = nil
    }
    private func deliverNext(_ client: Client) {
        guard !client.delivering else { return }
        if client.closed {
            client.delivering = true
            // Retain this slot until the UI acknowledges disconnect, bounding reconnect churn too.
            disconnected(client.id) { [weak self] in
                self?.queue.async { self?.clients.removeValue(forKey: client.id) }
            }
            return
        }
        guard let (message, bytes) = client.deliveries.first else { return }
        client.delivering = true
        receive(client.id, message) { [weak self] in
            self?.queue.async {
                client.delivering = false
                if !client.closed {
                    client.deliveries.removeFirst(); client.deliveryBytes -= bytes
                }
                self?.deliverNext(client)
            }
        }
    }
    private func disconnect(_ id: OpenCodeBridgeConnectionID) {
        guard let client = clients[id], !client.closed else { return }
        client.closed = true
        client.output?.cancel(); client.input?.cancel()
        client.deliveries.removeAll(); client.deliveryBytes = 0
        deliverNext(client)
    }
    func stop() {
        queue.sync {
            for id in Array(clients.keys) { disconnect(id) }
            listener?.cancel(); listener = nil
            if bound { unlink(configuration.socketURL.path); bound = false }
        }
    }
}
