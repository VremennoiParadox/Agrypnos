import Foundation

public struct QuestionKey: Hashable, Sendable {
    public let provider: AgentKind
    public let instanceID: String
    public let sessionID: String
    public let requestID: String

    public init(provider: AgentKind, instanceID: String, sessionID: String, requestID: String) {
        self.provider = provider
        self.instanceID = instanceID
        self.sessionID = sessionID
        self.requestID = requestID
    }
}

public struct QuestionOption: Equatable, Sendable {
    public let id: String
    public let label: String
    public let detail: String?

    public init(id: String, label: String, detail: String? = nil) {
        self.id = id
        self.label = label
        self.detail = detail
    }
}

public struct AgentQuestion: Equatable, Sendable {
    public let id: String
    public let prompt: String
    public let options: [QuestionOption]
    public let multiple: Bool
    public let allowsEmpty: Bool
    public let allowsFreeText: Bool

    public init(id: String, prompt: String, options: [QuestionOption], multiple: Bool = false,
                allowsEmpty: Bool = false, allowsFreeText: Bool = false) {
        self.id = id
        self.prompt = prompt
        self.options = options
        self.multiple = multiple
        self.allowsEmpty = allowsEmpty
        self.allowsFreeText = allowsFreeText
    }
}

public struct QuestionBatch: Equatable, Sendable {
    public let key: QuestionKey
    public let projectLabel: String?
    public let questions: [AgentQuestion]
    public let receivedUptime: TimeInterval
    public let deadlineUptime: TimeInterval

    public init(key: QuestionKey, projectLabel: String? = nil, questions: [AgentQuestion],
                receivedUptime: TimeInterval, deadlineUptime: TimeInterval) {
        self.key = key
        self.projectLabel = projectLabel
        self.questions = questions
        self.receivedUptime = receivedUptime
        self.deadlineUptime = deadlineUptime.isFinite ? min(deadlineUptime, receivedUptime + 600) : deadlineUptime
    }

    public func panelText(at index: Int) -> String {
        guard questions.indices.contains(index) else { return "" }
        let question = questions[index]
        var lines = [key.provider.displayName]
        if let projectLabel { lines.append(projectLabel) }
        lines += ["Session: \(key.sessionID)", "", question.prompt]
        for (offset, option) in question.options.enumerated() {
            lines.append("\(offset + 1). \(option.label)")
            if let detail = option.detail, !detail.isEmpty { lines.append(detail) }
        }
        return lines.joined(separator: "\n")
    }

    var isValid: Bool {
        let identity = [key.instanceID, key.sessionID, key.requestID]
        guard identity.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              receivedUptime.isFinite, receivedUptime >= 0,
              deadlineUptime.isFinite, deadlineUptime > receivedUptime,
              (1...4).contains(questions.count), Set(questions.map(\.id)).count == questions.count
        else { return false }
        var bytes = identity.reduce(0) { $0 + $1.utf8.count } + (projectLabel?.utf8.count ?? 0)
        for (index, question) in questions.enumerated() {
            guard !question.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !question.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  (1...20).contains(question.options.count),
                  Set(question.options.map(\.id)).count == question.options.count,
                  Set(question.options.map { $0.label.trimmingCharacters(in: .whitespacesAndNewlines) }).count == question.options.count,
                  question.options.allSatisfy({ !$0.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
                  panelText(at: index).utf16.count <= 1800 else { return false }
            bytes += question.id.utf8.count + question.prompt.utf8.count
            for option in question.options {
                bytes += option.id.utf8.count + option.label.utf8.count + (option.detail?.utf8.count ?? 0)
            }
        }
        return bytes <= 256 * 1024
    }
}

public struct QuestionSelection: Equatable, Sendable {
    public let questionID: String
    public let optionIDs: [String]
}

public struct QuestionAnswer: Equatable, Sendable {
    public let key: QuestionKey
    public let selections: [QuestionSelection]
}

public enum QuestionDestination: Hashable, Sendable { case telegram, discord }

public struct QuestionMessageRef: Hashable, Sendable {
    public let destination: QuestionDestination
    public let destinationID: String
    public let messageID: String

    public init(destination: QuestionDestination, destinationID: String, messageID: String) {
        self.destination = destination
        self.destinationID = destinationID
        self.messageID = messageID
    }
}

public struct QuestionCallback: Sendable {
    public let reference: QuestionMessageRef
    public let senderID: String
    public let actionToken: String
    public let generation: UInt64

    public init(reference: QuestionMessageRef, senderID: String, actionToken: String, generation: UInt64) {
        self.reference = reference
        self.senderID = senderID
        self.actionToken = actionToken
        self.generation = generation
    }
}

public enum QuestionAction: Hashable, Sendable {
    case choose(questionID: String, optionID: String)
    case next, back, send, returnLocal
}

public struct QuestionControl: Equatable, Sendable {
    public let action: QuestionAction
    public let token: String
}

public enum QuestionDelivery: Equatable, Sendable {
    case accepted, returnedToHook, rejected, unconfirmed
}

public enum QuestionState: Equatable, Sendable {
    case pending, submitting, delivered(QuestionDelivery), local, expired, invalid
}

public struct QuestionView: Sendable {
    public let handle: UUID
    public let batch: QuestionBatch
    public let selections: [String: Set<String>]
    public let page: Int
    public let state: QuestionState
    public let generation: UInt64
    public let controls: [QuestionControl]

    public var questionIndex: Int { page % batch.questions.count }
    public var isReview: Bool { page >= batch.questions.count }
}

public enum QuestionEffect: Equatable, Sendable {
    case ignore
    case rerender(UUID, QuestionDestination)
    case submit(UUID, QuestionAnswer)
    case returnLocal(UUID, QuestionKey)
}
