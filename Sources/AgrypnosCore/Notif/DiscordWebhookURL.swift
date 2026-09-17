import Foundation

/// Discord incoming webhook URLs only: HTTPS, known host, `/api/webhooks/<id>/<token>`.
public enum DiscordWebhookURL: Sendable {
    static let hosts: Set<String> = [
        "discord.com",
        "discordapp.com",
        "canary.discord.com",
        "ptb.discord.com",
    ]

    static let tokenCharacters = CharacterSet.alphanumerics
        .union(CharacterSet(charactersIn: "_-."))

    public static func parse(_ raw: String) -> URL? {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("<"), trimmed.hasSuffix(">"), trimmed.count >= 2 {
            trimmed = String(trimmed.dropFirst().dropLast())
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return nil }
        guard url.scheme?.lowercased() == "https" else { return nil }
        guard let host = url.host?.lowercased(), hosts.contains(host) else { return nil }
        if let port = url.port, port != 443 { return nil }
        guard url.user == nil, url.password == nil else { return nil }
        if let fragment = url.fragment, !fragment.isEmpty { return nil }

        var path = url.path
        while path.count > 1, path.hasSuffix("/") {
            path.removeLast()
        }
        let parts = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 5,
              parts[0].isEmpty,
              parts[1] == "api",
              parts[2] == "webhooks"
        else {
            return nil
        }
        let id = parts[3]
        let token = parts[4]
        guard !id.isEmpty,
              id.unicodeScalars.allSatisfy({ $0.isASCII && CharacterSet.decimalDigits.contains($0) })
        else {
            return nil
        }
        guard !token.isEmpty,
              token.unicodeScalars.allSatisfy({ $0.isASCII && tokenCharacters.contains($0) })
        else {
            return nil
        }
        return url
    }
}
