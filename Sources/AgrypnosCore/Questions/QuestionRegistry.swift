import Foundation

public struct QuestionRegistry: Sendable {
    private struct Draft: Sendable {
        var selections: [String: Set<String>] = [:]
        var page = 0
        var tokens: [QuestionAction: String] = [:]
    }

    private struct Entry: Sendable {
        var batch: QuestionBatch
        var state: QuestionState = .pending
        var messages: [QuestionDestination: QuestionMessageRef] = [:]
        var drafts: [QuestionDestination: Draft] = [:]
    }

    private var entries: [UUID: Entry] = [:]
    public private(set) var generation: UInt64 = 0

    public init() {}

    public var pendingDeadlines: [QuestionKey: TimeInterval] {
        Dictionary(uniqueKeysWithValues: entries.values.filter { $0.state == .pending }
            .map { ($0.batch.key, $0.batch.deadlineUptime) })
    }

    @discardableResult
    public mutating func insert(_ batch: QuestionBatch, handle: UUID) -> Bool {
        if let existing = entries.first(where: { $0.value.batch.key == batch.key }) {
            if existing.value.batch.questions != batch.questions || existing.value.batch.projectLabel != batch.projectLabel {
                entries[existing.key]?.state = .invalid
            } else if batch.isValid, batch.deadlineUptime < existing.value.batch.deadlineUptime {
                entries[existing.key]?.batch = QuestionBatch(key: batch.key,
                    projectLabel: batch.projectLabel, questions: batch.questions,
                    receivedUptime: existing.value.batch.receivedUptime,
                    deadlineUptime: batch.deadlineUptime)
            }
            return false
        }
        guard batch.isValid else { return false }
        // Terminal records prevent replay until the source is cleared; they consume the same bounded capacity.
        guard entries.count < 32, entries[handle] == nil else { return false }
        entries[handle] = Entry(batch: batch)
        return true
    }

    @discardableResult
    public mutating func bindMessage(handle: UUID, reference: QuestionMessageRef) -> Bool {
        guard var entry = entries[handle], entry.state == .pending,
              !reference.destinationID.isEmpty, !reference.messageID.isEmpty else { return false }
        if let existing = entry.messages[reference.destination] { return existing == reference }
        guard !entries.contains(where: { $0.key != handle && $0.value.messages[reference.destination] == reference })
        else { return false }
        var draft = Draft()
        var actions: [QuestionAction] = [.next, .back, .send, .returnLocal]
        for question in entry.batch.questions {
            actions += question.options.map { .choose(questionID: question.id, optionID: $0.id) }
        }
        for action in actions { draft.tokens[action] = UUID().uuidString }
        entry.messages[reference.destination] = reference
        entry.drafts[reference.destination] = draft
        entries[handle] = entry
        return true
    }

    public func view(handle: UUID, reference: QuestionMessageRef) -> QuestionView? {
        guard let entry = entries[handle], entry.messages[reference.destination] == reference,
              let draft = entry.drafts[reference.destination] else { return nil }
        let actions = entry.state == .pending ? visibleActions(entry.batch, draft: draft) : []
        return QuestionView(handle: handle, batch: entry.batch, selections: draft.selections,
            page: draft.page, state: entry.state, generation: generation,
            controls: actions.compactMap { action in
                draft.tokens[action].map { QuestionControl(action: action, token: $0) }
            })
    }

    public mutating func handle(_ callback: QuestionCallback, authorizedUserID: String,
                                now: TimeInterval) -> QuestionEffect {
        guard !authorizedUserID.isEmpty, callback.senderID == authorizedUserID,
              callback.generation == generation, now.isFinite,
              let found = entries.first(where: { $0.value.messages[callback.reference.destination] == callback.reference }),
              var draft = found.value.drafts[callback.reference.destination],
              found.value.state == .pending,
              now >= found.value.batch.receivedUptime, now < found.value.batch.deadlineUptime,
              let action = draft.tokens.first(where: { $0.value == callback.actionToken })?.key,
              visibleActions(found.value.batch, draft: draft).contains(action) else { return .ignore }
        let handle = found.key, batch = found.value.batch
        switch action {
        case let .choose(questionID, optionID):
            var selected = draft.selections[questionID] ?? []
            let question = batch.questions[draft.page]
            if question.multiple || question.allowsEmpty {
                if selected.contains(optionID) { selected.remove(optionID) }
                else { if !question.multiple { selected.removeAll() }; selected.insert(optionID) }
            } else { selected = [optionID] }
            draft.selections[questionID] = selected
        case .next:
            if draft.page < batch.questions.count {
                guard validSelection(batch.questions[draft.page], draft: draft) else { return .ignore }
            }
            draft.page += 1
        case .back:
            draft.page -= 1
        case .send:
            guard batch.questions.allSatisfy({ validSelection($0, draft: draft) }) else { return .ignore }
            let selections = batch.questions.map { question in
                QuestionSelection(questionID: question.id, optionIDs: question.options
                    .filter { draft.selections[question.id]?.contains($0.id) == true }.map(\.id))
            }
            // Reserve before returning an effect that can yield to network/provider work.
            entries[handle]?.state = .submitting
            return .submit(handle, QuestionAnswer(key: batch.key, selections: selections))
        case .returnLocal:
            entries[handle]?.state = .local
            return .returnLocal(handle, batch.key)
        }
        entries[handle]?.drafts[callback.reference.destination] = draft
        return .rerender(handle, callback.reference.destination)
    }

    public mutating func expire(now: TimeInterval) -> Set<QuestionKey> {
        guard now.isFinite else { return [] }
        var expired: Set<QuestionKey> = []
        for (handle, entry) in entries where entry.state == .pending && now >= entry.batch.deadlineUptime {
            entries[handle]?.state = .expired
            expired.insert(entry.batch.key)
        }
        return expired
    }

    public mutating func complete(handle: UUID, result: QuestionDelivery) {
        guard entries[handle]?.state == .submitting else { return }
        entries[handle]?.state = .delivered(result)
    }

    public mutating func returnToLocal(handle: UUID) {
        guard entries[handle]?.state == .pending else { return }
        entries[handle]?.state = .local
    }

    public mutating func cancel(key: QuestionKey) {
        entries = entries.filter { $0.value.batch.key != key }
    }

    public mutating func invalidateAll() {
        generation &+= 1
        entries.removeAll()
    }

    private func validSelection(_ question: AgentQuestion, draft: Draft) -> Bool {
        let selected = draft.selections[question.id] ?? []
        guard question.allowsEmpty || !selected.isEmpty else { return false }
        return question.multiple || selected.count <= 1
    }

    private func visibleActions(_ batch: QuestionBatch, draft: Draft) -> [QuestionAction] {
        let count = batch.questions.count
        var actions: [QuestionAction] = []
        if draft.page < count {
            let question = batch.questions[draft.page]
            actions += question.options.map { .choose(questionID: question.id, optionID: $0.id) }
        }
        if draft.page > 0 { actions.append(.back) }
        if draft.page < count * 2 - 1 { actions.append(.next) } else { actions.append(.send) }
        actions.append(.returnLocal)
        return actions
    }
}
