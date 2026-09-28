import Foundation

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

struct ProbeCollection<Value> {
    var values: [Value] = []
    var complete = true

    mutating func append(_ other: Self) {
        values.append(contentsOf: other.values)
        complete = complete && other.complete
    }
}

enum ProcessListReader {
    static func records(
        run: () -> (exit: Int32, out: String, err: String) = {
            ProcessRunner.run("/bin/ps", ["-axo", "pid=", "-o", "pcpu=", "-o", "args="])
        }
    ) -> ProbeCollection<ProcessRecord> {
        let result = run()
        guard result.exit == 0 else { return ProbeCollection(complete: false) }
        let records = ProcessTableParser.parse(stdout: result.out)
        let rows = result.out.split(whereSeparator: \.isNewline).filter {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return ProbeCollection(values: records, complete: records.count == rows.count)
    }
}

struct SessionFileInfo {
    var isDirectory: Bool
    var modified: Date?
}

/// Small filesystem seam for exercising the real walker without permissions or pmset changes.
struct SessionFileAccess {
    var info: (URL) throws -> SessionFileInfo = { url in
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
        guard let isDirectory = values.isDirectory else {
            throw CocoaError(.fileReadUnknown)
        }
        return SessionFileInfo(isDirectory: isDirectory, modified: values.contentModificationDate)
    }
    var children: (URL) throws -> [URL] = { url in
        try FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )
    }

    static func isMissing(_ error: Error) -> Bool {
        let error = error as NSError
        if error.domain == NSCocoaErrorDomain, (error.code == NSFileNoSuchFileError || error.code == NSFileReadNoSuchFileError) { return true }
        if error.domain == NSPOSIXErrorDomain, error.code == Int(ENOENT) { return true }
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? Error {
            return isMissing(underlying)
        }
        return false
    }
}

enum SessionFileWalker {
    static func signals(
        home: URL, env: [String: String], countTerminalSessions: Bool,
        included: Set<AgentKind>, now: Date, freshness: TimeInterval,
        access: SessionFileAccess = SessionFileAccess()
    ) -> ProbeCollection<SessionFileSignal> {
        var collected = ProbeCollection<SessionFileSignal>()
        for (kind, urls) in SessionFileLayout.roots(home: home, env: env, included: included) {
            var kindSignals = ProbeCollection<SessionFileSignal>()
            rootLoop: for root in urls {
                var walkRoots = [root]
                if kind == .cursor, root.lastPathComponent == "projects" {
                    let names = projectDirectoryNames(in: root, access: access)
                    kindSignals.complete = kindSignals.complete && names.complete
                    walkRoots = SessionFileLayout.cursorWalkRoots(
                        projectsRoot: root, projectNames: names.values,
                        includeTerminals: countTerminalSessions
                    )
                } else if kind == .openCode {
                    for file in SessionFileLayout.openCodeDataRootFiles(dataHome: root) {
                        kindSignals.append(fileSignal(url: file, kind: kind, access: access))
                    }
                    let names = projectDirectoryNames(in: root.appendingPathComponent("project"), access: access)
                    kindSignals.complete = kindSignals.complete && names.complete
                    walkRoots = SessionFileLayout.openCodeWalkRoots(dataHome: root, projectNames: names.values)
                }
                for sub in walkRoots {
                    if SessionWalkBudget.hasFreshBusy(kindSignals.values, now: now, freshness: freshness,
                                                     countTerminalSessions: countTerminalSessions) {
                        break rootLoop
                    }
                    kindSignals.append(walk(root: sub, kind: kind, now: now, freshness: freshness,
                                            countTerminalSessions: countTerminalSessions, access: access))
                }
            }
            if !countTerminalSessions {
                kindSignals.values.removeAll { SessionFileLayout.isTerminalSessionPath($0.url) }
            }
            kindSignals.values = SessionWalkBudget.selectNewest(
                kindSignals.values, now: now, freshness: freshness, countTerminalSessions: countTerminalSessions
            )
            collected.append(kindSignals)
        }
        return collected
    }

