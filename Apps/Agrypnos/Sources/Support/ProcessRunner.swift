import Foundation
import Darwin

enum ProcessRunner {
    static func run(_ launchPath: String, _ arguments: [String], privilegedSudoN: Bool = false, timeout: TimeInterval = 3) -> (
        exit: Int32, out: String, err: String
    ) {
        let process = Process()
        if privilegedSudoN {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
            process.arguments = ["-n", launchPath] + arguments
        } else {
            process.executableURL = URL(fileURLWithPath: launchPath)
            process.arguments = arguments
        }
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin"
        environment["HOME"] = FileManager.default.homeDirectoryForCurrentUser.path
        process.environment = environment
        let stdout = ProcessOutput()
        let stderr = ProcessOutput()
        process.standardOutput = stdout.pipe
        process.standardError = stderr.pipe
        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }
        process.standardInput = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return (-1, "", error.localizedDescription)
        }
        let timedOut = exited.wait(timeout: .now() + max(0, timeout)) == .timedOut
        if timedOut, process.isRunning {
            let pid = process.processIdentifier
            // Foundation gives children their own group on macOS. Check before signaling it.
            let ownsGroup = getpgid(pid) == pid
            _ = kill(ownsGroup ? -pid : pid, SIGTERM)
            if exited.wait(timeout: .now() + 0.1) == .timedOut, process.isRunning {
                _ = kill(ownsGroup ? -pid : pid, SIGKILL)
            }
        }
        process.waitUntilExit()
        let out = stdout.finish()
        let err = stderr.finish()
        return (timedOut ? -2 : process.terminationStatus, out,
                timedOut ? "Command timed out. " + err : err)
    }

    /// Do not wait. Used for Power B panel wake so a later `sleepnow` is not delayed.
    static func runDetached(_ launchPath: String, _ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
    }
}

/// Drain both pipes as data arrives. A descendant retaining a pipe cannot block completion.
private final class ProcessOutput: @unchecked Sendable {
    let pipe = Pipe()
    private let lock = NSLock()
    private let eof = DispatchSemaphore(value: 0)
    private var data = Data()

    init() {
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self else { return }
            guard let chunk = try? handle.read(upToCount: 8192), !chunk.isEmpty else {
                handle.readabilityHandler = nil
                self.eof.signal()
                return
            }
            self.lock.lock()
            self.data.append(chunk)
            self.lock.unlock()
        }
    }

    func finish() -> String {
        _ = eof.wait(timeout: .now() + 0.2)
        pipe.fileHandleForReading.readabilityHandler = nil
        try? pipe.fileHandleForReading.close()
        lock.lock()
        defer { lock.unlock() }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
