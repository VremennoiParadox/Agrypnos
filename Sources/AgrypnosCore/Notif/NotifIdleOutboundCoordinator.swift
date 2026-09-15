/// Quit / re-arm decisions for an in-flight idle-after-wait POST.
public struct NotifIdleTerminatePlan: Equatable, Sendable {
    public var cleanupRequired: Bool
    public var clearKernel: Bool

    public init(cleanupRequired: Bool, clearKernel: Bool) {
        self.cleanupRequired = cleanupRequired
        self.clearKernel = clearKernel
    }
}

/// Pure coordinator so Linux can prove POST-in-flight races without AppKit.
public struct NotifIdleOutboundCoordinator: Equatable, Sendable {
    public private(set) var generation: UInt64
    public private(set) var inFlightToken: UInt64?

    public var postInFlight: Bool { inFlightToken != nil }

    public init() {
        generation = 0
        inFlightToken = nil
    }

    /// Genuine new user arm. In-flight POST completion becomes stale.
    public mutating func noteUserArm() {
        generation &+= 1
        inFlightToken = nil
    }

    public mutating func beginPost() -> UInt64 {
        inFlightToken = generation
        return generation
    }

    /// True only when this token still matches the current arm.
    public mutating func completePost(token: UInt64) -> Bool {
        guard inFlightToken == token else { return false }
        inFlightToken = nil
        return generation == token
    }

    public mutating func cancelInFlight() {
        inFlightToken = nil
    }

    /// Skip poll while POST holds SleepDisabled and the engine already disengaged.
    public func shouldSkipPoll(engineEngaged: Bool) -> Bool {
        postInFlight && !engineEngaged
    }

    public func terminatePlan(
        engineEngaged: Bool,
        kernelSleepDisabled: Bool
    ) -> NotifIdleTerminatePlan {
        NotifIdleTerminatePlan(
            cleanupRequired: postInFlight || engineEngaged || kernelSleepDisabled,
            clearKernel: kernelSleepDisabled
        )
    }
}
