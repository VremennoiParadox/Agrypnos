public struct ProcessRecord: Equatable, Sendable {
    public var pid: Int
    public var cpuPercent: Double
    public var name: String

    public init(pid: Int, cpuPercent: Double, name: String) {
        self.pid = pid
        self.cpuPercent = cpuPercent
        self.name = name
    }
}

public enum ProcessTableParser: Sendable {
    /// Parses `ps -axo pid= -o pcpu= -o comm=` (pid, cpu, rest is command).
    public static func parse(stdout: String) -> [ProcessRecord] {
        stdout.split(whereSeparator: \.isNewline).compactMap(parseLine)
    }

    static func parseLine(_ line: Substring) -> ProcessRecord? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(maxSplits: 2, whereSeparator: { $0 == " " || $0 == "\t" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard parts.count == 3, let pid = Int(parts[0]), let cpu = Double(parts[1]) else {
            return nil
        }
        return ProcessRecord(pid: pid, cpuPercent: cpu, name: parts[2])
    }
}