    static func projectDirectoryNames(in root: URL, access: SessionFileAccess) -> ProbeCollection<String> {
        var result = ProbeCollection<String>()
        do {
            guard try access.info(root).isDirectory else { return ProbeCollection(complete: false) }
            for url in try access.children(root) {
                if SessionFileLayout.shouldSkipDirectory(url.lastPathComponent) { continue }
                do {
                    if try access.info(url).isDirectory { result.values.append(url.lastPathComponent) }
                } catch { result.complete = false }
            }
        } catch {
            result.complete = SessionFileAccess.isMissing(error)
        }
        result.values.sort()
        return result
    }

    static func fileSignal(url: URL, kind: AgentKind, access: SessionFileAccess) -> ProbeCollection<SessionFileSignal> {
        guard SessionFileLayout.isRelevantFile(url, kind: kind) else { return ProbeCollection() }
        do {
            let info = try access.info(url)
            guard !info.isDirectory, let modified = info.modified else { return ProbeCollection(complete: false) }
            return ProbeCollection(values: [SessionFileSignal(url: url, modified: modified, kind: kind)])
        } catch {
            return ProbeCollection(complete: SessionFileAccess.isMissing(error))
        }
    }

    /// Newest first; a cap is incomplete evidence, whereas a fresh positive needs no exhaustive walk.
    static func walk(
        root: URL, kind: AgentKind, now: Date, freshness: TimeInterval,
        countTerminalSessions: Bool, access: SessionFileAccess = SessionFileAccess()
    ) -> ProbeCollection<SessionFileSignal> {
        var collected = ProbeCollection<SessionFileSignal>()
        var visited = 0
        func visit(_ dir: URL, depth: Int, optionalRoot: Bool = false) -> Bool {
            if depth > 6 { collected.complete = false; return false }
            let items: [URL]
            do {
                guard try access.info(dir).isDirectory else { collected.complete = false; return false }
                items = try access.children(dir)
            } catch {
                if !optionalRoot || !SessionFileAccess.isMissing(error) { collected.complete = false }
                return false
            }
            let ranked = items.compactMap { url -> (URL, SessionFileInfo)? in
                if SessionFileLayout.shouldSkipDirectory(url.lastPathComponent,
                                                        countTerminalSessions: countTerminalSessions) { return nil }
                do { return (url, try access.info(url)) }
                catch { collected.complete = false; return nil }
            }.sorted { ($0.1.modified ?? .distantPast) > ($1.1.modified ?? .distantPast) }
            for (url, info) in ranked {
                visited += 1
                if visited > SessionWalkBudget.maxVisited { collected.complete = false; return true }
                if info.isDirectory {
                    if visit(url, depth: depth + 1) { return true }
                    continue
                }
                guard SessionFileLayout.isRelevantFile(url, kind: kind) else { continue }
                guard let modified = info.modified else { collected.complete = false; continue }
                collected.values.append(SessionFileSignal(url: url, modified: modified, kind: kind))
                if now.timeIntervalSince(modified) <= freshness,
                   SessionFileLayout.countsTowardBusy(url, countTerminalSessions: countTerminalSessions) { return true }
            }
            return false
        }
        _ = visit(root, depth: 0, optionalRoot: true)
        return collected
    }
}

enum AgentProbeService {
    static func snapshot(
        now: Date, freshness: TimeInterval, countTerminalSessions: Bool = false,
        included: Set<AgentKind> = Set(AgentKind.allCases)
    ) -> AgentProbeObservation {
        let engine = AgentHeuristicEngine(config: AgentHeuristicConfig(
            sessionFreshness: freshness, claudeCodexCPUBusyThreshold: 5,
            countTerminalSessionsAsBusy: countTerminalSessions
        ))
        let processes = ProcessListReader.records()
        let walkIncluded = SessionWalkBudget.kindsToWalk(included: included, processes: processes.values)
        let files = SessionFileWalker.signals(
            home: FileManager.default.homeDirectoryForCurrentUser, env: ProcessInfo.processInfo.environment,
            countTerminalSessions: countTerminalSessions, included: walkIncluded, now: now, freshness: freshness
        )
        let completed = Date()
        return AgentProbeObservation(
            snapshot: engine.evaluate(processes: processes.values, sessionWrites: files.values, now: completed),
            startedAt: now, completedAt: completed, complete: processes.complete && files.complete
        )
    }
}
