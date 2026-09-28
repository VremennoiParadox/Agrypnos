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

    public func isFresh(now: Date, freshness: TimeInterval) -> Bool {
        let age = now.timeIntervalSince(modified)
        return age >= 0 && age <= freshness
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
        anyBusy(included: Set(AgentKind.allCases))
    }

    public func anyBusy(included: Set<AgentKind>) -> Bool {
        reports.contains { $0.isBusy && included.contains($0.kind) }
    }
}

public struct AgentHeuristicConfig: Equatable, Sendable {
    public var sessionFreshness: TimeInterval
    public var claudeCodexCPUBusyThreshold: Double
    /// I3. Default off. Terminal session files count only when on.
    public var countTerminalSessionsAsBusy: Bool

    public init(
        sessionFreshness: TimeInterval = UserPreferences.defaultSessionFreshness,
        claudeCodexCPUBusyThreshold: Double = 5,
        countTerminalSessionsAsBusy: Bool = false
    ) {
        self.sessionFreshness = sessionFreshness
        self.claudeCodexCPUBusyThreshold = claudeCodexCPUBusyThreshold
        self.countTerminalSessionsAsBusy = countTerminalSessionsAsBusy
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
        let writes = sessionWrites.filter {
            SessionFileLayout.countsTowardBusy(
                $0.url,
                countTerminalSessions: config.countTerminalSessionsAsBusy
            )
        }
        let reports = AgentKind.allCases.map { kind in
            evaluate(kind: kind, processes: processes, sessionWrites: writes, now: now)
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
            signal.kind == kind && signal.isFresh(now: now, freshness: config.sessionFreshness)
        }
        let isBusy: Bool
        switch kind {
        case .cursor, .openCode:
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
