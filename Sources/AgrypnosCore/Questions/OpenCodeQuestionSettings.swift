import Foundation

/// Stored with bot secrets, including the optional local-server password.
public struct OpenCodeQuestionSettings: Codable, Equatable, Sendable {
    public var endpoint: String
    public var directory: String
    public var username: String
    public var password: String

    public init(endpoint: String, directory: String, username: String = "opencode", password: String = "") {
        self.endpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        self.directory = directory.trimmingCharacters(in: .whitespacesAndNewlines)
        self.username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        self.password = password
    }
}
