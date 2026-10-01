import Foundation
#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

@MainActor
final class OpenCodePluginQuestionSource {
    typealias Submit = @MainActor (QuestionAnswer) async -> QuestionDelivery
    typealias ReturnLocal = @MainActor () async -> Void
    typealias Receive = @MainActor (QuestionBatch, @escaping Submit, @escaping ReturnLocal) -> Bool
    private struct Client { let instance: String; let label: String? }
    private struct Record {
        let batch: QuestionBatch
        let original: Data
        var owner: OpenCodeBridgeConnectionID
        var active = true
        var attempted = false
        var nativeResolved = false
        var attempt: UUID?
    }
    private struct Attempt {
        let key: QuestionKey
        let owner: OpenCodeBridgeConnectionID
        let continuation: CheckedContinuation<QuestionDelivery, Never>
        let timeout: Task<Void, Never>
    }
    private let configuration: OpenCodeBridgeConfiguration
    private let uptime: () -> TimeInterval
    private let receive: Receive
    private let resolved: (QuestionKey) -> Void
    private let resultTimeout: TimeInterval
    var stateChanged: (Int) -> Void = { _ in }
    var sendFrame: ((OpenCodeBridgeMessage, OpenCodeBridgeConnectionID) async -> Bool)?
    private var clients: [OpenCodeBridgeConnectionID: Client] = [:]
    private var records: [QuestionKey: Record] = [:]
    private var seen: [QuestionKey] = []
    private var attempts: [UUID: Attempt] = [:]
    private var stopped = false
    private lazy var socket = OpenCodeBridgeSocket(configuration: configuration,
        receive: { [weak self] id, message in self?.ingest(message, from: id) },
        disconnected: { [weak self] id in self?.disconnected(id) })
    var connectedCount: Int { clients.count }

