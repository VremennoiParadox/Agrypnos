import Foundation

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

enum ToggleResult: Equatable {
    case ok
    case grantMissing
    case failed(String)
}

enum SleepDisabledController {
    static func read() -> Bool {
        SleepDisabledParser.parse(pmsetG: ProcessRunner.run("/usr/bin/pmset", ["-g"]).out)
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

    static func start() {
        guard lifeline == nil else { return }
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", KernelCrashGuard.script]
        process.standardInput = pipe
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return }
        lifeline = pipe
    }
}
