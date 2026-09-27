import Foundation

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

extension WatchRuntime {
    func lidCadence() -> LidSampleCadence {
        LidSamplePolicy.cadence(
            engaged: engine.engaged,
            lidCloseConfirmed: engine.lidCloseConfirmed,
            inboundNeedsLid: inboundNeedsLid(),
            pendingClose: engine.lidClosePending
        )
    }

    func pollLid() {
        let rawClosed = LidStateReader.isClosed()
        var lidChanged = false
        let commands = engine.observeLid(closed: rawClosed, now: Date())
        if engine.engaged {
            if !commands.isEmpty {
                apply(commands)
                lidChanged = true
            } else if LidCloseConfirm.shouldRecaptureOpenBrightness(
                rawClosed: rawClosed,
                confirmedClosed: engine.lidClosed
            ), !engine.lidHygieneApplied, !brightnessRamp.isRunning {
                recaptureOpenLidHygiene()
            }
        }
        syncLidPulse()
        if lidChanged {
            delegate?.watchRuntimeDidChange(self)
        }
    }

    func startLidPulse() {
        guard lidTimer == nil else { return }
        guard lidCadence() == .confirmPulse else { return }
        lidTimer = Timer.scheduledTimer(withTimeInterval: LidCloseConfirm.pulseInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollLid() }
        }
    }

    func syncLidPulse() {
        if lidCadence() == .confirmPulse {
            startLidPulse()
        } else {
            stopLidPulse()
        }
    }

    func stopLidPulse() {
        lidTimer?.invalidate()
        lidTimer = nil
    }
}
