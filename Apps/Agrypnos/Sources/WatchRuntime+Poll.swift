import Foundation

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

extension WatchRuntime {
    func poll() {
        let probe = WatchTickProbe.needed(engaged: engine.engaged, mode: engine.mode)
        if lidCadence() != .none {
            pollLid()
        } else {
            stopLidPulse()
        }

        if idleOutbound.shouldSkipPoll(engineEngaged: engine.engaged) { return }
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
        syncDeadlineTimer()
        diagnostics.tick(engine: engine, settle: engine.engaged ? engine.settle : previousSettle, busy: agents.anyBusy(included: engine.preferences.includedAgentKinds),
                         now: now, kernel: kernel, observed: observeAgents)
        for command in commands {
            if case .disengage(let reason) = command {
                WatchDiagnostics.event("watch end reason=\(reason) lidConfirmed=\(engine.lastDisengageLidClosed)")
            }
        }
        if commands.contains(where: Self.isOutboundPost) {
            WatchDiagnostics.event("idle POST decision enabled=\(engine.preferences.notifEnabled)")
            let token = idleOutbound.beginPost()
            let enabled = engine.preferences.notifEnabled
            let reason: DisengageReason = commands.contains(.postTimerExpiredNotif) ? .timerExpired : .agentsSettled
            idlePostTask?.cancel()
            idlePostTask = Task { @MainActor in
                await self.postIdle(enabled, reason)
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
        var applyCommands = commands.filter { !Self.isOutboundPost($0) }
        var released = false
        for command in commands {
            if case .disengage(let reason) = command {
                if !disarmKernel() {
                    apply(engine.rollbackDisarmFailure(now: Date()))
                    syncDeadlineTimer()
                    notify("Couldn't verify SleepDisabled was cleared.")
                    store.save(engine.preferences)
                    return
                }
                // Recheck after the blocking clear/read, preserving live confirmation during POST.
                let rawClosed = readLid()
                if engine.holdingForIdlePost, reason != .timerExpired {
                    _ = engine.observeLid(closed: rawClosed == true, now: Date())
                    if !engine.userOffLidCloseConfirmed(rawClosed: rawClosed == true) {
                        applyCommands.removeAll { $0 == .requestSleep }
                    }
                } else if reason == .timerExpired ? rawClosed == false : rawClosed != true {
                    applyCommands.removeAll { $0 == .requestSleep }
                }
                engine.completeIdlePostHold()
                released = true
                if reason != .user { notify(AgrypnosCopy.notification(for: reason)) }
            }
        }
        let result = apply(applyCommands)
        if released {
            finishDisengageHygiene(sleepResult: result)
            store.save(engine.preferences)
        }
    }

    func finishDisengageHygiene(sleepResult: HygieneApplyResult) {
        if sleepResult.sleepnow != nil {
            dropSavedHygieneWithoutWrite()
        } else {
            restoreHygiene()
            if engine.preferences.panelPowerMode == .displaySleep, readLid() != true {
                apply([.wakeDisplay])
            }
        }
    }

    static func isOutboundPost(_ command: WatchCommand) -> Bool {
        command == .postIdleAfterWaitNotif || command == .postTimerExpiredNotif
    }

    /// Popover/hotkey off: sample lid, restore hygiene only if we are not about to sleepnow.
    @discardableResult
    func applyUserOff() -> HygieneApplyResult {
        // Observe only: close-confirm commands must not reassert the hold we just cleared.
        _ = engine.observeLid(closed: readLid() == true, now: Date())
        let confirmed = engine.userOffLidCloseConfirmed(rawClosed: readLid() == true)
        if engine.holdingForIdlePost { engine.completeIdlePostHold() }
        let commands = engine.userSetEngaged(false, now: Date(), lidClosed: confirmed)
        let result = apply(commands)
        finishDisengageHygiene(sleepResult: result)
        return result
    }
}
