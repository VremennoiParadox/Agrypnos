import XCTest
@testable import AgrypnosCore

final class NotifPreferenceTests: XCTestCase {
    func testNotifEnabledDefaultsOff() {
        XCTAssertFalse(UserPreferences.default.notifEnabled)
        XCTAssertFalse(UserPreferences().notifEnabled)
    }

    func testMissingNotifEnabledKeyDecodesFalse() throws {
        let json = """
        {"batteryFloorPercent":15,"duration":"indefinite","keyboardBacklightOff":true,"applyBrightnessFloor":true,"brightnessFloorPercent":15,"agentSettleGrace":120,"sessionFreshness":45,"lidOpenRampSeconds":2,"hotkey":{"keyCode":0,"option":true,"command":true,"shift":false,"control":false},"thermalAutoOff":true}
        """
        let decoded = try JSONDecoder().decode(UserPreferences.self, from: Data(json.utf8))
        XCTAssertFalse(decoded.notifEnabled)

        let encoded = try JSONEncoder().encode(UserPreferences.default)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(object["notifEnabled"] as? Bool, false)

        var on = UserPreferences.default
        on.notifEnabled = true
        let roundTripped = try JSONDecoder().decode(
            UserPreferences.self,
            from: try JSONEncoder().encode(on)
        )
        XCTAssertTrue(roundTripped.notifEnabled)
    }
}

final class NotifIdlePostPolicyTests: XCTestCase {
    func testShouldPostIsOnlyEnabledAgentsSettledAndSawBusy() {
        XCTAssertTrue(
            NotifIdlePostPolicy.shouldPost(enabled: true, reason: .agentsSettled, sawBusy: true)
        )
        XCTAssertFalse(
            NotifIdlePostPolicy.shouldPost(enabled: false, reason: .agentsSettled, sawBusy: true)
        )
        XCTAssertFalse(
            NotifIdlePostPolicy.shouldPost(enabled: true, reason: .agentsSettled, sawBusy: false)
        )
        XCTAssertFalse(
            NotifIdlePostPolicy.shouldPost(enabled: true, reason: .timerExpired, sawBusy: true)
        )
    }

    func testDisabledNeverFiresEvenWithSecretsAndSettle() {
        XCTAssertEqual(
            channels(
                enabled: false,
                reason: .agentsSettled,
                sawBusy: true,
                discord: "https://discord.com/api/webhooks/1/abc",
                token: "123:token",
                chat: "99"
            ),
            []
        )
    }

    func testNeverBusyThisArmDoesNotFire() {
        XCTAssertEqual(
            channels(
                enabled: true,
                reason: .agentsSettled,
                sawBusy: false,
                discord: "https://discord.com/api/webhooks/1/abc",
                token: "123:token",
                chat: "99"
            ),
            []
        )
    }

    func testOnlyAgentsSettledFires() {
        let secrets = (
            discord: "https://discord.com/api/webhooks/1/abc",
            token: "123:token",
            chat: "99"
        )
        for reason in DisengageReason.allCases where reason != .agentsSettled {
            XCTAssertEqual(
                channels(
                    enabled: true,
                    reason: reason,
                    sawBusy: true,
                    discord: secrets.discord,
                    token: secrets.token,
                    chat: secrets.chat
                ),
                [],
                "must not POST for \(reason.rawValue)"
            )
        }
        XCTAssertEqual(
            channels(
                enabled: true,
                reason: .agentsSettled,
                sawBusy: true,
                discord: secrets.discord,
                token: secrets.token,
                chat: secrets.chat
            ),
            [.discord, .telegram]
        )
    }

    func testDiscordOnlyWhenWebhookSet() {
        XCTAssertEqual(
            channels(
                enabled: true,
                reason: .agentsSettled,
                sawBusy: true,
                discord: "https://discord.com/api/webhooks/1/abc",
                token: nil,
                chat: nil
            ),
            [.discord]
        )
        XCTAssertEqual(
            channels(
                enabled: true,
                reason: .agentsSettled,
                sawBusy: true,
                discord: "  ",
                token: nil,
                chat: nil
            ),
            []
        )
    }

