import Foundation
import CoreFoundation

public enum OpenCodeBridgeMessage: Equatable, Sendable {
    case hello(protocolVersion: Int, token: String, instanceID: UUID, generation: UUID,
               hostVersion: String, directory: String, projectLabel: String?)
    case ready(generation: UUID)
    case asked(original: Data)
    case resolved(sessionID: String, requestID: String)
    case snapshot(originals: [Data])
    case reply(attemptID: UUID, sessionID: String, requestID: String, answers: [[String]])
    case local(sessionID: String, requestID: String)
    case result(attemptID: UUID, delivery: QuestionDelivery)
    public enum Error: Swift.Error { case invalidFrame, oversized }
    public static let maximumFrameBytes = 262144

    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard let left = try? lhs.encodedFrame(), let right = try? rhs.encodedFrame() else { return false }
        return left == right
    }

    public func encodedFrame() throws -> Data {
        var object: [String: Any]
        switch self {
        case let .hello(version, token, instance, generation, host, directory, label):
            object = ["type": "hello", "protocolVersion": version, "token": token,
                "instanceID": instance.uuidString, "generation": generation.uuidString,
                "hostVersion": host, "directory": directory]
            if let label { object["projectLabel"] = label }
        case let .ready(generation): object = ["type": "ready", "generation": generation.uuidString]
        case let .asked(original): object = ["type": "asked", "original": try Self.original(original)]
        case let .resolved(session, request): object = ["type": "resolved", "sessionID": session, "requestID": request]
        case let .snapshot(originals):
            guard originals.count <= 32 else { throw Error.oversized }
            object = ["type": "snapshot", "originals": try originals.map(Self.original)]
        case let .reply(attempt, session, request, answers):
            object = ["type": "reply", "attemptID": attempt.uuidString, "sessionID": session,
                "requestID": request, "answers": answers]
        case let .local(session, request): object = ["type": "local", "sessionID": session, "requestID": request]
        case let .result(attempt, delivery):
            let value: String
            switch delivery {
            case .accepted: value = "accepted"
            case .rejected: value = "rejected"
            case .unconfirmed: value = "unconfirmed"
            case .returnedToHook: throw Error.invalidFrame
            }
            object = ["type": "result", "attemptID": attempt.uuidString, "delivery": value]
        }
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) + Data([10])
        guard data.count <= Self.maximumFrameBytes else { throw Error.oversized }
        return data
    }

    private static func original(_ data: Data) throws -> [String: Any] {
        guard data.count <= maximumFrameBytes,
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw Error.invalidFrame }
        return object
    }

    static func decode(_ data: Data) throws -> Self {
        guard String(data: data, encoding: .utf8) != nil,
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = object["type"] as? String else { throw Error.invalidFrame }
        func keys(_ expected: [String], optional: [String] = []) throws {
            let actual = Set(object.keys)
            guard Set(expected).isSubset(of: actual), actual.isSubset(of: Set(expected + optional + ["type"])) else { throw Error.invalidFrame }
        }
        func string(_ key: String, max: Int = 4096) throws -> String {
            guard let value = object[key] as? String, !value.isEmpty, value.utf8.count <= max,
                  !value.contains("\0") else { throw Error.invalidFrame }
            return value
        }
        func uuid(_ key: String) throws -> UUID {
            guard let value = UUID(uuidString: try string(key, max: 36)) else { throw Error.invalidFrame }
            return value
        }
        switch type {
        case "hello":
            try keys(["protocolVersion", "token", "instanceID", "generation", "hostVersion", "directory"], optional: ["projectLabel"])
            guard let version = object["protocolVersion"] as? Int,
                  (object["protocolVersion"] as? NSNumber).map { CFGetTypeID($0) != CFBooleanGetTypeID() } == true, try string("directory").hasPrefix("/") else { throw Error.invalidFrame }
            let label = object["projectLabel"] == nil ? nil : try string("projectLabel", max: 256)
            return try .hello(protocolVersion: version, token: string("token", max: 256), instanceID: uuid("instanceID"),
                generation: uuid("generation"), hostVersion: string("hostVersion", max: 32), directory: string("directory"), projectLabel: label)
        case "ready": try keys(["generation"]); return try .ready(generation: uuid("generation"))
        case "asked":
            try keys(["original"])
            guard let original = object["original"] as? [String: Any] else { throw Error.invalidFrame }
            return .asked(original: try JSONSerialization.data(withJSONObject: original, options: [.sortedKeys]))
        case "resolved", "local":
            try keys(["sessionID", "requestID"])
            let session = try string("sessionID"), request = try string("requestID", max: 100)
            return type == "local" ? .local(sessionID: session, requestID: request) : .resolved(sessionID: session, requestID: request)
        case "snapshot":
            try keys(["originals"])
            guard let originals = object["originals"] as? [[String: Any]], originals.count <= 32 else { throw Error.invalidFrame }
            return .snapshot(originals: try originals.map { try JSONSerialization.data(withJSONObject: $0, options: [.sortedKeys]) })
        case "reply":
            try keys(["attemptID", "sessionID", "requestID", "answers"])
            guard let answers = object["answers"] as? [[String]], (1...4).contains(answers.count),
                  answers.allSatisfy({ $0.count <= 20 && $0.allSatisfy { !$0.isEmpty && $0.utf8.count <= 4096 } }) else { throw Error.invalidFrame }
            return try .reply(attemptID: uuid("attemptID"), sessionID: string("sessionID"), requestID: string("requestID", max: 100), answers: answers)
        case "result":
            try keys(["attemptID", "delivery"])
            let value = try string("delivery", max: 16)
            guard ["accepted", "rejected", "unconfirmed"].contains(value) else { throw Error.invalidFrame }
            return try .result(attemptID: uuid("attemptID"), delivery: value == "accepted" ? .accepted : value == "rejected" ? .rejected : .unconfirmed)
        default: throw Error.invalidFrame
        }
    }
}

public struct OpenCodeBridgeFrameDecoder: Sendable {
    private var pending = Data()
    public init() {}
    public mutating func append(_ bytes: Data) throws -> [OpenCodeBridgeMessage] {
        var messages: [OpenCodeBridgeMessage] = []
        // Bound allocation even when one read contains many complete frames.
        for byte in bytes {
            if byte == 10 {
                guard !pending.isEmpty else { throw OpenCodeBridgeMessage.Error.invalidFrame }
                messages.append(try OpenCodeBridgeMessage.decode(pending)); pending.removeAll(keepingCapacity: true)
            } else {
                guard pending.count < OpenCodeBridgeMessage.maximumFrameBytes - 1 else { throw OpenCodeBridgeMessage.Error.oversized }
                pending.append(byte)
            }
        }
        return messages
    }
}
