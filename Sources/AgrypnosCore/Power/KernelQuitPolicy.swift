/// Quit must honor a failed `SleepDisabled` clear. Do not restore hygiene on a still-held kernel.
public enum KernelQuitPolicy: Sendable {
    public static func shouldRestoreHygiene(kernelCleared: Bool) -> Bool {
        kernelCleared
    }

    public static func leftoverNotify(kernelCleared: Bool) -> String? {
        kernelCleared ? nil : "Couldn't drop SleepDisabled. The kernel flag is still on."
    }
}
