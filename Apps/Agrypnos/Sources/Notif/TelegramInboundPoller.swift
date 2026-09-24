import Foundation

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

struct TelegramInboundPollSnapshot: Equatable, Sendable {
    var enabled: Bool
    var token: String?
    var chatId: String?
    var cursor: TelegramInboundCursor
}

enum TelegramInboundHTTP {
    static let requestTimeout: TimeInterval = 35

    static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = requestTimeout
        config.timeoutIntervalForResource = requestTimeout + 5
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    /// Do not log `request.url` — the bot token is in the path.
    static func fetch(_ request: NotifOutboundRequest) async -> Data? {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.httpMethod
        if !request.body.isEmpty {
            urlRequest.httpBody = request.body
        }
        urlRequest.timeoutInterval = requestTimeout
        for (header, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: header)
        }
        do {
            let (data, response) = try await session.data(for: urlRequest)
            let status = (response as? HTTPURLResponse)?.statusCode
            guard let status, (200...299).contains(status) else { return nil }
            return data
        } catch {
            return nil
        }
    }

    static func send(_ request: NotifOutboundRequest) async {
        _ = await fetch(request)
    }
}

/// Long-poll `getUpdates` on the user's bot. Never log the request URL — the token is in the path.
@MainActor
final class TelegramInboundPoller {
    static let longPollTimeout = 25
    static let retryNanos: UInt64 = 5_000_000_000

    weak var runtime: WatchRuntime?
    private var task: Task<Void, Never>?
    private var generation: UInt64 = 0

    func sync() {
        if shouldPoll() {
            startLoop()
        } else {
            invalidate()
        }
    }

    func stop() {
        invalidate()
    }

    func invalidate() {
        generation &+= 1
        task?.cancel()
        task = nil
    }

    func accepts(generation captured: UInt64) -> Bool {
        TelegramInboundGeneration.allowsApply(current: generation, captured: captured)
    }

    private func shouldPoll() -> Bool {
        guard let runtime else { return false }
        let snap = runtime.telegramInboundPollSnapshot()
        return TelegramInboundPolicy.shouldPoll(
            enabled: snap.enabled,
            botToken: snap.token,
            chatId: snap.chatId
        )
    }

    private func startLoop() {
        guard task == nil else { return }
        let timeout = Self.longPollTimeout
        let retry = Self.retryNanos
        let capturedGeneration = generation
        task = Task.detached { [weak self] in
            while !Task.isCancelled {
                let snap = await MainActor.run { self?.runtime?.telegramInboundPollSnapshot() }
                guard let snap else { return }
                guard
                    TelegramInboundPolicy.shouldPoll(
                        enabled: snap.enabled,
                        botToken: snap.token,
                        chatId: snap.chatId
                    ),
                    let token = snap.token,
                    let request = NotifOutboundRequestFactory.telegramGetUpdates(
                        botToken: token,
                        offset: snap.cursor.offset,
                        timeout: timeout
                    )
                else {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    continue
                }
                let data = await TelegramInboundHTTP.fetch(request)
                if Task.isCancelled { return }
                guard let data, TelegramGetUpdatesParser.accepted(data) else {
                    try? await Task.sleep(nanoseconds: retry)
                    continue
                }
                let updates = TelegramGetUpdatesParser.parse(data)
                await MainActor.run {
                    self?.runtime?.finishTelegramInboundPoll(
                        generation: capturedGeneration,
                        fetchedToken: token,
                        cursor: snap.cursor,
                        updates: updates
                    )
                }
            }
        }
    }
}
