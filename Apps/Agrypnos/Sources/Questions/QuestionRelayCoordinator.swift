import Foundation

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

struct TelegramQuestionDestination: Equatable {
    let token: String
    let chatID: String
    let userID: String

    var isComplete: Bool { !token.isEmpty && Int64(chatID) != nil && (Int64(userID) ?? 0) > 0 }
}

struct QuestionRelaySettings: Equatable {
    var enabled: Bool
    var includedKinds: Set<AgentKind>
    var telegram: TelegramQuestionDestination?
}

struct QuestionHTTPResponse: Sendable {
    let statusCode: Int?
    let body: Data
}

enum QuestionRelayEvent {
    case observed(QuestionKey, TimeInterval)
    case cleared(QuestionKey)
    case expired(QuestionKey)
}

/// Owns request-scoped closures. The bot only identifies a stored request; it never constructs one.
@MainActor
final class QuestionRelayCoordinator {
    typealias Transport = @MainActor (NotifOutboundRequest) async -> QuestionHTTPResponse
    private struct Record {
        let batch: QuestionBatch
        let submit: @MainActor (QuestionAnswer) async -> QuestionDelivery
        let returnLocal: @MainActor () async -> Void
        var returnedLocal = false
        var telegramRef: QuestionMessageRef?
    }

    private var registry = QuestionRegistry()
    private var records: [UUID: Record] = [:]
    private var currentSettings: QuestionRelaySettings?
    private var deadlineTask: Task<Void, Never>?
    private var recentCallbacks: [String] = []
    private let settings: @MainActor () -> QuestionRelaySettings
    private let transport: Transport
    private let uptime: @MainActor () -> TimeInterval
    private let onChange: @MainActor (QuestionRelayEvent) -> Void

    init(settings: @escaping @MainActor () -> QuestionRelaySettings,
         transport: @escaping Transport,
         uptime: @escaping @MainActor () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         onChange: @escaping @MainActor (QuestionRelayEvent) -> Void) {
        self.settings = settings
        self.transport = transport
        self.uptime = uptime
        self.onChange = onChange
    }

    var pendingDeadlines: [QuestionKey: TimeInterval] { registry.pendingDeadlines }

    @discardableResult
    func receive(_ batch: QuestionBatch,
                 submit: @escaping @MainActor (QuestionAnswer) async -> QuestionDelivery,
                 returnLocal: @escaping @MainActor () async -> Void) -> Bool {
        refreshSettings()
        guard let currentSettings, currentSettings.enabled,
              currentSettings.includedKinds.contains(batch.key.provider),
              let target = currentSettings.telegram, target.isComplete,
              uptime() < batch.deadlineUptime else { return false }
        let handle = UUID()
        guard registry.insert(batch, handle: handle) else {
            // A changed payload for the same native request invalidates the old buttons.
            if let old = records.first(where: { $0.value.batch.key == batch.key }), old.value.batch.questions != batch.questions {
                endLocally(old.key)
            }
            return false
        }
        records[handle] = Record(batch: batch, submit: submit, returnLocal: returnLocal)
        onChange(.observed(batch.key, batch.deadlineUptime))
        scheduleDeadline()
        let captured = registry.generation
        Task { [weak self] in await self?.createMessage(handle: handle, target: target, captured: captured) }
        return true
    }

    func handleTelegram(_ click: TelegramQuestionCallback, drain: TelegramInboundDrain) {
        refreshSettings()
        guard let target = currentSettings?.telegram, target.isComplete else { return }
        let ack = TelegramQuestionMessage.acknowledge(id: click.id, botToken: target.token,
            text: drain == .live ? nil : "This question must be answered on your Mac.")
        if let ack { Task { [transport] in _ = await transport(ack) } }
        guard drain == .live, click.reference.destinationID == target.chatID,
              click.senderID == target.userID else { return }
        let dedupeID = target.token + ":" + click.id
        guard !recentCallbacks.contains(dedupeID) else { return }
        recentCallbacks.append(dedupeID)
        if recentCallbacks.count > 256 { recentCallbacks.removeFirst(recentCallbacks.count - 256) }
        let effect = registry.handle(QuestionCallback(reference: click.reference, senderID: click.senderID,
            actionToken: click.actionToken, generation: registry.generation), authorizedUserID: target.userID, now: uptime())
        switch effect {
        case .ignore: break
        case let .rerender(handle, _):
            editMessage(handle: handle, target: target)
        case let .returnLocal(handle, _):
            onChange(.cleared(records[handle]!.batch.key))
            callReturnLocal(handle)
            scheduleDeadline()
            editMessage(handle: handle, target: target)
        case let .submit(handle, answer):
            // Core reserved submitting synchronously. Clear the unanswered timer before native I/O.
            onChange(.cleared(answer.key))
            scheduleDeadline()
            editMessage(handle: handle, target: target)
            let captured = registry.generation
            guard let submit = records[handle]?.submit else { return }
            Task { [weak self] in
                let result = await submit(answer)
                guard let self, self.registry.generation == captured, self.records[handle] != nil else { return }
                self.registry.complete(handle: handle, result: result)
                self.editMessage(handle: handle, target: target)
            }
        }
    }

