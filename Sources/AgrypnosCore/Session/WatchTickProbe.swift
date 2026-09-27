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

    /// Off-watch leftover `SleepDisabled` check. 5s tick × this many idle polls.
    public static let leftoverKernelIdleTicks = 12
    public static var leftoverKernelInterval: TimeInterval {
        TimeInterval(leftoverKernelIdleTicks) * 5
    }

    /// Leftover clear must not run while idle-after-wait still holds SleepDisabled.
    public static func leftoverReconcileDue(idleTicks: Int, holdingForIdlePost: Bool) -> Bool {
        !holdingForIdlePost && idleTicks >= leftoverKernelIdleTicks
    }

    public var probesSafety: Bool { self != .none }
    public var probesKernelHold: Bool { self != .none }
    public var probesAgents: Bool { self == .safetyAndAgents }

    public static func needed(engaged: Bool, mode: WatchMode) -> WatchTickProbe {
        guard engaged else { return .none }
        if mode == .untilAgentsSettle { return .safetyAndAgents }
        return .safety
    }
}
