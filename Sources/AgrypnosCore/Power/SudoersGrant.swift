import Foundation

public enum SudoersGrant: Sendable {
    public static let pmsetClause =
        "ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1"

    public static func isSafeUsername(_ username: String) -> Bool {
        let scalars = username.unicodeScalars
        guard !scalars.isEmpty else { return false }
        return scalars.allSatisfy { scalar in
            CharacterSet.alphanumerics.contains(scalar)
                || scalar == "." || scalar == "_" || scalar == "-"
        }
    }

    public static func line(username: String) -> String? {
        guard isSafeUsername(username) else { return nil }
        return "\(username) \(pmsetClause)"
    }
}
