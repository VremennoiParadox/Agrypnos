import Foundation

/// Read bytes directly: Foundation's line sequence removes SSE's blank frame separators.
struct OpenCodeEventFrames {
    private var line: [UInt8] = []
    private var data = Data()
    private var lineHasBytes = false
    private var discarding = false
    private var skipLF = false
    private let limit = 256 * 1024

    mutating func append(_ byte: UInt8) -> Data? {
        if skipLF {
            skipLF = false
            if byte == 10 { return nil }
        }
        if byte == 13 || byte == 10 {
            skipLF = byte == 13
            return finishLine()
        }
        lineHasBytes = true
        guard !discarding else { return nil }
        guard line.count + data.count + 1 <= limit else {
            discarding = true
            line.removeAll(keepingCapacity: true)
            data.removeAll(keepingCapacity: true)
            return nil
        }
        line.append(byte)
        return nil
    }

    private mutating func finishLine() -> Data? {
        defer {
            line.removeAll(keepingCapacity: true)
            lineHasBytes = false
        }
        if !lineHasBytes {
            defer { data.removeAll(keepingCapacity: true); discarding = false }
            return !discarding && !data.isEmpty ? data : nil
        }
        guard !discarding, line.starts(with: [100, 97, 116, 97, 58]) else { return nil }
        var value = line.dropFirst(5)
        if value.first == 32 { value = value.dropFirst() }
        if !data.isEmpty { data.append(10) }
        data.append(contentsOf: value)
        return nil
    }
}
