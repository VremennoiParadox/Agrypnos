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
              endpoint.user == nil, endpoint.password == nil, !username.isEmpty else {
            throw Error.invalidEndpoint
        }
        guard directory.hasPrefix("/") else { throw Error.invalidDirectory }
        self.endpoint = endpoint
        self.directory = URL(fileURLWithPath: directory).standardizedFileURL.path
        self.username = username
        self.password = password
    }

    var instanceID: String { "127.0.0.1:\(endpoint.port!)|\(directory)" }

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
    }

    private let configuration: OpenCodeQuestionConfiguration
    private let exchange: Exchange
    private let uptime: @MainActor () -> TimeInterval
    private let receive: Receive
    private let resolved: @MainActor (QuestionKey) -> Void
    private let streamSession: URLSession
    private var records: [QuestionKey: Record] = [:]
    private var seen: Set<QuestionKey> = []
    private var task: Task<Void, Never>?
    private var generation: UInt64 = 0
    private var instanceID: String { "\(configuration.instanceID)#\(generation)" }

    init(configuration: OpenCodeQuestionConfiguration,
         exchange: Exchange? = nil,
         uptime: @escaping @MainActor () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         receive: @escaping Receive,
         resolved: @escaping @MainActor (QuestionKey) -> Void) {
        self.configuration = configuration
        let session = URLSession(configuration: .ephemeral, delegate: NoOpenCodeRedirects(), delegateQueue: nil)
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
    }

    func start() {
        guard task == nil else { return }
        generation &+= 1
        let captured = generation
        task = Task { [weak self] in await self?.run(generation: captured) }
    }

    func stop() {
        generation &+= 1
        task?.cancel()
        task = nil
        for key in records.keys { resolved(key) }
        records.removeAll()
        seen.removeAll()
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
            guard seen.insert(batch.key).inserted else { return }
            if receive(batch) { records[batch.key] = Record(batch: batch, original: original) }
        case let .resolved(key):
            seen.remove(key)
            if records.removeValue(forKey: key) != nil { resolved(key) }
        }
    }

    func submit(key: QuestionKey, answer: QuestionAnswer) async -> QuestionDelivery {
        guard let record = records[key],
              let body = try? OpenCodeQuestionPayload.reply(original: record.original, answer: answer,
                  instanceID: instanceID) else { return .rejected }
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

    private func run(generation captured: UInt64) async {
        var retry = 1
        while !Task.isCancelled && generation == captured {
            do {
                let health = await serverHealth()
                guard generation == captured, !Task.isCancelled else { break }
                if health == .unsupported { break }
                if health == .offline { throw OpenCodeQuestionConfiguration.Error.invalidEndpoint }
                let request = configuration.request("/global/event")
                let (bytes, response) = try await streamSession.bytes(for: request)
                guard generation == captured, !Task.isCancelled else { break }
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { break }
                try await reconcilePending(generation: captured)
                retry = 1
                var frame = ""
                for try await line in bytes.lines {
                    if Task.isCancelled || generation != captured { break }
                    if line.hasPrefix("data:") {
                        frame += String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces) + "\n"
                        if frame.utf8.count > 256 * 1024 { frame = "" }
                    } else if line.isEmpty, !frame.isEmpty {
                        ingest(Data(frame.trimmingCharacters(in: .newlines).utf8))
                        frame = ""
                    }
                }
            } catch { /* Disconnection: reconcile pending requests after reconnect. */ }
            if Task.isCancelled || generation != captured { break }
            try? await Task.sleep(nanoseconds: UInt64(retry) * 1_000_000_000)
            retry = min(retry * 2, 30)
        }
        if generation == captured { task = nil }
    }

    private enum ServerHealth: Equatable { case supported, offline, unsupported }

    private func serverHealth() async -> ServerHealth {
        let response = await exchange(configuration.request("/global/health"))
        guard let status = response.statusCode else { return .offline }
        guard status == 200,
              let body = try? JSONSerialization.jsonObject(with: response.body) as? [String: Any],
              body["healthy"] as? Bool == true,
              body["version"] as? String == "1.18.32" else { return .unsupported }
        return .supported
    }

    private func reconcilePending(generation captured: UInt64) async throws {
        let response = await exchange(configuration.request("/question", directoryQuery: true))
        guard generation == captured, !Task.isCancelled else { return }
        guard response.statusCode == 200, response.body.count <= 256 * 1024,
              let pending = try JSONSerialization.jsonObject(with: response.body) as? [[String: Any]]
        else { throw OpenCodeQuestionConfiguration.Error.invalidEndpoint }
        var keys: Set<QuestionKey> = []
        for record in pending {
            guard let session = record["sessionID"] as? String, !session.isEmpty,
                  let request = record["id"] as? String, !request.isEmpty else {
                throw OpenCodeQuestionConfiguration.Error.invalidEndpoint
            }
            keys.insert(QuestionKey(provider: .openCode, instanceID: instanceID,
                sessionID: session, requestID: request))
        }
        for key in records.keys where !keys.contains(key) {
            records.removeValue(forKey: key)
            resolved(key)
        }
        seen.formIntersection(keys)
        // Unknown pending requests predate this connection; their original deadline is unknown.
        // Only a fresh event on this stream may create bot controls for them.
    }
}
