import Foundation

/// One bool, one lock. Discord heartbeat ack is not a plain cross-thread `var`.
public final class IsolatedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Bool

    public init(_ value: Bool = true) {
        stored = value
    }

    public var value: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return stored
        }
        set {
            lock.lock()
            stored = newValue
            lock.unlock()
        }
    }
}
