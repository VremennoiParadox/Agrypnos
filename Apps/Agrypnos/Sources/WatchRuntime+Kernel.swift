import AppKit
import Foundation

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

extension WatchRuntime {
    @discardableResult
    func armKernel(allowInstall: Bool = true) -> Bool {
        var result = setKernel(true)
        if result == .grantMissing, allowInstall {
            if GrantInstaller.installViaNativeAuth() {
                result = setKernel(true)
            }
        }
        guard result == .ok, readKernel() == .held else {
            if case .failed(let message) = result {
                notify("Couldn't keep the watch. \(message)")
            } else if result == .grantMissing {
                notify(AgrypnosCopy.grantNeeded)
            } else {
                notify("pmset ran but SleepDisabled did not read back as on.")
            }
            WatchDiagnostics.event("kernel arm failed")
            return false
        }
        WatchDiagnostics.event("kernel arm readback held=true")
        return true
    }

    @discardableResult
    func disarmKernel() -> Bool {
        _ = setKernel(false)
        let state = readKernel()
        WatchDiagnostics.event("kernel disarm readback=\(state)")
        return state == .clear
    }

    /// Quit must clear actual kernel-held SleepDisabled even if the engine already disengaged for POST.
    func prepareForTermination() {
        questionSourcesTerminated = true
        stopQuestionSources()
        guard ownsWakeHold else { return }
        clearQuestionWatch()
        deadlineTimer?.invalidate()
        deadlineTimer = nil
        stopObservingMacSleepWake()
        inboundPoller.stop()
        discordGateway.stop()
        let kernelHeld = readKernel()
        let plan = idleOutbound.terminatePlan(
            engineEngaged: engine.engaged,
            kernelSleepDisabled: kernelHeld != .clear
        )
        idlePostTask?.cancel()
        idlePostTask = nil
        idleOutbound.cancelInFlight()
        guard plan.cleanupRequired else { return }
        var cleared = true
        if plan.clearKernel {
            cleared = disarmKernel()
            if let message = KernelQuitPolicy.leftoverNotify(kernelCleared: cleared) {
                notify(message)
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
        let kernel = readKernel()
        if kernel == .held, !engine.engaged {
            if preferClearLeftover {
                _ = setKernel(false)
            }
            if readKernel() == .held {
                let rawClosed = readLid() == true
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
                syncDeadlineTimer()
                notify(AgrypnosCopy.leftoverNotify(for: engine.preferences.panelPowerMode))
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
