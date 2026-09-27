import Foundation

/// When the 5s tick may walk pmset / battery / ps / session trees.
/// No watt numbers — only skip work the watch cannot use.
public enum WatchTickProbe: Equatable, Sendable {
    /// Watch off. Auto-off and Agents settle cannot fire. Kernel leftover is separate.
    case none
    /// Armed. Safety + kernel hold. Skip process and session-tree walks.
    case safety
    /// Agents mode. Safety plus local busy signals.
    case safetyAndAgents

    public var probesSafety: Bool { self != .none }
    public var probesKernelHold: Bool { self != .none }
    public var probesAgents: Bool { self == .safetyAndAgents }

    public static func needed(engaged: Bool, mode: WatchMode) -> WatchTickProbe {
        guard engaged else { return .none }
        if mode == .untilAgentsSettle { return .safetyAndAgents }
        return .safety
    }
}
