import Foundation

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

struct OpenCodeQuestionConfiguration: Equatable {
    enum Error: Swift.Error { case invalidEndpoint, invalidDirectory }

    let endpoint: URL
    let directory: String
    let username: String
    let password: String

    init(endpoint: URL, directory: String, username: String = "opencode", password: String = "") throws {
        guard endpoint.scheme == "http", endpoint.host == "127.0.0.1",
              let port = endpoint.port, (1...65535).contains(port),
              endpoint.path.isEmpty || endpoint.path == "/",
              endpoint.query == nil, endpoint.fragment == nil,
              endpoint.user == nil, endpoint.password == nil, !username.isEmpty,
              !username.contains(":"), !username.contains("\n"), !username.contains("\r") else {
            throw Error.invalidEndpoint
        }
        guard directory.hasPrefix("/"), !directory.contains("\0"), directory.utf8.count <= 4096 else {
            throw Error.invalidDirectory
        }
        self.endpoint = endpoint
        self.directory = URL(fileURLWithPath: directory).standardizedFileURL.path
        self.username = username
        self.password = password
    }

    var instanceID: String { "127.0.0.1:\(endpoint.port!)|\(directory)" }

    init(_ settings: OpenCodeQuestionSettings) throws {
        guard let endpoint = URL(string: settings.endpoint) else { throw Error.invalidEndpoint }
        try self.init(endpoint: endpoint, directory: settings.directory,
            username: settings.username, password: settings.password)
    }

