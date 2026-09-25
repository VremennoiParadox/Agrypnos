import Foundation

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

struct DiscordInboundSnapshot: Equatable, Sendable {
    var enabled: Bool
    var token: String?
    var channelId: String?
    var cursor: DiscordInboundCursor
}

/// Gateway WebSocket on the Mac. No listen port. No Interactions Endpoint URL.
@MainActor
final class DiscordInboundGatewayClient {
    static let retryNanos: UInt64 = 5_000_000_000

    weak var runtime: WatchRuntime?
    private var task: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var generation: UInt64 = 0
    private var urlSession: URLSession?
    private var socket: URLSessionWebSocketTask?
    private var reconnectSoon = false

    func sync() {
        if shouldReceive() {
            startLoop(session: .leftover)
        } else {
            invalidate()
        }
    }

    func restartForWakeMiss() {
        invalidate()
        guard shouldReceive() else { return }
        runtime?.beginDiscordInboundWakeMissSession()
        startLoop(session: .keepCursor)
    }

    func stop() {
        invalidate()
    }

    func invalidate() {
        generation &+= 1
        heartbeatTask?.cancel()
        heartbeatTask = nil
        task?.cancel()
        task = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
    }

    func accepts(generation captured: UInt64) -> Bool {
        TelegramInboundGeneration.allowsApply(current: generation, captured: captured)
    }

    private func shouldReceive() -> Bool {
        guard let runtime else { return false }
        let snap = runtime.discordInboundSnapshot()
        return DiscordInboundPolicy.shouldReceive(
            enabled: snap.enabled,
            botToken: snap.token,
            channelId: snap.channelId
        )
    }

    private enum SessionStart {
        case leftover
        case keepCursor
    }

    private func startLoop(session: SessionStart) {
        guard task == nil else { return }
        switch session {
        case .leftover:
            runtime?.beginDiscordInboundSession()
        case .keepCursor:
            break
        }
        let retry = Self.retryNanos
        let capturedGeneration = generation
        task = Task.detached { [weak self] in
            while !Task.isCancelled {
                let live = await MainActor.run { self?.shouldReceive() ?? false }
                guard live else {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    continue
                }
                let reconnectNow = await self?.runConnection(generation: capturedGeneration) ?? false
                if Task.isCancelled { return }
                if reconnectNow { continue }
                try? await Task.sleep(nanoseconds: retry)
            }
        }
    }

    /// `true` = reconnect without the retry delay (opcode 7 / invalid session / missed heartbeat).
    private func runConnection(generation captured: UInt64) async -> Bool {
        reconnectSoon = false
        let snap = await MainActor.run { self.runtime?.discordInboundSnapshot() }
        guard let snap,
              DiscordInboundPolicy.shouldReceive(
                  enabled: snap.enabled,
                  botToken: snap.token,
                  channelId: snap.channelId
              ),
              let token = snap.token
        else { return false }

        let botData = await gatewayBotData(token: token)
        let url = DiscordGatewayURLFactory.socketURL(
            gatewayBotData: botData,
            resumeGatewayURL: snap.cursor.resumeGatewayURL,
            canResume: snap.cursor.canResume
        )
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 35
        config.waitsForConnectivity = false
        let session = URLSession(configuration: config)
        let ws = session.webSocketTask(with: url)
        await MainActor.run {
            self.urlSession = session
            self.socket = ws
        }
        ws.resume()

        let ack = HeartbeatAck()
        var reconnect = false
        receive: while !Task.isCancelled {
            let message: URLSessionWebSocketTask.Message
            do {
                message = try await ws.receive()
            } catch {
                break
            }
            if Task.isCancelled { break }
            let data: Data
            switch message {
            case .string(let text):
                data = Data(text.utf8)
            case .data(let raw):
                data = raw
            @unknown default:
                continue
            }
            guard let frame = DiscordGatewayParser.frame(from: data) else { continue }
            if case .heartbeatAck = frame.event {
                ack.ok = true
            }
            if case .hello(let interval) = frame.event {
                ack.ok = true
                startHeartbeat(intervalMs: interval, ack: ack, generation: captured)
            }
            let outcome = await MainActor.run { () -> ConnectionOutcome in
                guard let runtime = self.runtime, self.accepts(generation: captured) else {
                    return .stop
                }
                let effects = runtime.handleDiscordGatewayFrame(frame, generation: captured)
                return self.apply(
                    effects,
                    token: token,
                    generation: captured,
                    socket: ws
                )
            }
            switch outcome {
            case .continue:
                continue
            case .reconnect:
                reconnect = true
                break receive
            case .stop:
                break receive
            }
        }
        heartbeatTask?.cancel()
        heartbeatTask = nil
        ws.cancel(with: .goingAway, reason: nil)
        session.invalidateAndCancel()
        await MainActor.run {
            if self.socket === ws {
                self.socket = nil
                self.urlSession = nil
            }
        }
        return reconnect || reconnectSoon
    }

    private enum ConnectionOutcome {
        case `continue`
        case reconnect
        case stop
    }

    private func apply(
        _ effects: [DiscordGatewayEffect],
        token: String,
        generation captured: UInt64,
        socket: URLSessionWebSocketTask
    ) -> ConnectionOutcome {
        guard let runtime, accepts(generation: captured) else { return .stop }
        let cursor = runtime.store.loadDiscordInboundCursor()
        for effect in effects {
            switch effect {
            case .sendIdentify, .sendResume, .sendHeartbeat:
                send(effect, token: token, cursor: cursor, socket: socket)
            case .inbound(let update):
                runtime.applyDiscordInbound(update)
            case .registerCommands(let applicationId):
                runtime.registerDiscordBotCommands(applicationId: applicationId)
            case .reconnect:
                return .reconnect
            }
        }
        return .continue
    }

    private func send(
        _ effect: DiscordGatewayEffect,
        token: String,
        cursor: DiscordInboundCursor,
        socket: URLSessionWebSocketTask
    ) {
        guard let object = DiscordGatewaySession.payload(effect, botToken: token, cursor: cursor),
              let data = DiscordGatewaySession.json(object),
              let text = String(data: data, encoding: .utf8)
        else { return }
        socket.send(.string(text)) { _ in }
    }

    private func startHeartbeat(intervalMs: Int, ack: HeartbeatAck, generation captured: UInt64) {
        heartbeatTask?.cancel()
        let nanos = UInt64(max(intervalMs, 1)) * 1_000_000
        heartbeatTask = Task.detached { [weak self] in
            try? await Task.sleep(nanoseconds: nanos / 2)
            while !Task.isCancelled {
                let ok = await MainActor.run { () -> Bool in
                    guard let self, self.accepts(generation: captured), let socket = self.socket else {
                        return false
                    }
                    if !ack.ok {
                        self.reconnectSoon = true
                        socket.cancel(with: .goingAway, reason: nil)
                        return false
                    }
                    ack.ok = false
                    let cursor = self.runtime?.store.loadDiscordInboundCursor() ?? .unset
                    let token = self.runtime?.discordInboundSnapshot().token
                    if let token {
                        self.send(.sendHeartbeat, token: token, cursor: cursor, socket: socket)
                    }
                    return true
                }
                if !ok { return }
                try? await Task.sleep(nanoseconds: nanos)
            }
        }
    }

    private func gatewayBotData(token: String) async -> Data? {
        guard let request = DiscordInboundRequestFactory.gatewayBot(botToken: token) else { return nil }
        return await TelegramInboundHTTP.fetch(request)
    }
}

/// Shared between the receive loop and the heartbeat timer.
final class HeartbeatAck: @unchecked Sendable {
    var ok = true
}
