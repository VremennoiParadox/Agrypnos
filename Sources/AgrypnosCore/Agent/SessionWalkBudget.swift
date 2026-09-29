import Foundation

/// Cap session-tree walks. Newest mtime first; stop a kind once a fresh busy file exists.
public enum SessionWalkBudget: Sendable {
    public static let maxVisited = 4000

    public static func walksKind(_ kind: AgentKind, included: Set<AgentKind>) -> Bool {
        included.contains(kind)
    }

    public static func kindsToWalk(included: Set<AgentKind>, processes: [ProcessRecord]) -> Set<AgentKind> {
        let running = Set(processes.compactMap { AgentKindClassifier.classify(processName: $0.name) })
        return included.intersection(running)
    }

    /// Prefer newest files that still count as busy. Stop when one is within `freshness`.
    public static func selectNewest(
        _ signals: [SessionFileSignal],
        now: Date,
        freshness: TimeInterval,
        cap: Int = maxVisited,
        countTerminalSessions: Bool = false
    ) -> [SessionFileSignal] {
        let newestFirst = signals.sorted { $0.modified > $1.modified }
        var picked: [SessionFileSignal] = []
        for signal in newestFirst {
            if picked.count >= cap { break }
            guard SessionFileLayout.countsTowardBusy(
                signal.url,
                countTerminalSessions: countTerminalSessions
            ) else { continue }
            picked.append(signal)
            if signal.isFresh(now: now, freshness: freshness) {
                break
            }
        }
        return picked
    }

    /// Skip remaining roots for this kind once a file I3 would keep is fresh.
    public static func hasFreshBusy(
        _ signals: [SessionFileSignal],
        now: Date,
        freshness: TimeInterval,
        countTerminalSessions: Bool
    ) -> Bool {
        signals.contains {
            $0.isFresh(now: now, freshness: freshness)
                && SessionFileLayout.countsTowardBusy(
                    $0.url,
                    countTerminalSessions: countTerminalSessions
                )
        }
    }
}
