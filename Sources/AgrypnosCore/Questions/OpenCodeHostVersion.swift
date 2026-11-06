/// OpenCode builds that may connect: the Mac-checked 1.18.32 and anything newer.
/// The plugin itself also requires `question.reply` and `question.list`.
public enum OpenCodeHostVersion {
    public static let minimum = [1, 18, 32]

    public static func isSupported(_ version: String) -> Bool {
        let release = version.split(separator: "-", maxSplits: 1).first ?? ""
        let parts = release.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard parts.count == 3 else { return false }
        let numbers = parts.compactMap { $0 }
        guard numbers.count == 3 else { return false }
        return !numbers.lexicographicallyPrecedes(minimum)
    }
}
