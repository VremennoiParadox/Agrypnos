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

    static func applyFloor(_ floor: Double) {
        let currentValue = current() ?? 0
        if currentValue < floor {
            set(floor)
        }
    }

    static func restoreAtLeastFloor(saved: Double?, floor: Double) {
        guard let target = HygieneRestore.displayBrightnessToRestore(captured: saved, floor: floor) else { return }
        set(target)
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

    // MARK: DisplayServices (private)

    static func displayServicesGet(_ id: CGDirectDisplayID) -> Float? {
        typealias Fn = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
        guard let fn: Fn = load("DisplayServicesGetBrightness") else { return nil }
        var value: Float = 0
        guard fn(id, &value) == 0 else { return nil }
        return value
    }

    static func displayServicesSet(_ id: CGDirectDisplayID, _ value: Float) -> Bool {
        typealias Fn = @convention(c) (UInt32, Float) -> Int32
        guard let fn: Fn = load("DisplayServicesSetBrightness") else { return false }
        return fn(id, value) == 0
    }

    static func load<T>(_ symbol: String) -> T? {
        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        guard let handle = dlopen(path, RTLD_LAZY) else { return nil }
        guard let raw = dlsym(handle, symbol) else { return nil }
        return unsafeBitCast(raw, to: T.self)
    }
}
