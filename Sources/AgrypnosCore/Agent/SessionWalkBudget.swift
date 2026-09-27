import Foundation

/// Cap session-tree walks. Newest mtime first; stop a kind once a fresh busy file exists.
public enum SessionWalkBudget: Sendable {
    public static let maxVisited = 4000

    public static func walksKind(_ kind: AgentKind, included: Set<AgentKind>) -> Bool {
        included.contains(kind)
    }

    /// Prefer newest files. Stop when a write is within `freshness`. Cap keeps the newest `cap`.
    public static func selectNewest(
        _ signals: [SessionFileSignal],
        now: Date,
        freshness: TimeInterval,
        cap: Int = maxVisited
    ) -> [SessionFileSignal] {
        let newestFirst = signals.sorted { $0.modified > $1.modified }
        var picked: [SessionFileSignal] = []
        for signal in newestFirst {
            if picked.count >= cap { break }
            picked.append(signal)
            if now.timeIntervalSince(signal.modified) <= freshness {
                break
            }
        }
        return picked
    }
}