    func testTelegramNeedsTokenAndChatId() {
        XCTAssertEqual(
            channels(
                enabled: true,
                reason: .agentsSettled,
                sawBusy: true,
                discord: nil,
                token: "123:token",
                chat: "99"
            ),
            [.telegram]
        )
        XCTAssertEqual(
            channels(
                enabled: true,
                reason: .agentsSettled,
                sawBusy: true,
                discord: nil,
                token: "123:token",
                chat: nil
            ),
            []
        )
        XCTAssertEqual(
            channels(
                enabled: true,
                reason: .agentsSettled,
                sawBusy: true,
                discord: nil,
                token: nil,
                chat: "99"
            ),
            []
        )
        XCTAssertEqual(
            channels(
                enabled: true,
                reason: .agentsSettled,
                sawBusy: true,
                discord: nil,
                token: "  ",
                chat: "99"
            ),
            []
        )
    }

    private func channels(
        enabled: Bool,
        reason: DisengageReason,
        sawBusy: Bool,
        discord: String?,
        token: String?,
        chat: String?
    ) -> [NotifChannel] {
        guard NotifIdlePostPolicy.shouldPost(
            enabled: enabled,
            reason: reason,
            sawBusy: sawBusy
        ) else {
            return []
        }
        return NotifIdlePostPolicy.destinations(
            discordWebhookURL: discord,
            telegramBotToken: token,
            telegramChatId: chat
        )
    }
}

