import Foundation

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

extension WatchRuntime {
    func poll() {
        if idleOutbound.shouldSkipPoll(engineEngaged: engine.engaged) { return }
        let probe = WatchTickProbe.needed(engaged: engine.engaged, mode: engine.mode)
        if lidCadence() != .none {
            pollLid()
        } else {
            stopLidPulse()
        }

        guard probe != .none else {
            idleProbeTicks += 1
            if WatchTickProbe.leftoverReconcileDue(
                idleTicks: idleProbeTicks,
                holdingForIdlePost: engine.holdingForIdlePost
            ) {
                idleProbeTicks = 0
                reconcileKernel(preferClearLeftover: true)
            }
            delegate?.watchRuntimeDidChange(self)
            return
        }
        idleProbeTicks = 0

        let battery = BatteryMonitor.reading()
        lastBatteryReading = battery
        let safety = SafetyInputs(
            batteryPercent: battery.percent,
            onBatteryDischarging: battery.onBatteryDischarging,
            thermalSerious: ThermalMonitor.isSerious(),
            lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
        lastSafety = safety
        let kernel = readKernel() == .held
        let included = engine.preferences.includedAgentKinds
        let terminals = engine.preferences.countTerminalSessionsAsBusy
        let now = Date()

        guard probe.probesAgents else {
            finishPollTick(
                now: now,
                safety: safety,
                agents: AgentSnapshot(reports: []),
                kernel: kernel,
                observeAgents: false
            )
            return
        }

        if let cached = agentSnapshotCache.reusable(
            at: now,
            included: included,
            countTerminalSessionsAsBusy: terminals
        ) {
            finishPollTick(
                now: now,
                safety: safety,
                agents: cached,
                kernel: kernel,
                observeAgents: true
            )
            return
        }

        if probeInFlight {
            finishPollTick(
                now: now,
                safety: safety,
                agents: AgentSnapshot(reports: []),
                kernel: kernel,
                observeAgents: false
            )
            return
        }

        probeInFlight = true
        let generation = probeGeneration
        let freshness = engine.preferences.sessionFreshness
        Task.detached { [weak self] in
            let snap = AgentProbeService.snapshot(
                now: Date(),
                freshness: freshness,
                countTerminalSessions: terminals,
                included: included
            )
            await MainActor.run {
                self?.finishAgentProbe(
                    snap,
                    generation: generation,
                    included: included,
                    countTerminalSessionsAsBusy: terminals
                )
            }
        }
        finishPollTick(
            now: now,
            safety: safety,
            agents: AgentSnapshot(reports: []),
            kernel: kernel,
            observeAgents: false
        )
    }

    func finishAgentProbe(
        _ observation: AgentProbeObservation,
        generation: UInt64,
        included: Set<AgentKind>,
        countTerminalSessionsAsBusy: Bool
    ) {
        guard generation == probeGeneration else {
            WatchDiagnostics.event("probe discarded: generation changed")
            return
        }
        probeInFlight = false
        let now = Date()
        let busy = observation.settleBusy(included: included, now: now)
        diagnostics.probe(observation, busy: busy, included: included, now: now)
        // A timely partial positive is safe to reuse; incomplete negatives never get here.
        if busy != nil {
            agentSnapshotCache.store(
                observation.snapshot,
                included: included,
                countTerminalSessionsAsBusy: countTerminalSessionsAsBusy,
                at: observation.completedAt
            )
        } else {
            agentSnapshotCache.invalidate()
        }
        if busy == nil {
            engine.interruptAgentObservations()
        }
        guard engine.engaged else {
            delegate?.watchRuntimeDidChange(self)
            return
        }
        let safety = lastSafety ?? SafetyInputs(
            batteryPercent: lastBatteryReading?.percent,
            onBatteryDischarging: lastBatteryReading?.onBatteryDischarging ?? false,
            thermalSerious: ThermalMonitor.isSerious(),
            lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
        finishPollTick(
            now: now,
            safety: safety,
            agents: observation.snapshot,
            kernel: readKernel() == .held,
            observeAgents: busy != nil
        )
    }

    func finishPollTick(
        now: Date,
        safety: SafetyInputs,
        agents: AgentSnapshot,
        kernel: Bool,
        observeAgents: Bool
    ) {
        let previousSettle = engine.settle
        if observeAgents, engine.mode == .untilAgentsSettle, let last = previousSettle.lastObservedAt {
            let gap = now.timeIntervalSince(last)
            if gap < 0 || gap > AgentSettleTracker.maximumObservationGap {
                WatchDiagnostics.event("observation gap=\(gap); restarting quiet wait")
            }
        }
        let commands = engine.tick(
            now: now,
            safety: safety,
            agents: agents,
            kernelSleepDisabled: kernel,
            observeAgents: observeAgents
        )
        diagnostics.tick(engine: engine, settle: engine.engaged ? engine.settle : previousSettle, busy: agents.anyBusy(included: engine.preferences.includedAgentKinds),
                         now: now, kernel: kernel, observed: observeAgents)
        for command in commands {
            if case .disengage(let reason) = command {
                WatchDiagnostics.event("watch end reason=\(reason) lidConfirmed=\(engine.lastDisengageLidClosed)")
            }
        }
        if commands.contains(where: Self.isPostIdleAfterWait) {
            WatchDiagnostics.event("idle POST decision enabled=\(engine.preferences.notifEnabled)")
            let token = idleOutbound.beginPost()
            let enabled = engine.preferences.notifEnabled
            idlePostTask?.cancel()
            idlePostTask = Task { @MainActor in
                await self.postIdle(enabled)
                guard self.idleOutbound.completePost(token: token) else { return }
                self.idlePostTask = nil
                WatchDiagnostics.event("idle POST attempt complete; releasing hold")
                self.finishTickCommands(commands)
                self.delegate?.watchRuntimeDidChange(self)
            }
            delegate?.watchRuntimeDidChange(self)
            return
        }
        finishTickCommands(commands)
        delegate?.watchRuntimeDidChange(self)
    }

    func finishTickCommands(_ commands: [WatchCommand]) {
        var applyCommands = commands.filter { !Self.isPostIdleAfterWait($0) }
        // A network await must not preserve permission to sleep after the lid opens.
        let sleepNext = commands.contains(.requestSleep) && readLid()
        if !sleepNext {
            applyCommands.removeAll { $0 == .requestSleep }
            if commands.contains(.requestSleep), engine.preferences.panelPowerMode == .displaySleep {
                applyCommands.append(.wakeDisplay)
            }
        }
        for command in commands {
            if case .disengage(let reason) = command {
                if !disarmKernel() {
                    applyCommands = engine.rollbackDisarmFailure(now: Date())
                    notify("Couldn't drop SleepDisabled. The watch stays up.")
                    break
                }
                engine.completeIdlePostHold()
                if HygieneRestore.shouldRestoreAfterDisengage(
                    lidCloseConfirmed: engine.lastDisengageLidClosed,
                    nextCommandIsSleep: sleepNext
                ) {
                    restoreHygiene()
                } else {
                    dropSavedHygieneWithoutWrite()
                }
                if reason != .user {
                    notify(AgrypnosCopy.notification(for: reason))
                }
            }
        }
        apply(applyCommands)
        if commands.contains(where: { if case .disengage = $0 { return true }; return false }) {
            store.save(engine.preferences)
        }
    }

    static func isPostIdleAfterWait(_ command: WatchCommand) -> Bool {
        if case .postIdleAfterWaitNotif = command { return true }
        return false
    }

    /// Popover/hotkey off: sample lid, restore hygiene only if we are not about to sleepnow.
    @discardableResult
    func applyUserOff() -> HygieneApplyResult {
        pollLid()
        let confirmed = engine.userOffLidCloseConfirmed(rawClosed: readLid())
        if engine.holdingForIdlePost {
            engine.completeIdlePostHold()
        }
        let commands = engine.userSetEngaged(false, now: Date(), lidClosed: confirmed)
        let sleep = commands.filter { $0 == .requestSleep }
        apply(commands.filter { $0 != .requestSleep })
        if HygieneRestore.shouldRestoreAfterDisengage(
            lidCloseConfirmed: confirmed,
            nextCommandIsSleep: !sleep.isEmpty
        ) {
            restoreHygiene()
        } else {
            dropSavedHygieneWithoutWrite()
        }
        return apply(sleep)
    }
}
