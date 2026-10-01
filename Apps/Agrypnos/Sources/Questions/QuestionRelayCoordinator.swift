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

struct DiscordQuestionDestination: Equatable {
    let token: String
    let channelID: String
    let userID: String

    var isComplete: Bool { !token.isEmpty && !channelID.isEmpty && !userID.isEmpty }
}

struct QuestionRelaySettings: Equatable {
    var enabled: Bool
    var includedKinds: Set<AgentKind>
    var telegram: TelegramQuestionDestination?
    var discord: DiscordQuestionDestination? = nil
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
        var discordRef: QuestionMessageRef?
        var pendingCreates: Int = 0
    }
    private struct QueuedEdit {
        let id = UUID()
        let request: NotifOutboundRequest
        let handle: UUID
        let deadline: TimeInterval
        let terminal: Bool
    }

    private var registry = QuestionRegistry()
    private var records: [UUID: Record] = [:]
    private var currentSettings: QuestionRelaySettings?
    private var deadlineTask: Task<Void, Never>?
    private var recentCallbacks: [String] = []
    private var edits: [QuestionMessageRef: Task<Void, Never>] = [:]
    private var queuedEdits: [QuestionMessageRef: QueuedEdit] = [:]
    private let settings: @MainActor () -> QuestionRelaySettings
    private let transport: Transport
    private let uptime: @MainActor () -> TimeInterval
    private let retryWait: @MainActor (TimeInterval) async -> Void
    private let onChange: @MainActor (QuestionRelayEvent) -> Void

    init(settings: @escaping @MainActor () -> QuestionRelaySettings,
         transport: @escaping Transport,
         uptime: @escaping @MainActor () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         retryWait: @escaping @MainActor (TimeInterval) async -> Void = {
             try? await Task.sleep(nanoseconds: UInt64($0 * 1_000_000_000))
         },
         onChange: @escaping @MainActor (QuestionRelayEvent) -> Void) {
        self.settings = settings
        self.transport = transport
        self.uptime = uptime
        self.retryWait = retryWait
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
              (currentSettings.telegram?.isComplete == true || currentSettings.discord?.isComplete == true)
        else { return false }
        let previousDeadline = registry.pendingDeadlines[batch.key]
        if previousDeadline == nil, uptime() >= batch.deadlineUptime { return false }
        let handle = UUID()
        guard registry.insert(batch, handle: handle) else {
            // A changed payload for the same native request invalidates the old buttons.
            if let old = records.first(where: { $0.value.batch.key == batch.key }) {
                if old.value.batch.questions != batch.questions || old.value.batch.projectLabel != batch.projectLabel {
                    endLocally(old.key)
                } else if let previousDeadline, let shortened = registry.pendingDeadlines[batch.key],
                          shortened < previousDeadline {
                    // A shorter native lifetime is not a ten-minute unanswered event.
                    // Native expiry clears the watch's pending question when it occurs.
                    scheduleDeadline()
                    if shortened <= uptime() { expireDueQuestions() }
                }
            }
            return false
        }
        let telegram = currentSettings.telegram?.isComplete == true ? currentSettings.telegram : nil
        let discord = currentSettings.discord?.isComplete == true ? currentSettings.discord : nil
        records[handle] = Record(batch: batch, submit: submit, returnLocal: returnLocal,
            pendingCreates: (telegram == nil ? 0 : 1) + (discord == nil ? 0 : 1))
        // The watch's unanswered reason is ten minutes; a shorter native lifetime
        // ends via .cleared, never via .expired.
        onChange(.observed(batch.key, batch.receivedUptime + 600))
        scheduleDeadline()
        let captured = registry.generation
        if let telegram { Task { [weak self] in await self?.createMessage(handle: handle, target: telegram, captured: captured) } }
        if let discord { Task { [weak self] in await self?.createDiscordMessage(handle: handle, target: discord, captured: captured) } }
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
        apply(effect)
    }

    func handleDiscord(_ click: DiscordQuestionInteraction, drain: TelegramInboundDrain) {
        refreshSettings()
        guard drain == .live, let target = currentSettings?.discord, target.isComplete,
              click.reference.destinationID == target.channelID, click.senderID == target.userID else { return }
        let dedupeID = target.token + ":" + click.interactionID
        guard !recentCallbacks.contains(dedupeID) else { return }
        recentCallbacks.append(dedupeID)
        if recentCallbacks.count > 256 { recentCallbacks.removeFirst(recentCallbacks.count - 256) }
        let effect = registry.handle(QuestionCallback(reference: click.reference, senderID: click.senderID,
            actionToken: click.actionToken, generation: registry.generation), authorizedUserID: target.userID, now: uptime())
        apply(effect)
    }

    private func apply(_ effect: QuestionEffect) {
        switch effect {
        case .ignore: break
        case let .rerender(handle, _):
            editMessages(handle: handle)
        case let .returnLocal(handle, _):
            guard let key = records[handle]?.batch.key else { return }
            onChange(.cleared(key))
            callReturnLocal(handle)
            scheduleDeadline()
            editMessages(handle: handle)
            retire(handle)
        case let .submit(handle, answer):
            // Core reserved submitting synchronously. Clear the unanswered timer before native I/O.
            onChange(.cleared(answer.key))
            scheduleDeadline()
            editMessages(handle: handle)
            let captured = registry.generation
            guard let submit = records[handle]?.submit else { return }
            Task { [weak self] in
                let result = await submit(answer)
                guard let self, self.registry.generation == captured, self.records[handle] != nil else { return }
                self.registry.complete(handle: handle, result: result)
                self.editMessages(handle: handle)
                self.retire(handle)
            }
        }
    }

    func expireDueQuestions() {
        let now = uptime()
        let deadlines = registry.pendingDeadlines
        let due = registry.expire(now: now)
        for key in due {
            let original = records.first(where: { $0.value.batch.key == key })?.value.batch.receivedUptime ?? now
            if let handle = records.first(where: { $0.value.batch.key == key })?.key {
                callReturnLocal(handle)
                editMessages(handle: handle)
                retire(handle)
            }
            // Native expiry earlier than ten minutes is unavailable, not "unanswered for ten minutes".
            if (deadlines[key] ?? 0) < original + 600 { onChange(.cleared(key)) }
            else { onChange(.expired(key)) }
        }
        scheduleDeadline()
    }

    func cancel(key: QuestionKey) {
        let affected = records.filter { $0.value.batch.key == key }
        for (handle, _) in affected {
            registry.makeUnavailable(handle: handle)
            editMessages(handle: handle)
            // A verified reconnect may bind fresh controls for this original native request.
            retire(handle, preventingReplay: false)
        }
        if !affected.isEmpty { onChange(.cleared(key)) }
        scheduleDeadline()
    }

    func invalidateAll() {
        deadlineTask?.cancel(); deadlineTask = nil
        let old = records
        let needsFallback = Set(old.keys.filter { handle in
            switch registry.state(handle: handle) {
            case .pending, .expired, .invalid: true
            default: false
            }
        })
        registry.invalidateAll()
        records.removeAll()
        recentCallbacks.removeAll()
        edits.values.forEach { $0.cancel() }
        edits.removeAll()
        queuedEdits.removeAll()
        for (handle, record) in old {
            onChange(.cleared(record.batch.key))
            if needsFallback.contains(handle), !record.returnedLocal { Task { await record.returnLocal() } }
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
            botToken: target.token, chatID: target.chatID) else { finishCreation(handle, succeeded: false); return }
        var result = TelegramQuestionResponse.parse(status: nil, body: Data())
        for attempt in 0..<2 {
            let response = await transport(request)
            guard registry.generation == captured, records[handle] != nil else { return }
            result = TelegramQuestionResponse.parse(status: response.statusCode, body: response.body)
            if case let .rejected(retryAfter) = result, let retryAfter, attempt == 0,
               uptime() + retryAfter < record.batch.deadlineUptime {
                await retryWait(retryAfter)
                continue
            }
            break
        }
        guard registry.generation == captured, records[handle] != nil else { return }
        guard uptime() < record.batch.deadlineUptime,
              case let .sent(reference) = result, reference.destinationID == target.chatID,
              registry.bindMessage(handle: handle, reference: reference) else { finishCreation(handle, succeeded: false); return }
        records[handle]?.telegramRef = reference
        finishCreation(handle, succeeded: true)
        editMessages(handle: handle)
    }

    private func createDiscordMessage(handle: UUID, target: DiscordQuestionDestination, captured: UInt64) async {
        guard let record = records[handle], let request = DiscordQuestionMessage.initial(batch: record.batch,
            botToken: target.token, channelID: target.channelID) else { finishCreation(handle, succeeded: false); return }
        var result = DiscordQuestionResponse.parse(status: nil, body: Data())
        for attempt in 0..<2 {
            let response = await transport(request)
            guard registry.generation == captured, records[handle] != nil else { return }
            result = DiscordQuestionResponse.parse(status: response.statusCode, body: response.body)
            if case let .rejected(retryAfter) = result, let retryAfter, attempt == 0,
               uptime() + retryAfter < record.batch.deadlineUptime {
                await retryWait(retryAfter)
                continue
            }
            break
        }
        guard registry.generation == captured, records[handle] != nil else { return }
        guard uptime() < record.batch.deadlineUptime,
              case let .sent(reference) = result, reference.destinationID == target.channelID,
              registry.bindMessage(handle: handle, reference: reference) else { finishCreation(handle, succeeded: false); return }
        records[handle]?.discordRef = reference
        finishCreation(handle, succeeded: true)
        editMessages(handle: handle)
    }

    private func finishCreation(_ handle: UUID, succeeded: Bool) {
        guard records[handle] != nil else { return }
        records[handle]!.pendingCreates -= 1
        if !succeeded, records[handle]!.pendingCreates == 0,
           records[handle]!.telegramRef == nil, records[handle]!.discordRef == nil {
            endLocally(handle)
        }
    }

    private func editMessages(handle: UUID) {
        guard let record = records[handle] else { return }
        if let target = currentSettings?.telegram, let reference = record.telegramRef,
           let view = registry.view(handle: handle, reference: reference),
           let request = TelegramQuestionMessage.edit(view: view, botToken: target.token, reference: reference) {
            queueEdit(request, reference: reference, handle: handle)
        }
        if let target = currentSettings?.discord, let reference = record.discordRef,
           let view = registry.view(handle: handle, reference: reference),
           let request = DiscordQuestionMessage.edit(view: view, botToken: target.token, reference: reference) {
            queueEdit(request, reference: reference, handle: handle)
        }
    }

    private func queueEdit(_ request: NotifOutboundRequest, reference: QuestionMessageRef, handle: UUID) {
        guard let record = records[handle] else { return }
        // Active requests need at most 64 message slots. Bound terminal edit work too.
        guard queuedEdits[reference] != nil || queuedEdits.count < 128 else {
            endLocally(handle)
            return
        }
        queuedEdits[reference] = QueuedEdit(request: request, handle: handle,
            deadline: record.batch.deadlineUptime, terminal: registry.state(handle: handle) != .pending)
        guard edits[reference] == nil else { return }
        let captured = registry.generation
        edits[reference] = Task { [weak self] in
            await self?.drainEdits(reference: reference, captured: captured)
        }
    }

    private func drainEdits(reference: QuestionMessageRef, captured: UInt64) async {
        var lastID: UUID?
        var attempts = 0
        defer { if registry.generation == captured { edits.removeValue(forKey: reference) } }
        while registry.generation == captured, !Task.isCancelled, let edit = queuedEdits[reference] {
            if lastID != edit.id { attempts = 0; lastID = edit.id }
            if !edit.terminal, uptime() >= edit.deadline { expireDueQuestions(); continue }
            let response = await transport(edit.request)
            guard registry.generation == captured, !Task.isCancelled else { return }
            // A newer rendering replaces a failed/stale edit instead of restoring older controls.
            guard queuedEdits[reference]?.id == edit.id else { continue }
            attempts += 1
            let result = Self.editResult(response, destination: reference.destination)
            if case .accepted = result {
                queuedEdits.removeValue(forKey: reference)
                continue
            }
            if case let .retry(retryAfter) = result {
                let delay = retryAfter ?? pow(2, Double(attempts - 1))
                if attempts < 3, uptime() + delay < edit.deadline {
                    await retryWait(delay)
                    continue
                }
            }
            queuedEdits.removeValue(forKey: reference)
            if !edit.terminal { endLocally(edit.handle) }
        }
    }

    private enum EditResult { case accepted, retry(TimeInterval?), rejected }

    private static func editResult(_ response: QuestionHTTPResponse,
                                   destination: QuestionDestination) -> EditResult {
        guard let status = response.statusCode, status < 500 else { return .retry(nil) }
        let body = (try? JSONSerialization.jsonObject(with: response.body)) as? [String: Any]
        if status == 429 {
            let value = destination == .telegram
                ? (body?["parameters"] as? [String: Any])?["retry_after"] : body?["retry_after"]
            guard let seconds = (value as? NSNumber)?.doubleValue,
                  seconds.isFinite, seconds > 0, seconds <= 600 else { return .rejected }
            return .retry(seconds)
        }
        if destination == .discord { return (200...299).contains(status) ? .accepted : .rejected }
        if (200...299).contains(status), body?["ok"] as? Bool == true { return .accepted }
        // Telegram rejects an idempotent edit when the requested text/controls are already present.
        if status == 400, (body?["description"] as? String)?.contains("message is not modified") == true {
            return .accepted
        }
        return .rejected
    }

    private func retire(_ handle: UUID, preventingReplay: Bool = true) {
        registry.retire(handle: handle, preventingReplay: preventingReplay)
        records.removeValue(forKey: handle)
    }

    private func endLocally(_ handle: UUID) {
        guard let record = records[handle],
              registry.state(handle: handle) == .pending || registry.state(handle: handle) == .invalid else { return }
        registry.returnToLocal(handle: handle)
        onChange(.cleared(record.batch.key))
        callReturnLocal(handle)
        editMessages(handle: handle)
        retire(handle)
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
