/// Quit must honor a failed `SleepDisabled` clear. Do not restore hygiene on a still-held kernel.
public enum KernelQuitPolicy: Sendable {
    public static func shouldRestoreHygiene(kernelCleared: Bool) -> Bool {
        kernelCleared
    }

    public static func leftoverNotify(kernelCleared: Bool) -> String? {
        kernelCleared ? nil : "Couldn't verify SleepDisabled was cleared."
    }
}

/// Helper shell that outlives a crashed app. The app holds its stdin pipe open; when the
/// app dies for any reason the pipe closes and the helper clears SleepDisabled with the
/// existing grant. Uses only the `disablesleep 0` line of the sudoers rule.
public enum KernelCrashGuard: Sendable {
    public static let script = """
    trap '' HUP INT TERM
    read _
    exec /usr/bin/sudo -n /usr/bin/pmset -a disablesleep 0
    """
}
