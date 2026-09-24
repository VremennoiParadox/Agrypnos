import XCTest
@testable import AgrypnosCore

final class TelegramStatusCopyTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_725_000_000)
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_GB")
        return calendar
    }()

    func testArmedIndefiniteNamesModeAndOmitsCountdown() {
        let text = TelegramWatchStatusCopy.reply(base(engaged: true, duration: .indefinite), now: now)
        XCTAssertTrue(text.contains("Keep the watch is on."))
        XCTAssertTrue(text.contains("How long is ∞."))
        XCTAssertTrue(text.contains("Lid is open or unconfirmed."))
        XCTAssertTrue(text.contains("Auto-off at 15% battery."))
        XCTAssertTrue(text.contains("Thermal auto-off is on."))
        XCTAssertFalse(text.lowercased().contains("left"))
        XCTAssertFalse(text.lowercased().contains("remaining"))
        XCTAssertFalse(text.contains("Agents:"))
        XCTAssertFalse(text.contains("Selected tools:"))
    }

    func testDisarmedStillNamesHowLong() {
        let text = TelegramWatchStatusCopy.reply(base(engaged: false, duration: .oneHour), now: now)
        XCTAssertTrue(text.contains("Keep the watch is off."))
        XCTAssertTrue(text.contains("How long is 1h."))
        XCTAssertFalse(text.lowercased().contains("left"))
        XCTAssertFalse(text.lowercased().contains("remaining"))
    }

    func testTimedHowLongNeverCountsDownEvenWhenTimerEndExists() {
        var engine = WatchEngine(preferences: UserPreferences(duration: .threeHours))
        _ = engine.userSetEngaged(true, now: now)
        XCTAssertNotNil(engine.timerEnd)
        let text = TelegramWatchStatusCopy.reply(
            engine.telegramWatchStatus(now: now.addingTimeInterval(60)),
            now: now.addingTimeInterval(60)
        )
        XCTAssertTrue(text.contains("How long is 3h."))
        XCTAssertFalse(text.contains("2h"))
        XCTAssertFalse(text.lowercased().contains("left"))
        XCTAssertFalse(text.lowercased().contains("remaining"))
    }

    func testCustomMinutesNamesTheMode() {
        let text = TelegramWatchStatusCopy.reply(
            base(engaged: true, duration: .customMinutes(33)),
            now: now
        )
        XCTAssertTrue(text.contains("How long is 33m."))
        XCTAssertFalse(text.lowercased().contains("remaining"))
    }

    func testConfirmedClosedUsesStableLidConfirmNotRawClosedWording() {
        let closed = TelegramWatchStatusCopy.reply(
            base(lidCloseConfirmed: true),
            now: now
        )
        XCTAssertTrue(closed.contains("Lid is confirmed closed."))
        XCTAssertFalse(closed.contains("Lid is closed."))
        let open = TelegramWatchStatusCopy.reply(base(lidCloseConfirmed: false), now: now)
        XCTAssertTrue(open.contains("Lid is open or unconfirmed."))
        XCTAssertFalse(open.contains("confirmed closed"))
    }

    func testOneRawClosedSampleIsNotReportedConfirmedClosed() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: now)
        XCTAssertTrue(engine.observeLid(closed: true, now: now).isEmpty)
        XCTAssertFalse(engine.lidCloseConfirmed)
        let text = TelegramWatchStatusCopy.reply(engine.telegramWatchStatus(now: now), now: now)
        XCTAssertTrue(text.contains("Lid is open or unconfirmed."))
        XCTAssertFalse(text.contains("confirmed closed"))
    }

    func testStableClosedConfirmIsReportedConfirmedClosed() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: now)
        _ = engine.observeLid(closed: true, now: now)
        _ = engine.observeLid(closed: true, now: now.addingTimeInterval(LidCloseConfirm.pulseInterval))
        XCTAssertTrue(engine.lidCloseConfirmed)
        let text = TelegramWatchStatusCopy.reply(
            engine.telegramWatchStatus(now: now.addingTimeInterval(LidCloseConfirm.pulseInterval)),
            now: now
        )
        XCTAssertTrue(text.contains("Lid is confirmed closed."))
    }

    func testAgentsLinesCoverSelectedToolsBusySeenAndSettleWait() {
        let text = TelegramWatchStatusCopy.reply(
            base(
                duration: .untilAgentsSettle,
                includedAgentKinds: [.cursor, .openCode],
                sawBusyThisArm: true,
                settlingAfterBusy: true
            ),
            now: now
        )
        XCTAssertTrue(text.contains("How long is Agents."))
        XCTAssertTrue(text.contains("Selected tools: Cursor, OpenCode."))
        XCTAssertTrue(text.contains("Local busy signals seen this arm."))
        XCTAssertTrue(text.contains("Waiting after local busy signals stop."))
        XCTAssertFalse(text.lowercased().contains("still thinking"))
        XCTAssertFalse(text.lowercased().contains("job finished"))
        XCTAssertFalse(text.lowercased().contains("agent stopped"))
    }

    func testAgentsNeverBusyOmitsSettleWait() {
        let text = TelegramWatchStatusCopy.reply(
            base(
                duration: .untilAgentsSettle,
                sawBusyThisArm: false,
                settlingAfterBusy: false
            ),
            now: now
        )
        XCTAssertTrue(text.contains("No local busy signals seen this arm."))
        XCTAssertFalse(text.contains("Waiting after local busy signals stop."))
        XCTAssertTrue(text.contains("Selected tools: Cursor, Claude Code, Codex, OpenCode."))
    }

    func testAgentsLinesOmittedWhenHowLongIsNotAgents() {
        let text = TelegramWatchStatusCopy.reply(
            base(
                duration: .indefinite,
                sawBusyThisArm: true,
                settlingAfterBusy: true
            ),
            now: now
        )
        XCTAssertFalse(text.contains("Selected tools:"))
        XCTAssertFalse(text.contains("Local busy signals seen this arm."))
        XCTAssertFalse(text.contains("Waiting after local busy signals stop."))
    }

    func testLastEndHonestyMatchesWatchCaptionAndOmitsWhenUnknown() {
        let event = LastWatchEnd(endedAt: now.addingTimeInterval(-120), reason: .batteryFloor)
        let withEnd = TelegramWatchStatusCopy.reply(base(lastWatchEnd: event), now: now, calendar: calendar)
        XCTAssertTrue(
            withEnd.contains(
                AgrypnosCopy.lastWatchEndCaption(event: event, now: now, calendar: calendar, locale: calendar.locale!)
            )
        )
        let none = TelegramWatchStatusCopy.reply(base(lastWatchEnd: nil), now: now)
        XCTAssertFalse(none.contains("Last watch ended"))
        XCTAssertFalse(none.contains(AgrypnosCopy.lastWatchEndNone))
    }

    func testSafetyPrefsAndLpmHonesty() {
        let thermalOff = TelegramWatchStatusCopy.reply(
            base(batteryFloorPercent: 22, thermalAutoOff: false),
            now: now
        )
        XCTAssertTrue(thermalOff.contains("Auto-off at 22% battery."))
        XCTAssertTrue(thermalOff.contains("Thermal auto-off is off."))
        XCTAssertFalse(thermalOff.contains("Low Power Mode"))

        let forced = TelegramWatchStatusCopy.reply(
            base(lowPowerMode: true, userForcedThisSession: true),
            now: now
        )
        XCTAssertTrue(forced.contains("Low Power Mode is on. Keep the watch is still on."))
        XCTAssertFalse(forced.lowercased().contains("ended"))
        XCTAssertFalse(forced.lowercased().contains("standing down"))

        let unknown = TelegramWatchStatusCopy.reply(base(lowPowerMode: nil), now: now)
        XCTAssertFalse(unknown.contains("Low Power Mode"))
    }

    func testInboundStatusHelperUsesTheFactsDump() {
        let snapshot = base(duration: .untilAgentsSettle, sawBusyThisArm: false)
        XCTAssertEqual(
            TelegramInboundCopy.status(snapshot, now: now, calendar: calendar),
            TelegramWatchStatusCopy.reply(snapshot, now: now, calendar: calendar)
        )
        XCTAssertEqual(
            TelegramInboundCopy.reply(intent: .status, status: snapshot, now: now, calendar: calendar),
            TelegramWatchStatusCopy.reply(snapshot, now: now, calendar: calendar)
        )
    }

    func testDumpBansParkedRichStatusAndCountdowns() {
        let blob = TelegramWatchStatusCopy.reply(
            base(
                duration: .untilAgentsSettle,
                sawBusyThisArm: true,
                settlingAfterBusy: true,
                lastWatchEnd: LastWatchEnd(endedAt: now, reason: .agentsSettled)
            ),
            now: now,
            calendar: calendar
        ).lowercased()
        for banned in [
            "eta",
            "still thinking",
            "job finished",
            "agent stopped",
            "task text",
            "finish eta",
            "remaining",
            "we notify your phone",
        ] {
            XCTAssertFalse(blob.contains(banned), "banned phrase: \(banned)")
        }
    }

    private func base(
        engaged: Bool = true,
        duration: DurationOption = .indefinite,
        lidCloseConfirmed: Bool = false,
        includedAgentKinds: Set<AgentKind> = AgentIncludeChrome.defaultIncluded,
        sawBusyThisArm: Bool? = nil,
        settlingAfterBusy: Bool? = nil,
        lastWatchEnd: LastWatchEnd? = nil,
        batteryFloorPercent: Int = 15,
        thermalAutoOff: Bool = true,
        lowPowerMode: Bool? = nil,
        userForcedThisSession: Bool = true
    ) -> TelegramWatchStatus {
        TelegramWatchStatus(
            engaged: engaged,
            duration: duration,
            lidCloseConfirmed: lidCloseConfirmed,
            includedAgentKinds: includedAgentKinds,
            sawBusyThisArm: sawBusyThisArm,
            settlingAfterBusy: settlingAfterBusy,
            lastWatchEnd: lastWatchEnd,
            batteryFloorPercent: batteryFloorPercent,
            thermalAutoOff: thermalAutoOff,
            lowPowerMode: lowPowerMode,
            userForcedThisSession: userForcedThisSession
        )
    }
}

final class TelegramStatusSnapshotTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 20_000)

    func testEngineSnapshotReadsLiveWatchFacts() {
        var prefs = UserPreferences(
            batteryFloorPercent: 18,
            duration: .untilAgentsSettle,
            thermalAutoOff: false,
            includedAgentKinds: [.cursor, .claudeCode]
        )
        prefs.lastWatchEnd = LastWatchEnd(endedAt: t0.addingTimeInterval(-10), reason: .user)
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0)
        _ = engine.tick(now: t0.addingTimeInterval(1), safety: .acPower, agents: .busy)
        _ = engine.tick(now: t0.addingTimeInterval(2), safety: .acPower, agents: .idle)

        let snapshot = engine.telegramWatchStatus(
            now: t0.addingTimeInterval(2),
            agentsBusy: false,
            lowPowerMode: true
        )
        XCTAssertTrue(snapshot.engaged)
        XCTAssertEqual(snapshot.duration, .untilAgentsSettle)
        XCTAssertFalse(snapshot.lidCloseConfirmed)
        XCTAssertEqual(snapshot.includedAgentKinds, [.cursor, .claudeCode])
        XCTAssertEqual(snapshot.sawBusyThisArm, true)
        XCTAssertEqual(snapshot.settlingAfterBusy, true)
        XCTAssertEqual(snapshot.lastWatchEnd?.reason, .user)
        XCTAssertEqual(snapshot.batteryFloorPercent, 18)
        XCTAssertFalse(snapshot.thermalAutoOff)
        XCTAssertEqual(snapshot.lowPowerMode, true)
        XCTAssertTrue(snapshot.userForcedThisSession)
    }

    func testEngineSnapshotOmitsSettleWhenBusyUnknown() {
        var engine = WatchEngine(preferences: UserPreferences(duration: .untilAgentsSettle))
        _ = engine.userSetEngaged(true, now: t0)
        let snapshot = engine.telegramWatchStatus(now: t0, agentsBusy: nil)
        XCTAssertEqual(snapshot.sawBusyThisArm, false)
        XCTAssertNil(snapshot.settlingAfterBusy)
        XCTAssertNil(snapshot.lowPowerMode)
    }

    func testLiveBusyWithoutTickCountsAsSeenThisArm() {
        var engine = WatchEngine(preferences: UserPreferences(duration: .untilAgentsSettle))
        _ = engine.userSetEngaged(true, now: t0)
        XCTAssertFalse(engine.settle.sawBusy)
        let snapshot = engine.telegramWatchStatus(now: t0, agentsBusy: true)
        XCTAssertEqual(snapshot.sawBusyThisArm, true)
        XCTAssertEqual(snapshot.settlingAfterBusy, false)
        let text = TelegramWatchStatusCopy.reply(snapshot, now: t0)
        XCTAssertTrue(text.contains("Local busy signals seen this arm."))
        XCTAssertFalse(text.contains("No local busy signals seen this arm."))
        XCTAssertFalse(text.contains("Waiting after local busy signals stop."))
        XCTAssertFalse(engine.settle.sawBusy)
    }

    func testEngineSnapshotFormatsLiveDump() {
        var engine = WatchEngine(
            preferences: UserPreferences(
                batteryFloorPercent: 18,
                duration: .untilAgentsSettle,
                thermalAutoOff: false,
                lastWatchEnd: LastWatchEnd(endedAt: t0.addingTimeInterval(-10), reason: .user),
                includedAgentKinds: [.cursor, .openCode]
            )
        )
        _ = engine.userSetEngaged(true, now: t0)
        let text = TelegramWatchStatusCopy.reply(
            engine.telegramWatchStatus(now: t0, agentsBusy: true, lowPowerMode: true),
            now: t0
        )
        XCTAssertTrue(text.contains("Keep the watch is on."))
        XCTAssertTrue(text.contains("How long is Agents."))
        XCTAssertTrue(text.contains("Lid is open or unconfirmed."))
        XCTAssertTrue(text.contains("Selected tools: Cursor, OpenCode."))
        XCTAssertTrue(text.contains("Local busy signals seen this arm."))
        XCTAssertTrue(text.contains("Auto-off at 18% battery."))
        XCTAssertTrue(text.contains("Thermal auto-off is off."))
        XCTAssertTrue(text.contains("Low Power Mode is on. Keep the watch is still on."))
        XCTAssertTrue(text.contains("Last watch ended"))
        XCTAssertFalse(text.lowercased().contains("remaining"))
        XCTAssertFalse(text.lowercased().contains("still thinking"))
    }

    func testDisarmedAgentsSnapshotKeepsSelectedToolsAndDropsThisArmBusy() {
        let engine = WatchEngine(
            preferences: UserPreferences(
                duration: .untilAgentsSettle,
                includedAgentKinds: [.codex]
            )
        )
        let snapshot = engine.telegramWatchStatus(now: t0, agentsBusy: true)
        XCTAssertFalse(snapshot.engaged)
        XCTAssertEqual(snapshot.includedAgentKinds, [.codex])
        XCTAssertNil(snapshot.sawBusyThisArm)
        XCTAssertNil(snapshot.settlingAfterBusy)
    }
}

private extension SafetyInputs {
    static let acPower = SafetyInputs(
        batteryPercent: 90, onBatteryDischarging: false, thermalSerious: false, lowPowerMode: false
    )
}

private extension AgentSnapshot {
    static let idle = AgentSnapshot(reports: [])
    static let busy = AgentSnapshot(reports: [
        AgentReport(kind: .cursor, processRunning: true, cpuBusy: false, recentSessionWrite: false, isBusy: true),
    ])
}
