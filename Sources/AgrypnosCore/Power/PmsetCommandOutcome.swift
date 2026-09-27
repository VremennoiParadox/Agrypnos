public enum PmsetUserCommand: Equatable, Sendable {
    case sleepnow
    case displaysleepnow
}

public enum PmsetCommandOutcome: Equatable, Sendable {
    case ok
    case failed(exit: Int32)

    public static func from(exit: Int32) -> PmsetCommandOutcome {
        exit == 0 ? .ok : .failed(exit: exit)
    }
}

/// Surface `pmset` sleep/display-sleep failures. Not a new sudoers grant.
public enum PmsetCommandCopy: Sendable {
    public static func notify(
        _ command: PmsetUserCommand,
        outcome: PmsetCommandOutcome
    ) -> String? {
        switch outcome {
        case .ok:
            return nil
        case .failed:
            switch command {
            case .sleepnow:
                return "Couldn't send the Mac to sleep."
            case .displaysleepnow:
                return "Couldn't sleep the panel."
            }
        }
    }
}

public struct HygieneApplyResult: Equatable, Sendable {
    public var sleepnow: PmsetCommandOutcome?
    public var displaysleepnow: PmsetCommandOutcome?

    public init(sleepnow: PmsetCommandOutcome? = nil, displaysleepnow: PmsetCommandOutcome? = nil) {
        self.sleepnow = sleepnow
        self.displaysleepnow = displaysleepnow
    }

    public var notifications: [String] {
        var lines: [String] = []
        if let sleepnow, let line = PmsetCommandCopy.notify(.sleepnow, outcome: sleepnow) {
            lines.append(line)
        }
        if let displaysleepnow, let line = PmsetCommandCopy.notify(.displaysleepnow, outcome: displaysleepnow) {
            lines.append(line)
        }
        return lines
    }
}
