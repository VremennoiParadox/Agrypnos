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
    /// Newest fresh session write. Auto-on needs a newer one before it trusts a write alone.
    public var newestWrite: Date?

    public init(
        kind: AgentKind,
        processRunning: Bool,
        cpuBusy: Bool,
        recentSessionWrite: Bool,
        isBusy: Bool,
        newestWrite: Date? = nil
    ) {
        self.kind = kind
        self.processRunning = processRunning
        self.cpuBusy = cpuBusy
        self.recentSessionWrite = recentSessionWrite
        self.isBusy = isBusy
        self.newestWrite = newestWrite
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

    /// A busy selected tool shows CPU, so this check is fresh evidence on its own.
    public func busyCPU(included: Set<AgentKind>) -> Bool {
        reports.contains { $0.isBusy && $0.cpuBusy && included.contains($0.kind) }
    }

    public func newestBusyWrite(included: Set<AgentKind>) -> Date? {
        reports.filter { $0.isBusy && included.contains($0.kind) }.compactMap(\.newestWrite).max()
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
        let threshold = config.claudeCodexCPUBusyThreshold
        let agents = matched.filter { AgentKindClassifier.commandsCountTowardBusy(processName: $0.name) }
        let cpuBusy = matched.contains {
            AgentKindClassifier.cpuCountsTowardBusy(processName: $0.name) && $0.cpuPercent >= threshold
        } || Self.commandCPU(under: agents, in: processes) >= threshold
        let fresh = sessionWrites.filter { signal in
            signal.kind == kind && signal.isFresh(now: now, freshness: config.sessionFreshness)
        }
        return AgentReport(
            kind: kind,
            processRunning: processRunning,
            cpuBusy: cpuBusy,
            recentSessionWrite: !fresh.isEmpty,
            isBusy: processRunning && (cpuBusy || !fresh.isEmpty),
            newestWrite: fresh.map(\.modified).max()
        )
    }

    /// CPU of commands the agents ran: their shell children and everything under those.
    /// Servers an agent starts directly (MCP, language servers) are not commands.
    static func commandCPU(under agents: [ProcessRecord], in processes: [ProcessRecord]) -> Double {
        guard !agents.isEmpty else { return 0 }
        let children = Dictionary(grouping: processes, by: { $0.parentPID ?? -1 })
        var stack = agents.flatMap { children[$0.pid] ?? [] }.filter { isShell($0.name) }
        var seen = Set<Int>()
        var total = 0.0
        while let process = stack.popLast() {
            guard seen.insert(process.pid).inserted else { continue }
            total += process.cpuPercent
            stack += children[process.pid] ?? []
        }
        return total
    }

    static func isShell(_ processName: String) -> Bool {
        var name = AgentKindClassifier.basename(processName)
        if name.hasPrefix("-") { name.removeFirst() }  // login shell
        return ["sh", "bash", "zsh", "dash", "fish", "ksh", "tcsh", "csh"].contains(name)
    }
}
