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
    static func signals(
        home: URL,
        env: [String: String],
        countTerminalSessions: Bool,
        included: Set<AgentKind>,
        now: Date,
        freshness: TimeInterval
    ) -> [SessionFileSignal] {
        var collected: [SessionFileSignal] = []
        let roots = SessionFileLayout.roots(home: home, env: env, included: included)
        for (kind, urls) in roots {
            guard SessionWalkBudget.walksKind(kind, included: included) else { continue }
            var kindSignals: [SessionFileSignal] = []
            rootLoop: for root in urls {
                if kind == .cursor, root.lastPathComponent == "projects" {
                    let names = projectDirectoryNames(in: root)
                    for sub in SessionFileLayout.cursorWalkRoots(
                        projectsRoot: root,
                        projectNames: names,
                        includeTerminals: countTerminalSessions
                    ) {
                        kindSignals.append(contentsOf: walk(
                            root: sub,
                            kind: kind,
                            now: now,
                            freshness: freshness,
                            countTerminalSessions: countTerminalSessions
                        ))
                        if SessionWalkBudget.hasFreshBusy(
                            kindSignals,
                            now: now,
                            freshness: freshness,
                            countTerminalSessions: countTerminalSessions
                        ) {
                            break rootLoop
                        }
                    }
                } else if kind == .openCode {
                    kindSignals.append(contentsOf: openCodeSignals(
                        dataHome: root,
                        now: now,
                        freshness: freshness,
                        countTerminalSessions: countTerminalSessions
                    ))
                    if SessionWalkBudget.hasFreshBusy(
                        kindSignals,
                        now: now,
                        freshness: freshness,
                        countTerminalSessions: countTerminalSessions
                    ) {
                        break
                    }
                } else {
                    kindSignals.append(contentsOf: walk(
                        root: root,
                        kind: kind,
                        now: now,
                        freshness: freshness,
                        countTerminalSessions: countTerminalSessions
                    ))
                    if SessionWalkBudget.hasFreshBusy(
                        kindSignals,
                        now: now,
                        freshness: freshness,
                        countTerminalSessions: countTerminalSessions
                    ) {
                        break
                    }
                }
            }
            if !countTerminalSessions {
                kindSignals.removeAll { SessionFileLayout.isTerminalSessionPath($0.url) }
            }
            collected.append(contentsOf: SessionWalkBudget.selectNewest(
                kindSignals,
                now: now,
                freshness: freshness,
                countTerminalSessions: countTerminalSessions
            ))
        }
        return collected
    }

    static func projectDirectoryNames(in root: URL) -> [String] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return items.compactMap { url in
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { return nil }
            let name = url.lastPathComponent
            if SessionFileLayout.shouldSkipDirectory(name) { return nil }
            return name
        }.sorted()
    }

    static func openCodeSignals(
        dataHome: URL,
        now: Date,
        freshness: TimeInterval,
        countTerminalSessions: Bool
    ) -> [SessionFileSignal] {
        var collected: [SessionFileSignal] = []
        for file in SessionFileLayout.openCodeDataRootFiles(dataHome: dataHome) {
            collected.append(contentsOf: fileSignal(url: file, kind: .openCode))
            if SessionWalkBudget.hasFreshBusy(
                collected,
                now: now,
                freshness: freshness,
                countTerminalSessions: countTerminalSessions
            ) {
                return collected
            }
        }
        let names = projectDirectoryNames(in: dataHome.appendingPathComponent("project"))
        for sub in SessionFileLayout.openCodeWalkRoots(dataHome: dataHome, projectNames: names) {
            collected.append(contentsOf: walk(
                root: sub,
                kind: .openCode,
                now: now,
                freshness: freshness,
                countTerminalSessions: countTerminalSessions
            ))
            if SessionWalkBudget.hasFreshBusy(
                collected,
                now: now,
                freshness: freshness,
                countTerminalSessions: countTerminalSessions
            ) {
                break
            }
        }
        return collected
    }

    static func fileSignal(url: URL, kind: AgentKind) -> [SessionFileSignal] {
        guard SessionFileLayout.isRelevantFile(url, kind: kind) else { return [] }
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue else { return [] }
        guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
              let modified = values.contentModificationDate
        else { return [] }
        return [SessionFileSignal(url: url, modified: modified, kind: kind)]
    }

    /// Newest-mtime first. Stop this root once a fresh file that still counts as busy is found. Cap 4000 visits.
    static func walk(
        root: URL,
        kind: AgentKind,
        now: Date,
        freshness: TimeInterval,
        countTerminalSessions: Bool
    ) -> [SessionFileSignal] {
        var collected: [SessionFileSignal] = []
        var visited = 0
        func visit(_ dir: URL, depth: Int) -> Bool {
            if depth > 6 { return false }
            let fm = FileManager.default
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else { return false }
            guard let items = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [
                    .contentModificationDateKey,
                    .isDirectoryKey,
                    .isRegularFileKey,
                ],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { return false }
            let ranked = items.compactMap { url -> (URL, Date, Bool)? in
                guard let values = try? url.resourceValues(
                    forKeys: [.contentModificationDateKey, .isDirectoryKey, .isRegularFileKey]
                ) else { return nil }
                let modified = values.contentModificationDate ?? Date.distantPast
                return (url, modified, values.isDirectory == true)
            }
            .sorted { $0.1 > $1.1 }
            for (url, modified, isDirectory) in ranked {
                visited += 1
                if visited > SessionWalkBudget.maxVisited { return true }
                if SessionFileLayout.shouldSkipDirectory(
                    url.lastPathComponent,
                    countTerminalSessions: countTerminalSessions
                ) { continue }
                if isDirectory {
                    if visit(url, depth: depth + 1) { return true }
                    continue
                }
                guard SessionFileLayout.isRelevantFile(url, kind: kind) else { continue }
                collected.append(SessionFileSignal(url: url, modified: modified, kind: kind))
                if now.timeIntervalSince(modified) <= freshness,
                   SessionFileLayout.countsTowardBusy(
                       url,
                       countTerminalSessions: countTerminalSessions
                   )
                {
                    return true
                }
            }
            return false
        }
        _ = visit(root, depth: 0)
        return collected
    }
}

enum AgentProbeService {
    static func snapshot(
        now: Date,
        freshness: TimeInterval,
        countTerminalSessions: Bool = false,
        included: Set<AgentKind> = Set(AgentKind.allCases)
    ) -> AgentSnapshot {
        let engine = AgentHeuristicEngine(
            config: AgentHeuristicConfig(
                sessionFreshness: freshness,
                claudeCodexCPUBusyThreshold: 5,
                countTerminalSessionsAsBusy: countTerminalSessions
            )
        )
        let processes = ProcessListReader.records()
        let walkIncluded = SessionWalkBudget.kindsToWalk(included: included, processes: processes)
        return engine.evaluate(
            processes: processes,
            sessionWrites: SessionFileWalker.signals(
                home: FileManager.default.homeDirectoryForCurrentUser,
                env: ProcessInfo.processInfo.environment,
                countTerminalSessions: countTerminalSessions,
                included: walkIncluded,
                now: now,
                freshness: freshness
            ),
            now: now
        )
    }
}