    func request(_ path: String, method: String = "GET", body: Data? = nil,
                 directoryQuery: Bool = false) -> URLRequest {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.path = path
        if directoryQuery { components.queryItems = [URLQueryItem(name: "directory", value: directory)] }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.httpBody = body
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if !password.isEmpty {
            let value = Data("\(username):\(password)".utf8).base64EncodedString()
            request.setValue("Basic \(value)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
}

enum OpenCodeQuestionConnectionState: Equatable {
    case stopped, connecting, connected, offline
    case unavailable(String)

    var caption: String {
        switch self {
        case .stopped: return "OpenCode: not connected."
        case .connecting: return "OpenCode: connecting…"
        case .connected: return "OpenCode 1.18.32: connected."
        case .offline: return "OpenCode: disconnected; retrying."
        case let .unavailable(reason): return "OpenCode: \(reason)"
        }
    }
}

private final class NoOpenCodeRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

@MainActor
final class OpenCodeQuestionSource {
    typealias Exchange = @MainActor (URLRequest) async -> QuestionHTTPResponse
    typealias Receive = @MainActor (QuestionBatch) -> Bool

    private struct Record {
        let batch: QuestionBatch
        let original: Data
        var active = true
        var attempted = false
        var submitting = false
    }

    private let configuration: OpenCodeQuestionConfiguration
    private let exchange: Exchange
    private let uptime: @MainActor () -> TimeInterval
    private let receive: Receive
    private let resolved: @MainActor (QuestionKey) -> Void
    private let streamSession: URLSession
    private let stateChanged: @MainActor (OpenCodeQuestionConnectionState) -> Void
    private(set) var connectionState: OpenCodeQuestionConnectionState = .stopped
    private var records: [QuestionKey: Record] = [:]
    private var seen: [QuestionKey] = []
    private var task: Task<Void, Never>?
    private var generation: UInt64 = 0
    private let sourceID = UUID()
    private var instanceID: String { "\(configuration.instanceID)#\(sourceID)" }

    init(configuration: OpenCodeQuestionConfiguration,
         exchange: Exchange? = nil,
         streamSession: URLSession? = nil,
         uptime: @escaping @MainActor () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         receive: @escaping Receive,
         resolved: @escaping @MainActor (QuestionKey) -> Void,
         stateChanged: @escaping @MainActor (OpenCodeQuestionConnectionState) -> Void = { _ in }) {
        self.configuration = configuration
        let session = streamSession ?? URLSession(configuration: .ephemeral,
            delegate: NoOpenCodeRedirects(), delegateQueue: nil)
        self.streamSession = session
        self.exchange = exchange ?? { request in
            do {
                let (body, response) = try await session.data(for: request)
                return QuestionHTTPResponse(statusCode: (response as? HTTPURLResponse)?.statusCode, body: body)
            } catch { return QuestionHTTPResponse(statusCode: nil, body: Data()) }
        }
        self.uptime = uptime
        self.receive = receive
        self.resolved = resolved
        self.stateChanged = stateChanged
    }

    func start() {
        guard task == nil else { return }
        generation &+= 1
        setState(.connecting)
        let captured = generation
        let configuration = configuration, exchange = exchange, session = streamSession
        task = Task { [weak self] in
            await Self.run(configuration: configuration, exchange: exchange, session: session,
                isCurrent: { [weak self] in self?.generation == captured },
                reconcile: { [weak self] in try self?.reconcilePending($0) },
                ingest: { [weak self] in self?.ingest($0) },
                disconnected: { [weak self] in self?.connectionLost() },
                stateChanged: { [weak self] in self?.setState($0) })
            if self?.generation == captured { self?.task = nil }
        }
    }

    deinit { task?.cancel(); streamSession.invalidateAndCancel() }

    func stop() {
        pause()
        records.removeAll()
        seen.removeAll()
    }

    func pause() {
        generation &+= 1
        task?.cancel()
        task = nil
        connectionLost()
        setState(.stopped)
    }

    private func setState(_ state: OpenCodeQuestionConnectionState) {
        guard connectionState != state else { return }
        connectionState = state
        stateChanged(state)
    }

    func returnToLocal(key: QuestionKey) {
        // Relinquish bot control without rejecting or answering the native question.
        records[key]?.active = false
        records[key]?.attempted = true
    }

    func connectionLost() {
        for (key, record) in records where record.active {
            records[key]?.active = false
            resolved(key)
        }
    }

    func ingest(_ data: Data) {
        guard let event = try? OpenCodeQuestionPayload.event(data,
            instanceID: instanceID, directory: configuration.directory,
            receivedUptime: uptime()) else { return }
        switch event {
        case let .asked(batch, original):
            if let prior = records[batch.key] {
                if prior.batch.questions != batch.questions {
                    records.removeValue(forKey: batch.key)
                    resolved(batch.key)
                }
                return
            }
            guard !seen.contains(batch.key) else { return }
            seen.append(batch.key)
            if seen.count > 256 { seen.removeFirst(seen.count - 256) }
            guard records.count < 32 else { return }
            if receive(batch) { records[batch.key] = Record(batch: batch, original: original) }
        case let .resolved(key):
            if records[key]?.submitting == true {
                // OpenCode publishes the native event before replying to our POST.
                // Only that POST's outcome distinguishes our answer from a local winner.
                records[key]?.active = false
                return
            }
            if records.removeValue(forKey: key) != nil { resolved(key) }
        }
    }

    func submit(key: QuestionKey, answer: QuestionAnswer) async -> QuestionDelivery {
        guard let record = records[key], record.active, !record.attempted,
              uptime() < record.batch.deadlineUptime,
              let body = try? OpenCodeQuestionPayload.reply(original: record.original, answer: answer,
                  instanceID: instanceID) else { return .rejected }
        records[key]?.attempted = true
        records[key]?.submitting = true
        defer {
            if records[key]?.active == false { records.removeValue(forKey: key) }
            else { records[key]?.submitting = false }
        }
        let request = configuration.request("/question/\(key.requestID)/reply", method: "POST",
            body: body, directoryQuery: true)
        let response = await exchange(request)
        guard records[key] != nil else { return .unconfirmed }
        if response.statusCode == 404 {
            records.removeValue(forKey: key)
            return .rejected
        }
        guard response.statusCode == 200,
              (try? JSONDecoder().decode(Bool.self, from: response.body)) == true else { return .unconfirmed }
        records.removeValue(forKey: key)
        return .accepted
    }

    private static func run(configuration: OpenCodeQuestionConfiguration, exchange: Exchange,
                            session: URLSession, isCurrent: () -> Bool,
                            reconcile: (Data) throws -> Void, ingest: (Data) -> Void,
                            disconnected: () -> Void,
                            stateChanged: (OpenCodeQuestionConnectionState) -> Void) async {
        var retry = 1
        while !Task.isCancelled && isCurrent() {
            do {
                let health = await serverHealth(configuration: configuration, exchange: exchange)
                guard isCurrent(), !Task.isCancelled else { break }
                if case let .unavailable(reason) = health { stateChanged(.unavailable(reason)); break }
                if health == .offline { throw OpenCodeQuestionConfiguration.Error.invalidEndpoint }
                let request = configuration.request("/global/event")
                let (bytes, response) = try await session.bytes(for: request)
                guard isCurrent(), !Task.isCancelled else { break }
                guard (response as? HTTPURLResponse)?.statusCode == 200,
                      (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type")?
                        .hasPrefix("text/event-stream") == true else {
                    stateChanged(.unavailable("Couldn't open the question event stream.")); break
                }
                let pending = await exchange(configuration.request("/question", directoryQuery: true))
                guard isCurrent(), !Task.isCancelled else { break }
                guard pending.statusCode == 200 else { throw OpenCodeQuestionConfiguration.Error.invalidEndpoint }
                try reconcile(pending.body)
                retry = 1
                stateChanged(.connected)
                var frames = OpenCodeEventFrames()
                for try await byte in bytes {
                    if Task.isCancelled || !isCurrent() { break }
                    if let frame = frames.append(byte) { ingest(frame) }
                }
            } catch { /* Reconnect below. */ }
            if isCurrent() { disconnected(); stateChanged(.offline) }
            if Task.isCancelled || !isCurrent() { break }
            try? await Task.sleep(nanoseconds: UInt64(retry) * 1_000_000_000)
            retry = min(retry * 2, 30)
        }
        if isCurrent() { disconnected() }
    }

    private enum ServerHealth: Equatable { case supported, offline, unavailable(String) }

    private static func serverHealth(configuration: OpenCodeQuestionConfiguration,
                                     exchange: Exchange) async -> ServerHealth {
        let response = await exchange(configuration.request("/global/health"))
        guard let status = response.statusCode else { return .offline }
        if status == 401 || status == 403 { return .unavailable("Server authentication failed.") }
        guard status == 200,
              let body = try? JSONSerialization.jsonObject(with: response.body) as? [String: Any],
              body["healthy"] as? Bool == true,
              body["version"] as? String == "1.18.32" else {
            return .unavailable("Requires OpenCode 1.18.32.")
        }
        return .supported
    }

    func reconcilePending(_ data: Data) throws {
        guard data.count <= 256 * 1024,
              let pending = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { throw OpenCodeQuestionConfiguration.Error.invalidEndpoint }
        var verified: [QuestionKey: QuestionBatch] = [:]
        var present: Set<QuestionKey> = []
        for record in pending {
            let data = try JSONSerialization.data(withJSONObject: record)
            let key = try OpenCodeQuestionPayload.identity(data, instanceID: instanceID)
            guard present.insert(key).inserted else { throw OpenCodeQuestionPayload.Error.invalidRequest }
            // Native questions outside the relay's content/choice limits stay local.
            if let batch = try? OpenCodeQuestionPayload.decode(data,
                instanceID: instanceID, receivedUptime: uptime()) { verified[key] = batch }
        }
        for (key, record) in records {
            guard let current = verified[key], current.questions == record.batch.questions else {
                records.removeValue(forKey: key)
                // An inactive local/expired question may still own a deferred watch-end decision.
                resolved(key)
                continue
            }
            if !record.active, !record.attempted, uptime() < record.batch.deadlineUptime,
               receive(record.batch) { records[key]?.active = true }
        }
        // Unknown pending requests predate this connection; their original deadline is unknown.
        // Only a fresh event on this stream may create bot controls for them.
    }
}