    init(configuration: OpenCodeBridgeConfiguration,
         uptime: @escaping () -> TimeInterval,
         receive: @escaping Receive, resolved: @escaping (QuestionKey) -> Void,
         resultTimeout: TimeInterval = 5) {
        self.configuration = configuration; self.uptime = uptime; self.receive = receive
        self.resolved = resolved; self.resultTimeout = resultTimeout
    }
    func start() throws { stopped = false; try socket.start() }
    func stop() {
        stopped = true; socket.stop()
        for id in Array(attempts.keys) { finish(id, .unconfirmed) }
        clients.removeAll(); records.removeAll(); seen.removeAll(); stateChanged(0)
    }
    func ingest(_ message: OpenCodeBridgeMessage, from id: OpenCodeBridgeConnectionID) {
        guard !stopped else { return }
        if case let .hello(version, token, instance, generation, host, _, label) = message {
            guard version == 1, token == configuration.token, generation == configuration.generation,
                  host == "1.18.32", clients[id] == nil, clients.count < 32 else { return }
            let identity = instance.uuidString + "#" + generation.uuidString
            guard !clients.values.contains(where: { $0.instance == identity }) else { return }
            clients[id] = Client(instance: identity, label: label); stateChanged(clients.count); return
        }
        guard let client = clients[id] else { return }
        switch message {
        case let .asked(original): observe(original, client: client, owner: id)
        case let .resolved(session, request):
            let key = QuestionKey(provider: .openCode, instanceID: client.instance, sessionID: session, requestID: request)
            guard records[key]?.owner == id else { return }
            if records[key]?.attempt != nil {
                // A native event can beat our API acknowledgment; it cannot prove our answer won.
                records[key]?.active = false; records[key]?.nativeResolved = true
            } else if records.removeValue(forKey: key) != nil { resolved(key) }
        case let .result(attempt, delivery):
            guard attempts[attempt]?.owner == id else { return }
            finish(attempt, delivery)
        case let .snapshot(originals): reconcile(originals, client: client, owner: id)
        default: break
        }
    }
    private func observe(_ original: Data, client: Client, owner: OpenCodeBridgeConnectionID) {
        guard let decoded = try? OpenCodeQuestionPayload.decode(original, instanceID: client.instance, receivedUptime: uptime()) else { return }
        let batch = QuestionBatch(key: decoded.key, projectLabel: client.label, questions: decoded.questions,
            receivedUptime: decoded.receivedUptime, deadlineUptime: decoded.deadlineUptime)
        if let prior = records[batch.key] {
            if prior.batch.questions != batch.questions {
                records[batch.key]?.active = false; records[batch.key]?.attempted = true; resolved(batch.key)
            }
            return
        }
        guard !seen.contains(batch.key) else { return }
        remember(batch.key)
        guard records.count < 32 else { return }
        records[batch.key] = Record(batch: batch, original: original, owner: owner)
        if !offer(batch) { records.removeValue(forKey: batch.key) }
    }
    private func offer(_ batch: QuestionBatch) -> Bool {
        receive(batch, { [weak self] answer in await self?.submit(key: batch.key, answer: answer) ?? .rejected },
            { [weak self] in await self?.returnLocal(batch.key) })
    }
    private func send(_ message: OpenCodeBridgeMessage, to id: OpenCodeBridgeConnectionID) async -> Bool {
        if let sendFrame { return await sendFrame(message, id) }
        return await socket.send(message, to: id)
    }
    private func submit(key: QuestionKey, answer: QuestionAnswer) async -> QuestionDelivery {
        guard let record = records[key], record.active, !record.attempted, clients[record.owner] != nil,
              uptime() < record.batch.deadlineUptime,
              let body = try? OpenCodeQuestionPayload.reply(original: record.original, answer: answer, instanceID: key.instanceID),
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let answers = object["answers"] as? [[String]] else { return .rejected }
        let id = UUID()
        records[key]?.attempted = true; records[key]?.attempt = id
        return await withCheckedContinuation { continuation in
            let timeout = Task { [weak self, resultTimeout] in
                try? await Task.sleep(nanoseconds: UInt64(max(0, resultTimeout) * 1_000_000_000))
                if !Task.isCancelled { self?.finish(id, .unconfirmed) }
            }
            attempts[id] = Attempt(key: key, owner: record.owner, continuation: continuation, timeout: timeout)
            Task { [weak self] in
                let sent = await self?.send(.reply(attemptID: id, sessionID: key.sessionID,
                    requestID: key.requestID, answers: answers), to: record.owner) ?? false
                if !sent { self?.finish(id, .unconfirmed) }
            }
        }
    }
    private func finish(_ id: UUID, _ delivery: QuestionDelivery) {
        guard let attempt = attempts.removeValue(forKey: id) else { return }
        attempt.timeout.cancel()
        if records[attempt.key]?.nativeResolved == true || delivery == .accepted || delivery == .rejected {
            records.removeValue(forKey: attempt.key)
        } else {
            records[attempt.key]?.active = false; records[attempt.key]?.attempt = nil
        }
        attempt.continuation.resume(returning: delivery)
    }
    private func returnLocal(_ key: QuestionKey) async {
        guard let record = records[key] else { return }
        records[key]?.active = false; records[key]?.attempted = true
        _ = await send(.local(sessionID: key.sessionID, requestID: key.requestID), to: record.owner)
    }
    func disconnected(_ id: OpenCodeBridgeConnectionID) {
        guard clients.removeValue(forKey: id) != nil else { return }
        for attempt in Array(attempts.keys) where attempts[attempt]?.owner == id { finish(attempt, .unconfirmed) }
        for (key, record) in records where record.owner == id && record.active {
            records[key]?.active = false; resolved(key)
        }
        stateChanged(clients.count)
    }
    private func remember(_ key: QuestionKey) {
        guard !seen.contains(key) else { return }
        seen.append(key); if seen.count > 256 { seen.removeFirst() }
    }
    private func reconcile(_ originals: [Data], client: Client, owner: OpenCodeBridgeConnectionID) {
        var verified: [QuestionKey: QuestionBatch] = [:]
        for original in originals {
            guard let batch = try? OpenCodeQuestionPayload.decode(original, instanceID: client.instance, receivedUptime: uptime()),
                  verified[batch.key] == nil else { continue }
            verified[batch.key] = batch
            if records[batch.key] == nil { remember(batch.key) }
        }
        for (key, record) in records where key.instanceID == client.instance {
            guard let pending = verified[key], pending.questions == record.batch.questions else {
                if record.attempt == nil { records.removeValue(forKey: key); resolved(key) }
                continue
            }
            records[key]?.owner = owner
            if !record.active, !record.attempted, uptime() < record.batch.deadlineUptime, offer(record.batch) {
                records[key]?.active = true
            }
        }
        // Unknown-age pending requests never gain a new ten-minute deadline from a snapshot.
    }
}
