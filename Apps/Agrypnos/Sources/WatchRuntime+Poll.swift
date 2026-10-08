import Foundation

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

extension WatchRuntime {
    func poll() {
        let probe = WatchTickProbe.needed(engaged: engine.engaged, mode: engine.mode,
            questionTimeoutPending: !questionUnansweredKeys.isEmpty)
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
        let (questionWait, questionNotices) = questionWaitDecision(agents: agents, observeAgents: observeAgents)
        let commands = engine.tick(
            now: now,
            safety: safety,
            agents: agents,
            kernelSleepDisabled: kernel,
            observeAgents: observeAgents,
            questionWait: questionWait
        )
        if engine.engaged {
            for notice in questionNotices { Task { await attemptQuestionNotice(notice) } }
        }
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
            finishTickCommands(commands, postToken: token)
            delegate?.watchRuntimeDidChange(self)
            return
        }
        finishTickCommands(commands)
        delegate?.watchRuntimeDidChange(self)
    }

    func finishTickCommands(_ commands: [WatchCommand], postToken: UInt64? = nil) {
        var applyCommands = commands.filter { !Self.isOutboundPost($0) }
        var released = false
        var disengageReason: DisengageReason?
        for command in commands {
            if case .disengage(let reason) = command {
                disengageReason = reason
                if !disarmKernel() {
                    idleOutbound.cancelInFlight()
                    let rollback = engine.rollbackDisarmFailure(now: Date())
                    // A failed clear left SleepDisabled held; do not turn a valid rollback into a failed reassertion.
                    let commands = readKernel() == .held ? rollback.filter { $0 != .assertSleepDisabled } : rollback
                    apply(commands)
                    syncDeadlineTimer()
                    notify("Couldn't verify SleepDisabled was cleared.")
                    if reason == .questionUnanswered, !questionReleaseFailureReported {
                        questionReleaseFailureReported = true
                        Task { await attemptQuestionNotice("Agrypnos couldn't turn the watch off after an unanswered question.") }
                    }
                    store.save(engine.preferences)
                    return
                }
                if reason == .questionUnanswered {
                    let key = questionUnansweredKeys.first
                    let shouldSleep = applyCommands.contains(.requestSleep) && engine.lastDisengageLidClosed
                    applyCommands.removeAll { $0 == .requestSleep }
                    let result = apply(applyCommands)
                    store.save(engine.preferences)
                    clearQuestionWatch()
                    let context = key.map { "\n\($0.provider.displayName) · session \($0.sessionID.prefix(80))" } ?? ""
                    var message = "Agrypnos: watch turned off because an agent question went unanswered for 10 minutes."
                    if shouldSleep { message += " Asking the Mac to sleep." }
                    message += context
                    let captured = questionSleepGeneration
                    questionSleepTask = Task { [weak self] in
                        guard let self else { return }
                        await self.attemptQuestionNotice(message)
                        guard !Task.isCancelled, self.questionSleepGeneration == captured,
                              !self.engine.engaged else { return }
                        // The notification can take three seconds. Confirm the current close again
                        // so an open/reclose during delivery cannot borrow the old confirmation.
                        var lid = LidCloseConfirm()
                        _ = lid.sample(self.readLid() == true, now: Date())
                        if shouldSleep { try? await Task.sleep(nanoseconds: 250_000_000) }
                        guard !Task.isCancelled, self.questionSleepGeneration == captured,
                              !self.engine.engaged else { return }
                        _ = lid.sample(self.readLid() == true, now: Date())
                        let canSleep = shouldSleep && lid.confirmedClosed
                        let final = canSleep ? self.apply([.requestSleep]) : result
                        self.finishDisengageHygiene(sleepResult: final)
                        self.questionSleepTask = nil
                        self.delegate?.watchRuntimeDidChange(self)
                    }
                    return
                }
                clearQuestionWatch()
                // Recheck after the blocking clear/read, preserving live confirmation during POST.
                removeSleepIfLidOpen(&applyCommands, reason: reason)
                released = true
                if reason != .user { notify(AgrypnosCopy.notification(for: reason)) }
            }
        }
        let willSleep = applyCommands.contains(.requestSleep)
        let enabled = engine.preferences.notifEnabled
        let needsPost = postToken != nil || shouldAwaitWatchEndPost(
            enabled: enabled, reason: disengageReason, willSleep: willSleep
        )
        if needsPost {
            idlePostTask?.cancel()
            idlePostTask = Task { @MainActor in
                await self.postIdle(enabled, disengageReason, willSleep)
                guard !Task.isCancelled else { return }
                if let postToken, !self.idleOutbound.completePost(token: postToken) { return }
                WatchDiagnostics.event("idle POST attempt complete; releasing hold")
                var liveCommands = applyCommands
                self.removeSleepIfLidOpen(&liveCommands, reason: disengageReason)
                self.engine.completeIdlePostHold()
                self.applyPreparedDisengage(liveCommands, released: released)
                self.idlePostTask = nil
                self.delegate?.watchRuntimeDidChange(self)
            }
            return
        }
        if released {
            engine.completeIdlePostHold()
        }
        applyPreparedDisengage(applyCommands, released: released)
    }

    func removeSleepIfLidOpen(_ applyCommands: inout [WatchCommand], reason: DisengageReason?) {
        let rawClosed = readLid()
        if reason == nil {
            if !engine.userOffLidCloseConfirmed(rawClosed: rawClosed == true) {
                applyCommands.removeAll { $0 == .requestSleep }
            }
            return
        }
        if engine.holdingForIdlePost, reason != .timerExpired {
            _ = engine.observeLid(closed: rawClosed == true, now: Date())
            if !engine.userOffLidCloseConfirmed(rawClosed: rawClosed == true) {
                applyCommands.removeAll { $0 == .requestSleep }
            }
        } else if reason == .timerExpired ? rawClosed == false : rawClosed != true {
            applyCommands.removeAll { $0 == .requestSleep }
        }
    }

    func applyPreparedDisengage(_ applyCommands: [WatchCommand], released: Bool) {
        let result = apply(applyCommands)
        if released {
            finishDisengageHygiene(sleepResult: result)
            store.save(engine.preferences)
        }
    }

    func shouldAwaitWatchEndPost(enabled: Bool, reason: DisengageReason?, willSleep: Bool) -> Bool {
        guard enabled else { return false }
        let secrets = readNotifSecrets()
        let channels = NotifIdlePostPolicy.destinations(
            discordBotToken: secrets.discordBotToken,
            discordChannelId: secrets.discordChannelId,
            telegramBotToken: secrets.telegramBotToken,
            telegramChatId: secrets.telegramChatId
        )
        if channels.contains(.discord),
           DiscordBotOutbound.body(reason: reason, willSleep: willSleep) != nil
        {
            return true
        }
        if channels.contains(.telegram), reason == .timerExpired || reason == .agentsSettled {
            return true
        }
        return false
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
        let reason: DisengageReason?
        let commands: [WatchCommand]
        if engine.engaged {
            commands = engine.userSetEngaged(false, now: Date(), lidClosed: confirmed)
            reason = .user
        } else {
            commands = confirmed ? [.requestSleep] : []
            reason = nil
        }
        let willSleep = commands.contains(.requestSleep)
        let enabled = engine.preferences.notifEnabled
        if shouldAwaitWatchEndPost(enabled: enabled, reason: reason, willSleep: willSleep) {
            idlePostTask = Task { @MainActor in
                await self.postIdle(enabled, reason, willSleep)
                guard !Task.isCancelled else { return }
                let result = self.apply(commands)
                self.finishDisengageHygiene(sleepResult: result)
                self.store.save(self.engine.preferences)
                self.idlePostTask = nil
                self.delegate?.watchRuntimeDidChange(self)
            }
            return HygieneApplyResult()
        }
        let result = apply(commands)
        finishDisengageHygiene(sleepResult: result)
        return result
    }
}