final class NotifWatchEngineTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 10_000)

    func testDefaultOffDoesNotEmitIdleNotifOnAgentsSettled() {
        var prefs = UserPreferences.default
        prefs.duration = .untilAgentsSettle
        XCTAssertFalse(prefs.notifEnabled)
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0)
        busyThenSettle(&engine)
        XCTAssertEqual(
            engine.tick(now: t0.addingTimeInterval(20 + 120), safety: .acPower, agents: .idle),
            [.disengage(.agentsSettled)]
        )
    }

    func testEnabledEmitsIdleNotifOnlyAfterBusyThenSettle() {
        var prefs = UserPreferences.default
        prefs.duration = .untilAgentsSettle
        prefs.notifEnabled = true
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0)
        XCTAssertTrue(
            engine.tick(now: t0.addingTimeInterval(10), safety: .acPower, agents: .idle).isEmpty
        )
        XCTAssertTrue(engine.engaged)
        busyThenSettle(&engine)
        XCTAssertEqual(
            engine.tick(now: t0.addingTimeInterval(20 + 120), safety: .acPower, agents: .idle),
            [.disengage(.agentsSettled), .postIdleAfterWaitNotif]
        )
    }

    func testNeverBusyDoesNotEmitIdleNotifWhenEnabled() {
        var prefs = UserPreferences.default
        prefs.duration = .untilAgentsSettle
        prefs.notifEnabled = true
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0)
        XCTAssertTrue(
            engine.tick(now: t0.addingTimeInterval(10_000), safety: .acPower, agents: .idle).isEmpty
        )
        XCTAssertTrue(engine.engaged)
    }

    func testOtherDisengageReasonsDoNotEmitIdleNotifWhenEnabled() {
        var prefs = UserPreferences.default
        prefs.notifEnabled = true
        prefs.duration = .oneHour
        var timed = WatchEngine(preferences: prefs)
        _ = timed.userSetEngaged(true, now: t0)
        XCTAssertEqual(
            timed.tick(now: t0.addingTimeInterval(3600), safety: .acPower, agents: .idle),
            [.disengage(.timerExpired)]
        )

        prefs.duration = .indefinite
        var battery = WatchEngine(preferences: prefs)
        _ = battery.userSetEngaged(true, now: t0)
        XCTAssertEqual(
            battery.tick(
                now: t0.addingTimeInterval(1),
                safety: SafetyInputs(
                    batteryPercent: 12,
                    onBatteryDischarging: true,
                    thermalSerious: false,
                    lowPowerMode: false
                ),
                agents: .idle
            ),
            [.disengage(.batteryFloor)]
        )

        var thermal = WatchEngine(preferences: prefs)
        _ = thermal.userSetEngaged(true, now: t0)
        XCTAssertEqual(
            thermal.tick(
                now: t0.addingTimeInterval(1),
                safety: SafetyInputs(
                    batteryPercent: 90,
                    onBatteryDischarging: false,
                    thermalSerious: true,
                    lowPowerMode: false
                ),
                agents: .idle
            ),
            [.disengage(.thermal)]
        )

        var manual = WatchEngine(preferences: prefs)
        _ = manual.userSetEngaged(true, now: t0)
        XCTAssertEqual(
            manual.userSetEngaged(false, now: t0.addingTimeInterval(1)),
            [.disengage(.user)]
        )

        var leftover = WatchEngine(preferences: prefs)
        _ = leftover.adoptLeftoverKernel(now: t0)
        XCTAssertEqual(
            leftover.tick(
                now: t0.addingTimeInterval(1),
                safety: SafetyInputs(
                    batteryPercent: 50,
                    onBatteryDischarging: true,
                    thermalSerious: false,
                    lowPowerMode: true
                ),
                agents: .idle
            ),
            [.disengage(.lowPowerMode)]
        )
    }

    func testBusyThenManualOffDoesNotEmitIdleNotif() {
        var prefs = UserPreferences.default
        prefs.duration = .untilAgentsSettle
        prefs.notifEnabled = true
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0)
        XCTAssertTrue(
            engine.tick(now: t0.addingTimeInterval(20), safety: .acPower, agents: .busy).isEmpty
        )
        XCTAssertEqual(
            engine.userSetEngaged(false, now: t0.addingTimeInterval(21)),
            [.disengage(.user)]
        )
    }

    func testLidClosedAgentsSettlePostsThenRequestsSleep() {
        var prefs = UserPreferences.default
        prefs.duration = .untilAgentsSettle
        prefs.notifEnabled = true
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: true)
        busyThenSettle(&engine)
        XCTAssertEqual(
            engine.tick(now: t0.addingTimeInterval(20 + 120), safety: .acPower, agents: .idle),
            [.disengage(.agentsSettled), .postIdleAfterWaitNotif, .requestSleep]
        )
    }

    func testDisarmFailureRollbackDoesNotPostASecondTime() {
        var prefs = UserPreferences.default
        prefs.duration = .untilAgentsSettle
        prefs.notifEnabled = true
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0)
        busyThenSettle(&engine)
        XCTAssertEqual(
            engine.tick(now: t0.addingTimeInterval(20 + 120), safety: .acPower, agents: .idle),
            [.disengage(.agentsSettled), .postIdleAfterWaitNotif]
        )
        XCTAssertTrue(engine.postedThisUserArm)
        XCTAssertFalse(engine.engaged)

        let rollback = engine.rollbackDisarmFailure(now: t0.addingTimeInterval(21), lidClosed: false)
        XCTAssertTrue(engine.engaged)
        XCTAssertTrue(engine.postedThisUserArm)
        XCTAssertTrue(rollback.contains(.engage))

        XCTAssertTrue(
            engine.tick(now: t0.addingTimeInterval(40), safety: .acPower, agents: .busy).isEmpty
        )
        XCTAssertTrue(
            engine.tick(now: t0.addingTimeInterval(40 + 119), safety: .acPower, agents: .idle).isEmpty
        )
        XCTAssertEqual(
            engine.tick(now: t0.addingTimeInterval(40 + 120), safety: .acPower, agents: .idle),
            [.disengage(.agentsSettled)],
            "same user arm must not POST again after disarm-failure rollback"
        )
    }

    func testGenuineUserRearmAllowsAnotherIdlePost() {
        var prefs = UserPreferences.default
        prefs.duration = .untilAgentsSettle
        prefs.notifEnabled = true
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0)
        busyThenSettle(&engine)
        XCTAssertEqual(
            engine.tick(now: t0.addingTimeInterval(20 + 120), safety: .acPower, agents: .idle),
            [.disengage(.agentsSettled), .postIdleAfterWaitNotif]
        )

        _ = engine.userSetEngaged(true, now: t0.addingTimeInterval(200))
        XCTAssertFalse(engine.postedThisUserArm)
        XCTAssertTrue(
            engine.tick(now: t0.addingTimeInterval(220), safety: .acPower, agents: .busy).isEmpty
        )
        XCTAssertTrue(
            engine.tick(now: t0.addingTimeInterval(220 + 119), safety: .acPower, agents: .idle).isEmpty
        )
        XCTAssertEqual(
            engine.tick(now: t0.addingTimeInterval(220 + 120), safety: .acPower, agents: .idle),
            [.disengage(.agentsSettled), .postIdleAfterWaitNotif]
        )
    }

    private func busyThenSettle(_ engine: inout WatchEngine) {
        XCTAssertTrue(
            engine.tick(
                now: t0.addingTimeInterval(20),
                safety: .acPower,
                agents: .busy
            ).isEmpty
        )
        XCTAssertTrue(
            engine.tick(
                now: t0.addingTimeInterval(20 + 119),
                safety: .acPower,
                agents: .idle
            ).isEmpty
        )
    }
}

