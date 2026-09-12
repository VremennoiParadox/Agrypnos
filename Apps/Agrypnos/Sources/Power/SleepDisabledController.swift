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
