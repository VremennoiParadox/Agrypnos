import Foundation

/// Stable lid-closed from successive samples. Matches the 0.25s WatchRuntime pulse:
/// one raw AppleClamshellState read is not close. A flicker while the lid is open
/// must not apply hygiene.
public struct LidCloseConfirm: Equatable, Sendable {
    public static let pulseInterval: TimeInterval = 0.25

    public private(set) var confirmedClosed = false
    private var closedSince: Date?

    /// Raw closed samples have started; not yet a stable confirm.
    public var isPendingClose: Bool { closedSince != nil && !confirmedClosed }

    public enum Edge: Equatable, Sendable {
        case closed
        case opened
    }

    public init() {}

    /// Snapshot the open-lid panel only while the raw clamshell is open.
    /// Pending close (raw closed, not yet confirmed) must not overwrite the last open level.
    public static func shouldRecaptureOpenBrightness(rawClosed: Bool, confirmedClosed: Bool) -> Bool {
        !rawClosed && !confirmedClosed
    }

    public mutating func reset() {
        confirmedClosed = false
        closedSince = nil
    }

    /// Caller already confirmed closed (`lidDidClose` / arm with `lidClosed: true`).
    public mutating func markConfirmedClosed() {
        confirmedClosed = true
        closedSince = nil
    }

    public mutating func sample(_ closed: Bool, now: Date) -> Edge? {
        if closed {
            let start = closedSince ?? now
            closedSince = start
            if !confirmedClosed, now.timeIntervalSince(start) >= Self.pulseInterval {
                confirmedClosed = true
                return .closed
            }
            return nil
        }
        closedSince = nil
        if confirmedClosed {
            confirmedClosed = false
            return .opened
        }
        return nil
    }
}

/// 4 Hz only while a close is pending confirm. Open or already confirmed uses the 5s tick.
public enum LidSampleCadence: Equatable, Sendable {
    case none
    case confirmPulse
    case coarse
}

public enum LidSamplePolicy: Sendable {
    public static var confirmPulseInterval: TimeInterval { LidCloseConfirm.pulseInterval }

    public static func cadence(
        engaged: Bool,
        lidCloseConfirmed: Bool,
        inboundNeedsLid: Bool = false,
        pendingClose: Bool = false
    ) -> LidSampleCadence {
        guard engaged || inboundNeedsLid else { return .none }
        if lidCloseConfirmed { return .coarse }
        if pendingClose { return .confirmPulse }
        return .coarse
    }

    public static func runsConfirmPulse(
        engaged: Bool,
        lidCloseConfirmed: Bool,
        inboundNeedsLid: Bool = false,
        pendingClose: Bool = false
    ) -> Bool {
        cadence(
            engaged: engaged,
            lidCloseConfirmed: lidCloseConfirmed,
            inboundNeedsLid: inboundNeedsLid,
            pendingClose: pendingClose
        ) == .confirmPulse
    }

    public static func samplesOnTick(
        engaged: Bool,
        lidCloseConfirmed: Bool,
        inboundNeedsLid: Bool = false,
        pendingClose: Bool = false
    ) -> Bool {
        cadence(
            engaged: engaged,
            lidCloseConfirmed: lidCloseConfirmed,
            inboundNeedsLid: inboundNeedsLid,
            pendingClose: pendingClose
        ) != .none
    }
}
