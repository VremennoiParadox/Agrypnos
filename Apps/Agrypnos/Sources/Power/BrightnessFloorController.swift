import CoreGraphics
import Darwin
import Foundation
import IOKit
import IOKit.graphics

enum BrightnessFloorController {
    /// 0...1. Returns nil if the display stack will not talk to us.
    static func current() -> Double? {
        if let viaDisplayServices = displayServicesGet() { return Double(viaDisplayServices) }
        return ioDisplayGet()
    }

    static func set(_ value: Double) {
        let clamped = Float(min(max(value, 0), 1))
        if !displayServicesSet(clamped) {
            ioDisplaySet(Double(clamped))
        }
    }

    static func applyFloor(_ floor: Double) {
        let currentValue = current() ?? 0
        if currentValue < floor {
            set(floor)
        }
    }

    static func restoreAtLeastFloor(saved: Double?, floor: Double) {
        set(max(saved ?? floor, floor))
    }

    // MARK: IODisplayConnect

    static func ioDisplayGet() -> Double? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IODisplayConnect"), &iterator)
            == KERN_SUCCESS
        else { return nil }
        defer { IOObjectRelease(iterator) }
        let service = IOIteratorNext(iterator)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        var brightness: Float = 0
        let key = "brightness" as CFString
        guard IODisplayGetFloatParameter(service, 0, key, &brightness) == kIOReturnSuccess else { return nil }
        return Double(brightness)
    }

    static func ioDisplaySet(_ value: Double) {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IODisplayConnect"), &iterator)
            == KERN_SUCCESS
        else { return }
        defer { IOObjectRelease(iterator) }
        let service = IOIteratorNext(iterator)
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }
        IODisplaySetFloatParameter(service, 0, "brightness" as CFString, Float(value))
    }

    // MARK: DisplayServices (private, Apple Silicon fallback)

    static func displayServicesGet() -> Float? {
        typealias Fn = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
        guard let fn: Fn = load("DisplayServicesGetBrightness") else { return nil }
        var value: Float = 0
        let id = CGMainDisplayID()
        guard fn(id, &value) == 0 else { return nil }
        return value
    }

    static func displayServicesSet(_ value: Float) -> Bool {
        typealias Fn = @convention(c) (UInt32, Float) -> Int32
        guard let fn: Fn = load("DisplayServicesSetBrightness") else { return false }
        return fn(CGMainDisplayID(), value) == 0
    }

    static func load<T>(_ symbol: String) -> T? {
        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        guard let handle = dlopen(path, RTLD_LAZY) else { return nil }
        guard let raw = dlsym(handle, symbol) else { return nil }
        return unsafeBitCast(raw, to: T.self)
    }
}
