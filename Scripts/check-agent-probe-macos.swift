// Compile this file as main.swift with Core, ProcessRunner.swift and AgentProbeService.swift.
import Foundation

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
}
let now = Date()
let root = URL(fileURLWithPath: "/probe-check")
let denied = NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError)
let missing = NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError)
let cursor = ProcessRecord(pid: 1, cpuPercent: 0, name: "Cursor")

let empty = ProcessListReader.records(run: { (0, "", "") })
let failed = ProcessListReader.records(run: { (1, "", "") })
check(empty.complete && empty.values.isEmpty, "Empty successful ps is valid absence")
check(!failed.complete, "Failed ps must not become idle")
check(!ProcessListReader.records(run: { (0, "broken ps row", "") }).complete,
      "Malformed process table must not become idle")

func walk(_ access: SessionFileAccess) -> ProbeCollection<SessionFileSignal> {
    SessionFileWalker.walk(root: root, kind: .cursor, now: now, freshness: 45,
                           countTerminalSessions: false, access: access)
}
let absent = SessionFileAccess(info: { _ in throw missing }, children: { _ in [] })
check(walk(absent).complete, "Optional missing root is valid absence")
let actualAbsent = SessionFileWalker.walk(root: root.appendingPathComponent(UUID().uuidString),
    kind: .cursor, now: now, freshness: 45, countTerminalSessions: false)
check(actualAbsent.complete && actualAbsent.values.isEmpty, "Actual missing root is valid absence")
let unreadable = SessionFileAccess(info: { _ in SessionFileInfo(isDirectory: true, modified: now) },
                                  children: { _ in throw denied })
check(!walk(unreadable).complete, "Existing unreadable root must be unknown")
let badMetadata = SessionFileAccess(info: { url in
    if url == root { return SessionFileInfo(isDirectory: true, modified: now) }
    throw denied
}, children: { _ in [root.appendingPathComponent("agent-transcripts/a.jsonl")] })
check(!walk(badMetadata).complete, "Unreadable metadata must be unknown")

let stale = now.addingTimeInterval(-300)
let capped = SessionFileAccess(info: { url in
    SessionFileInfo(isDirectory: url == root, modified: stale)
}, children: { _ in (0...SessionWalkBudget.maxVisited).map { root.appendingPathComponent("\($0).jsonl") } })
check(!walk(capped).complete, "Exhausted visit budget must not become idle")
let deep = SessionFileAccess(info: { _ in SessionFileInfo(isDirectory: true, modified: stale) },
                             children: { [$0.appendingPathComponent("child")] })
check(!walk(deep).complete, "Exhausted depth budget must not become idle")

// An early positive can expire before collection ends; skipped roots are not idle evidence.
let edge = root.appendingPathComponent("agent-transcripts/edge.jsonl")
let nested = root.appendingPathComponent("agent-transcripts/nested")
let stillFresh = nested.appendingPathComponent("still-fresh.jsonl")
let aging = SessionFileAccess(info: { url in
    if url == root { return SessionFileInfo(isDirectory: true, modified: now) }
    if url == nested { return SessionFileInfo(isDirectory: true, modified: stale) }
    return SessionFileInfo(isDirectory: false, modified: url == edge ? now.addingTimeInterval(-44) : now)
}, children: { $0 == root ? [edge, nested] : [stillFresh] })
let stopped = walk(aging)
let completion = now.addingTimeInterval(2)
let expiredSnapshot = AgentHeuristicEngine().evaluate(processes: [cursor], sessionWrites: stopped.values, now: completion)
let expiredPositive = AgentProbeObservation(snapshot: expiredSnapshot, startedAt: now,
    completedAt: completion, complete: stopped.complete)
check(expiredPositive.settleBusy(included: [.cursor], now: completion) == nil,
      "Expired early positive with skipped traversal must not become idle")

let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
defer { try? FileManager.default.removeItem(at: temp) }
let subagent = temp.appendingPathComponent("agent-transcripts/parent/subagents/child.jsonl")
try FileManager.default.createDirectory(at: subagent.deletingLastPathComponent(), withIntermediateDirectories: true)
try Data("{}".utf8).write(to: subagent)
let real = SessionFileWalker.walk(root: temp, kind: .cursor, now: Date(), freshness: 45,
                                  countTerminalSessions: false)
let snap = AgentHeuristicEngine().evaluate(processes: [cursor], sessionWrites: real.values, now: Date())
check(snap.anyBusy(included: [.cursor]), "Fresh subagent still counts with terminals off")
let partial = AgentProbeObservation(snapshot: snap, startedAt: now, completedAt: Date(), complete: false)
check(partial.settleBusy(included: [.cursor], now: Date()) == true, "Partial positive still protects watch")
print("Mac probe checks passed: ps failure, missing/error roots, metadata, budgets, expired positive, real subagent")