final class NotifCopyTests: XCTestCase {
    func testIdleBodyAndHelpAreIdleAfterWaitNotJobFinished() {
        XCTAssertEqual(
            AgrypnosCopy.notifIdleBody,
            "Agrypnos: local busy signals went idle after the wait."
        )
        XCTAssertFalse(
            AgrypnosCopy.notifIdleBody.lowercased().contains("watch turned off"),
            "outbound body is idle-after-wait only"
        )
        XCTAssertEqual(
            AgrypnosCopy.notifEnabledHelp,
            "POST to your Discord webhook and/or message your Telegram bot after Agents stay idle through the wait. Off by default."
        )
        XCTAssertTrue(AgrypnosCopy.notifDiscordHelp.lowercased().contains("your webhook"))
        XCTAssertTrue(AgrypnosCopy.notifTelegramHelp.lowercased().contains("your telegram bot"))
        XCTAssertTrue(AgrypnosCopy.notifTelegramHelp.lowercased().contains("does not run a shared bot"))
        let blob = [
            AgrypnosCopy.notifEnabled,
            AgrypnosCopy.notifEnabledHelp,
            AgrypnosCopy.notifDiscord,
            AgrypnosCopy.notifDiscordHelp,
            AgrypnosCopy.notifDiscordInvalid,
            AgrypnosCopy.notifTelegram,
            AgrypnosCopy.notifTelegramToken,
            AgrypnosCopy.notifTelegramChatId,
            AgrypnosCopy.notifTelegramHelp,
            AgrypnosCopy.notifSetup,
            AgrypnosCopy.notifSetupHelp,
            AgrypnosCopy.notifClear,
            AgrypnosCopy.notifIdleBody,
        ].joined(separator: "\n").lowercased()
        for banned in [
            "we notify your phone",
            "notify your phone",
            "agent stopped",
            "job finished",
            "still thinking",
            "agent finished",
        ] {
            XCTAssertFalse(blob.contains(banned), "banned phrase in Notif copy: \(banned)")
        }
        XCTAssertTrue(blob.contains("idle after the wait") || blob.contains("idle through the wait"))
    }
}

private extension SafetyInputs {
    static let acPower = SafetyInputs(
        batteryPercent: 90,
        onBatteryDischarging: false,
        thermalSerious: false,
        lowPowerMode: false
    )
}

private extension AgentSnapshot {
    static let idle = AgentSnapshot(reports: [])
    static let busy = AgentSnapshot(reports: [
        AgentReport(
            kind: .claudeCode,
            processRunning: true,
            cpuBusy: true,
            recentSessionWrite: true,
            isBusy: true
        )
    ])
}
