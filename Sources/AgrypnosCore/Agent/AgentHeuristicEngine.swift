import Foundation

public struct SessionFileSignal: Equatable, Sendable {
    public var url: URL
    public var modified: Date
    public var kind: AgentKind

    public init(url: URL, modified: Date, kind: AgentKind) {
        self.url = url
        self.modified = modified
        self.kind = kind
    }
}

public struct AgentReport: Equatable, Sendable {
    public var kind: AgentKind
    public var processRunning: Bool
    public var cpuBusy: Bool
    public var recentSessionWrite: Bool
    public var isBusy: Bool

    public init(
        kind: AgentKind,
        processRunning: Bool,
        cpuBusy: Bool,
        recentSessionWrite: Bool,
        isBusy: Bool
    ) {
        self.kind = kind
        self.processRunning = processRunning
        self.cpuBusy = cpuBusy
        self.recentSessionWrite = recentSessionWrite
        self.isBusy = isBusy
    }
}

public struct AgentSnapshot: Equatable, Sendable {
    public var reports: [AgentReport]

    public init(reports: [AgentReport]) {
        self.reports = reports
    }

    public var anyBusy: Bool {
        reports.contains { $0.isBusy }
    }
}

public struct AgentHeuristicConfig: Equatable, Sendable {
    public static let defaultSubagentSessionFreshness: TimeInterval = 900

    public var sessionFreshness: TimeInterval
    public var subagentSessionFreshness: TimeInterval
    public var claudeCodexCPUBusyThreshold: Double

    public init(
        sessionFreshness: TimeInterval = UserPreferences.defaultSessionFreshness,
        subagentSessionFreshness: TimeInterval = AgentHeuristicConfig.defaultSubagentSessionFreshness,
        claudeCodexCPUBusyThreshold: Double = 5
    ) {
        self.sessionFreshness = sessionFreshness
        self.subagentSessionFreshness = subagentSessionFreshness
        self.claudeCodexCPUBusyThreshold = claudeCodexCPUBusyThreshold
    }
}

public struct AgentHeuristicEngine: Equatable, Sendable {
    public var config: AgentHeuristicConfig

    public init(config: AgentHeuristicConfig = AgentHeuristicConfig()) {
        self.config = config
    }

    public func evaluate(
        processes: [ProcessRecord],
        sessionWrites: [SessionFileSignal],
        now: Date
    ) -> AgentSnapshot {
        let reports = AgentKind.allCases.map { kind in
            evaluate(kind: kind, processes: processes, sessionWrites: sessionWrites, now: now)
        }
        return AgentSnapshot(reports: reports)
    }

    func evaluate(
        kind: AgentKind,
        processes: [ProcessRecord],
        sessionWrites: [SessionFileSignal],
        now: Date
    ) -> AgentReport {
        let matched = processes.filter { AgentKindClassifier.classify(processName: $0.name) == kind }
        let processRunning = !matched.isEmpty
        let cpuBusy = matched.contains {
            AgentKindClassifier.cpuCountsTowardBusy(processName: $0.name)
                && $0.cpuPercent >= config.claudeCodexCPUBusyThreshold
        }
        let recentSessionWrite = sessionWrites.contains { signal in
            guard signal.kind == kind else { return false }
            // ponytail: 15m flush window only for /subagents/ paths. Cursor Task jsonl
            // often writes at turn start, not per tool. If short subagents delay Notif
            // too long, drop this to sessionFreshness (45s) instead of adding detectors.
            let window = SessionFileLayout.isSubagentSessionPath(signal.url)
                ? config.subagentSessionFreshness
                : config.sessionFreshness
            return now.timeIntervalSince(signal.modified) <= window
        }
        let isBusy: Bool
        switch kind {
        case .cursor:
            isBusy = processRunning && recentSessionWrite
        case .claudeCode, .codex:
            isBusy = processRunning && (cpuBusy || recentSessionWrite)
        }
        return AgentReport(
            kind: kind,
            processRunning: processRunning,
            cpuBusy: cpuBusy,
            recentSessionWrite: recentSessionWrite,
            isBusy: isBusy
        )
    }
}