    func expireDueQuestions() {
        let now = uptime()
        let deadlines = registry.pendingDeadlines
        let due = registry.expire(now: now)
        for key in due {
            if let handle = records.first(where: { $0.value.batch.key == key })?.key {
                callReturnLocal(handle)
                if let target = currentSettings?.telegram { editMessage(handle: handle, target: target) }
            }
            // Native expiry earlier than ten minutes is unavailable, not "unanswered for ten minutes".
            let original = records.first(where: { $0.value.batch.key == key })?.value.batch.receivedUptime ?? now
            if (deadlines[key] ?? 0) < original + 600 { onChange(.cleared(key)) }
            else { onChange(.expired(key)) }
        }
        scheduleDeadline()
    }

    func cancel(key: QuestionKey) {
        let affected = records.filter { $0.value.batch.key == key }
        registry.cancel(key: key)
        for (handle, _) in affected { records.removeValue(forKey: handle) }
        if !affected.isEmpty { onChange(.cleared(key)) }
        scheduleDeadline()
    }

    func invalidateAll() {
        deadlineTask?.cancel(); deadlineTask = nil
        let old = records
        registry.invalidateAll()
        records.removeAll()
        recentCallbacks.removeAll()
        for (_, record) in old {
            onChange(.cleared(record.batch.key))
            if !record.returnedLocal { Task { await record.returnLocal() } }
        }
    }

    func refreshSettings() {
        let next = settings()
        guard next != currentSettings else { return }
        invalidateAll()
        currentSettings = next
    }

    private func createMessage(handle: UUID, target: TelegramQuestionDestination, captured: UInt64) async {
        guard let record = records[handle], let request = TelegramQuestionMessage.initial(batch: record.batch,
            botToken: target.token, chatID: target.chatID) else { endLocally(handle); return }
        var result = TelegramQuestionResponse.parse(status: nil, body: Data())
        for attempt in 0..<2 {
            let response = await transport(request)
            guard registry.generation == captured, records[handle] != nil else { return }
            result = TelegramQuestionResponse.parse(status: response.statusCode, body: response.body)
            if case let .rejected(retryAfter) = result, let retryAfter, attempt == 0,
               uptime() + retryAfter < record.batch.deadlineUptime {
                try? await Task.sleep(nanoseconds: UInt64(retryAfter * 1_000_000_000))
                continue
            }
            break
        }
        guard registry.generation == captured, records[handle] != nil else { return }
        guard uptime() < record.batch.deadlineUptime,
              case let .sent(reference) = result, reference.destinationID == target.chatID,
              registry.bindMessage(handle: handle, reference: reference) else { endLocally(handle); return }
        records[handle]?.telegramRef = reference
        editMessage(handle: handle, target: target)
    }

    private func editMessage(handle: UUID, target: TelegramQuestionDestination) {
        guard let reference = records[handle]?.telegramRef,
              let view = registry.view(handle: handle, reference: reference),
              let request = TelegramQuestionMessage.edit(view: view, botToken: target.token, reference: reference)
        else { return }
        let captured = registry.generation
        Task { [weak self, transport] in
            guard let self, self.registry.generation == captured, self.records[handle] != nil else { return }
            _ = await transport(request)
        }
    }

    private func endLocally(_ handle: UUID) {
        guard let record = records[handle] else { return }
        registry.returnToLocal(handle: handle)
        onChange(.cleared(record.batch.key))
        callReturnLocal(handle)
        if let target = currentSettings?.telegram { editMessage(handle: handle, target: target) }
        scheduleDeadline()
    }

    private func callReturnLocal(_ handle: UUID) {
        guard let record = records[handle], !record.returnedLocal else { return }
        records[handle]?.returnedLocal = true
        Task { await record.returnLocal() }
    }

    private func scheduleDeadline() {
        deadlineTask?.cancel(); deadlineTask = nil
        guard let nearest = registry.pendingDeadlines.values.min() else { return }
        let delta = max(0, nearest - uptime())
        deadlineTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(min(delta, 600) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.expireDueQuestions()
        }
    }
}
