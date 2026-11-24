public struct ProcessRecord: Equatable, Sendable {
    public var pid: Int
    public var cpuPercent: Double
    public var name: String
    /// Lets a command the agent started count toward that agent's CPU.
    public var parentPID: Int?

    public init(pid: Int, cpuPercent: Double, name: String, parentPID: Int? = nil) {
        self.pid = pid
        self.cpuPercent = cpuPercent
        self.name = name
        self.parentPID = parentPID
    }
}

public enum ProcessTableParser: Sendable {
    /// Parses `ps -axo pid= -o ppid= -o pcpu= -o args=` (pid, parent, cpu, rest is command). Never log `name`.
    public static func parse(stdout: String) -> [ProcessRecord] {
        stdout.split(whereSeparator: \.isNewline).compactMap(parseLine)
    }

    static func parseLine(_ line: Substring) -> ProcessRecord? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(maxSplits: 3, whereSeparator: { $0 == " " || $0 == "\t" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard parts.count == 4, let pid = Int(parts[0]), let parent = Int(parts[1]), let cpu = Double(parts[2]) else {
            return nil
        }
        return ProcessRecord(pid: pid, cpuPercent: cpu, name: parts[3], parentPID: parent)
    }
}
