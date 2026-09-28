import Foundation
import Darwin

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

enum ToggleResult: Equatable {
    case ok
    case grantMissing
    case failed(String)
}

enum SleepDisabledController {
    static func read() -> SleepDisabledState {
        let result = ProcessRunner.run("/usr/bin/pmset", ["-g"])
        return SleepDisabledParser.state(pmsetG: result.out, exit: result.exit)
    }

    static func set(_ on: Bool) -> ToggleResult {
        let result = ProcessRunner.run(
            "/usr/bin/pmset",
            ["-a", "disablesleep", on ? "1" : "0"],
            privilegedSudoN: true
        )
        if result.exit == 0 { return .ok }
        let err = result.err
        if err.range(of: "a password is required", options: .caseInsensitive) != nil
            || err.range(of: "not allowed", options: .caseInsensitive) != nil
            || err.range(of: "may not run", options: .caseInsensitive) != nil
            || err.range(of: "a terminal is required", options: .caseInsensitive) != nil
        {
            return .grantMissing
        }
        return .failed(err.isEmpty ? "exit \(result.exit)" : err)
    }
}

/// A crash or force quit skips `prepareForTermination`, which would leave SleepDisabled on
/// until reboot. The helper clears it as soon as this process is gone.
@MainActor
enum SleepDisabledCrashGuard {
    private static var lifeline: Pipe?

    nonisolated static func acquireOwnership(at url: URL) -> FileHandle? {
        let fd = open(url.path, O_CREAT | O_RDWR | O_NOFOLLOW | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { return nil }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else { close(fd); return nil }
        return FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    }

    static func start() -> Bool {
        if lifeline != nil { return true }
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Agrypnos")
        do { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        catch { return false }
        guard let owner = acquireOwnership(at: directory.appendingPathComponent("wake-owner.lock")) else {
            return false
        }
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", KernelCrashGuard.script]
        process.standardInput = pipe
        // The helper inherits this locked open-file description as stdout. The lock survives
        // app death and is released only after its existing cleanup command exits.
        process.standardOutput = owner
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return false }
        lifeline = pipe
        return true
    }
}
