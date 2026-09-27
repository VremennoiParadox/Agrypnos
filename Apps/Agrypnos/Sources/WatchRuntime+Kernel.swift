import AppKit
import Foundation

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

extension WatchRuntime {
    @discardableResult
    func armKernel() -> Bool {
        var result = SleepDisabledController.set(true)
        if result == .grantMissing {
            if GrantInstaller.installViaNativeAuth() {
                result = SleepDisabledController.set(true)
            }
        }
        guard result == .ok, SleepDisabledController.read() else {
            if case .failed(let message) = result {
                UserNotify.post("Couldn't keep the watch. \(message)")
            } else if result == .grantMissing {
                UserNotify.post(AgrypnosCopy.grantNeeded)
            } else {
                UserNotify.post("pmset ran but SleepDisabled did not read back as on.")
            }
            return false
        }
        return true
    }

    @discardableResult
    func disarmKernel() -> Bool {
        _ = SleepDisabledController.set(false)
        return !SleepDisabledController.read()
    }

    /// Quit must clear actual kernel-held SleepDisabled even if the engine already disengaged for POST.
    func prepareForTermination() {
        stopObservingMacSleepWake()
        inboundPoller.stop()
        discordGateway.stop()
        let kernelHeld = SleepDisabledController.read()
        let plan = idleOutbound.terminatePlan(
            engineEngaged: engine.engaged,
            kernelSleepDisabled: kernelHeld
        )
        idlePostTask?.cancel()
        idlePostTask = nil
        idleOutbound.cancelInFlight()
        guard plan.cleanupRequired else { return }
        var cleared = true
        if plan.clearKernel {
            cleared = disarmKernel()
            if let message = KernelQuitPolicy.leftoverNotify(kernelCleared: cleared) {
                UserNotify.post(message)
            }
        }
        if engine.engaged {
            apply(engine.userSetEngaged(false, now: Date(), lidClosed: false))
            store.save(engine.preferences)
        }
        if KernelQuitPolicy.shouldRestoreHygiene(kernelCleared: cleared) {
            restoreHygiene()
        } else {
            dropSavedHygieneWithoutWrite()
        }
    }

    func reconcileKernel(preferClearLeftover: Bool) {
        let kernel = SleepDisabledController.read()
        if kernel, !engine.engaged {
            if preferClearLeftover {
                _ = SleepDisabledController.set(false)
            }
            if SleepDisabledController.read() {
                let rawClosed = LidStateReader.isClosed()
                if LidCloseConfirm.shouldCaptureBeforeClosedHygiene(rawClosed: rawClosed) {
                    recaptureOpenLidHygiene()
                }
                apply(engine.adoptLeftoverKernel(now: Date(), lidClosed: false))
                apply(engine.observeLid(closed: rawClosed, now: Date()))
                if LidCloseConfirm.shouldRecaptureOpenBrightness(
                    rawClosed: rawClosed,
                    confirmedClosed: engine.lidClosed
                ) {
                    recaptureOpenLidHygiene()
                }
                startLidPulse()
                UserNotify.post(AgrypnosCopy.leftoverNotify)
            }
        }
    }

    func observeMacSleepWake() {
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(
            center.addObserver(
                forName: NSWorkspace.willSleepNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.noteMacWillSleep() }
            }
        )
        workspaceObservers.append(
            center.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.noteMacDidWake() }
            }
        )
    }

    func stopObservingMacSleepWake() {
        let center = NSWorkspace.shared.notificationCenter
        for observer in workspaceObservers {
            center.removeObserver(observer)
        }
        workspaceObservers = []
    }
}
