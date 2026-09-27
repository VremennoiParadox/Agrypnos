import CoreGraphics
import Darwin
import Foundation

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

enum BrightnessFloorController {
    static func onlineRecords() -> [DisplayRecord] {
        ids().map { DisplayRecord(isBuiltIn: isBuiltIn($0), isOnline: true) }
    }

    static func canSetBuiltIn() -> Bool {
        BrightnessWritePolicy.shouldWrite(displays: onlineRecords())
    }

    /// 0...1. Nil if the built-in panel is not online or will not talk to us.
    static func current() -> Double? {
        guard let id = builtInID() else { return nil }
        return displayServicesGet(id).map(Double.init)
    }

    static func set(_ value: Double) {
        guard let id = builtInID() else { return }
        let clamped = Float(min(max(value, 0), 1))
        _ = displayServicesSet(id, clamped)
    }

    static func builtInID() -> CGDirectDisplayID? {
        ids().first { isBuiltIn($0) }
    }

    static func ids() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        var buffer = [CGDirectDisplayID](repeating: 0, count: 16)
        guard CGGetOnlineDisplayList(16, &buffer, &count) == .success else { return [] }
        return Array(buffer.prefix(Int(count)))
    }

    static func isBuiltIn(_ id: CGDirectDisplayID) -> Bool {
        CGDisplayIsBuiltin(id) != 0
    }

    // MARK: DisplayServices (private) — resolve once.

    typealias GetFn = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    typealias SetFn = @convention(c) (UInt32, Float) -> Int32

    static let symbols: (get: GetFn, set: SetFn)? = loadOnce()

    static func displayServicesGet(_ id: CGDirectDisplayID) -> Float? {
        guard let get = symbols?.get else { return nil }
        var value: Float = 0
        guard get(id, &value) == 0 else { return nil }
        return value
    }

    static func displayServicesSet(_ id: CGDirectDisplayID, _ value: Float) -> Bool {
        guard let set = symbols?.set else { return false }
        return set(id, value) == 0
    }

    static func loadOnce() -> (get: GetFn, set: SetFn)? {
        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        guard let handle = dlopen(path, RTLD_LAZY) else { return nil }
        guard let getRaw = dlsym(handle, "DisplayServicesGetBrightness"),
              let setRaw = dlsym(handle, "DisplayServicesSetBrightness")
        else { return nil }
        return (
            unsafeBitCast(getRaw, to: GetFn.self),
            unsafeBitCast(setRaw, to: SetFn.self)
        )
    }
}
