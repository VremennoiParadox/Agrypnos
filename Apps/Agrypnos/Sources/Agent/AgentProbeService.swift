import Foundation

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

enum ProcessListReader {
    static func records() -> [ProcessRecord] {
        let stdout = ProcessRunner.run("/bin/ps", ["-axo", "pid=", "-o", "pcpu=", "-o", "args="]).out
        return ProcessTableParser.parse(stdout: stdout)
    }
}

enum SessionFileWalker {
    static func signals(home: URL, env: [String: String]) -> [SessionFileSignal] {
        var collected: [SessionFileSignal] = []
        let roots = SessionFileLayout.roots(home: home, env: env)
        for (kind, urls) in roots {
            for root in urls {
                collected.append(contentsOf: walk(root: root, kind: kind))
            }
        }
        return collected
    }

    static func walk(root: URL, kind: AgentKind) -> [SessionFileSignal] {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: root.path, isDirectory: &isDir), isDir.boolValue else { return [] }
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var signals: [SessionFileSignal] = []
        var visited = 0
        for case let url as URL in enumerator {
            visited += 1
            if visited > 4000 { break }
            if enumerator.level > 6 { enumerator.skipDescendants(); continue }
            guard SessionFileLayout.isRelevantFile(url, kind: kind) else { continue }
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                  values.isRegularFile == true,
                  let modified = values.contentModificationDate
            else { continue }
            signals.append(SessionFileSignal(url: url, modified: modified, kind: kind))
        }
        return signals
    }
}

enum AgentProbeService {
    static func snapshot(now: Date, freshness: TimeInterval) -> AgentSnapshot {
        let engine = AgentHeuristicEngine(
            config: AgentHeuristicConfig(sessionFreshness: freshness, claudeCodexCPUBusyThreshold: 5)
        )
        return engine.evaluate(
            processes: ProcessListReader.records(),
            sessionWrites: SessionFileWalker.signals(
                home: FileManager.default.homeDirectoryForCurrentUser,
                env: ProcessInfo.processInfo.environment
            ),
            now: now
        )
    }
}
