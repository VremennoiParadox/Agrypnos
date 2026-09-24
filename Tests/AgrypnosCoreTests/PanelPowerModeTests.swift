import XCTest
@testable import AgrypnosCore

final class PanelPowerModePreferenceTests: XCTestCase {
    func testDefaultIsFloorModeA() {
        XCTAssertEqual(PanelPowerMode.default, .floor)
        XCTAssertEqual(UserPreferences.default.panelPowerMode, .floor)
        XCTAssertEqual(UserPreferences().panelPowerMode, .floor)
        XCTAssertTrue(UserPreferences.default.panelPowerMode.writesBrightnessFloor)
        XCTAssertFalse(UserPreferences.default.panelPowerMode.sleepsDisplay)
        XCTAssertTrue(UserPreferences.default.panelPowerMode.showsLidOpenRamp)
    }

    func testDisplaySleepModePersistsAndMissingKeyDecodesToFloor() throws {
        var prefs = UserPreferences.default
        prefs.panelPowerMode = .displaySleep
        let data = try JSONEncoder().encode(prefs)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["panelPowerMode"] as? String, "displaySleep")
        let loaded = try JSONDecoder().decode(UserPreferences.self, from: data)
        XCTAssertEqual(loaded.panelPowerMode, .displaySleep)
        XCTAssertTrue(loaded.panelPowerMode.sleepsDisplay)
        XCTAssertFalse(loaded.panelPowerMode.writesBrightnessFloor)
        XCTAssertFalse(loaded.panelPowerMode.showsLidOpenRamp)

        let missing = try JSONDecoder().decode(
            UserPreferences.self,
            from: Data(
                """
                {"batteryFloorPercent":15,"duration":"indefinite","keyboardBacklightOff":true,"applyBrightnessFloor":true,"brightnessFloorPercent":15,"sessionFreshness":45,"hotkey":{"keyCode":0,"option":true,"command":true,"shift":false,"control":false}}
                """.utf8
            )
        )
        XCTAssertEqual(missing.panelPowerMode, .floor)
    }

    func testUnknownPanelPowerModeDecodesToFloor() throws {
        let json = """
        {"batteryFloorPercent":15,"duration":"indefinite","keyboardBacklightOff":true,"applyBrightnessFloor":true,"brightnessFloorPercent":15,"sessionFreshness":45,"panelPowerMode":"panelNap","hotkey":{"keyCode":0,"option":true,"command":true,"shift":false,"control":false}}
        """
        let decoded = try JSONDecoder().decode(UserPreferences.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.panelPowerMode, .floor)
    }
}

final class PanelPowerHygieneGateTests: XCTestCase {
    func testFloorWriteOnlyWhenArmedConfirmedAndModeA() {
        XCTAssertTrue(PanelPowerMode.shouldWriteFloor(armed: true, lidCloseConfirmed: true, mode: .floor))
        XCTAssertFalse(PanelPowerMode.shouldWriteFloor(armed: false, lidCloseConfirmed: true, mode: .floor))
        XCTAssertFalse(PanelPowerMode.shouldWriteFloor(armed: true, lidCloseConfirmed: false, mode: .floor))
        XCTAssertFalse(PanelPowerMode.shouldWriteFloor(armed: true, lidCloseConfirmed: true, mode: .displaySleep))
    }

    func testDisplaySleepOnlyWhenArmedConfirmedAndModeB() {
        XCTAssertTrue(PanelPowerMode.shouldSleepDisplay(armed: true, lidCloseConfirmed: true, mode: .displaySleep))
        XCTAssertFalse(PanelPowerMode.shouldSleepDisplay(armed: false, lidCloseConfirmed: true, mode: .displaySleep))
        XCTAssertFalse(PanelPowerMode.shouldSleepDisplay(armed: true, lidCloseConfirmed: false, mode: .displaySleep))
        XCTAssertFalse(PanelPowerMode.shouldSleepDisplay(armed: true, lidCloseConfirmed: true, mode: .floor))
    }

    func testLidCloseCommandsNeverFloorAndDisplaySleepTogether() {
        let floor = PanelPowerMode.lidCloseCommands(
            mode: .floor,
            applyBrightnessFloor: true,
            keyboardBacklightOff: true
        )
        XCTAssertEqual(floor, [.applyBrightnessFloor, .requestKeyboardBacklightOff])
        XCTAssertFalse(floor.contains(.requestDisplaySleep))
        XCTAssertFalse(floor.contains(.requestSleep))

        let displaySleep = PanelPowerMode.lidCloseCommands(
            mode: .displaySleep,
            applyBrightnessFloor: true,
            keyboardBacklightOff: true
        )
        XCTAssertEqual(displaySleep, [.requestDisplaySleep, .requestKeyboardBacklightOff])
        XCTAssertFalse(displaySleep.contains(.applyBrightnessFloor))
        XCTAssertFalse(displaySleep.contains(.requestSleep))
        XCTAssertFalse(displaySleep.contains(.rampBrightnessRestore))

        for mode in PanelPowerMode.allCases {
            let commands = PanelPowerMode.lidCloseCommands(
                mode: mode,
                applyBrightnessFloor: true,
                keyboardBacklightOff: true
            )
            XCTAssertFalse(
                commands.contains(.applyBrightnessFloor) && commands.contains(.requestDisplaySleep)
            )
        }
    }

    func testLidOpenRampOnlyOnFloorPath() {
        XCTAssertEqual(
            PanelPowerMode.lidOpenCommands(
                mode: .floor,
                applyBrightnessFloor: true,
                keyboardBacklightOff: true
            ),
            [.rampBrightnessRestore, .restoreKeyboardBacklight]
        )
        XCTAssertEqual(
            PanelPowerMode.lidOpenCommands(
                mode: .displaySleep,
                applyBrightnessFloor: true,
                keyboardBacklightOff: true
            ),
            [.wakeDisplay, .restoreKeyboardBacklight]
        )
        let b = PanelPowerMode.lidOpenCommands(
            mode: .displaySleep,
            applyBrightnessFloor: true,
            keyboardBacklightOff: false
        )
        XCTAssertEqual(b, [.wakeDisplay])
        XCTAssertFalse(b.contains(.rampBrightnessRestore))
        XCTAssertFalse(b.contains(.applyBrightnessFloor))
    }

    func testBDisengageWakesDisplayAndDoesNotWriteFloor() {
        XCTAssertNil(PanelPowerMode.disengageDisplayCommand(mode: .floor))
        XCTAssertEqual(PanelPowerMode.disengageDisplayCommand(mode: .displaySleep), .wakeDisplay)
        XCTAssertFalse(PanelPowerMode.displaySleep.writesBrightnessFloor)
        XCTAssertNil(HygieneRestore.displayBrightnessToRestore(captured: nil, floor: 0.15))
    }
}

final class PanelPowerWatchEngineTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 10_000)

    func testPowerAConfirmedCloseFloorsAndDoesNotSleepDisplay() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: false)
        XCTAssertTrue(engine.observeLid(closed: true, now: t0).isEmpty)
        let commands = engine.observeLid(
            closed: true,
            now: t0.addingTimeInterval(LidCloseConfirm.pulseInterval)
        )
        XCTAssertEqual(
            commands,
            [.assertSleepDisabled, .applyBrightnessFloor, .requestKeyboardBacklightOff]
        )
        XCTAssertFalse(commands.contains(.requestDisplaySleep))
        XCTAssertFalse(commands.contains(.requestSleep))
        XCTAssertTrue(engine.engaged)
        XCTAssertTrue(engine.lidHygieneApplied)
    }

    func testPowerBConfirmedCloseSleepsDisplayWithoutFloor() {
        var prefs = UserPreferences.default
        prefs.panelPowerMode = .displaySleep
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: false)
        XCTAssertTrue(engine.observeLid(closed: true, now: t0).isEmpty)
        XCTAssertFalse(engine.lidHygieneApplied)
        let commands = engine.observeLid(
            closed: true,
            now: t0.addingTimeInterval(LidCloseConfirm.pulseInterval)
        )
        XCTAssertEqual(
            commands,
            [.assertSleepDisabled, .requestDisplaySleep, .requestKeyboardBacklightOff]
        )
        XCTAssertFalse(commands.contains(.applyBrightnessFloor))
        XCTAssertFalse(commands.contains(.requestSleep))
        XCTAssertTrue(engine.engaged)
        XCTAssertEqual(engine.preferences.duration, .indefinite)
        XCTAssertTrue(engine.lidHygieneApplied)
    }

    func testPowerBUnconfirmedCloseAppliesNeitherFloorNorDisplaySleep() {
        var prefs = UserPreferences.default
        prefs.panelPowerMode = .displaySleep
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: false)
        XCTAssertTrue(engine.observeLid(closed: true, now: t0).isEmpty)
        XCTAssertFalse(engine.lidClosed)
        XCTAssertFalse(engine.lidHygieneApplied)
        XCTAssertTrue(engine.engaged)
    }

    func testPowerBArmToggleDoesNotSleepDisplay() {
        var prefs = UserPreferences.default
        prefs.panelPowerMode = .displaySleep
        var engine = WatchEngine(preferences: prefs)
        let commands = engine.userSetEngaged(true, now: t0, lidClosed: false)
        XCTAssertEqual(commands, [.engage])
        XCTAssertFalse(commands.contains(.requestDisplaySleep))
        XCTAssertFalse(commands.contains(.applyBrightnessFloor))
        XCTAssertFalse(commands.contains(.requestKeyboardBacklightOff))
        XCTAssertFalse(engine.lidHygieneApplied)
    }

    func testPowerBLidOpenWakesDisplayWithoutRamp() {
        var prefs = UserPreferences.default
        prefs.panelPowerMode = .displaySleep
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: false)
        _ = engine.lidDidClose(now: t0.addingTimeInterval(1))
        let commands = engine.lidDidOpen(now: t0.addingTimeInterval(2))
        XCTAssertEqual(commands, [.wakeDisplay, .restoreKeyboardBacklight])
        XCTAssertFalse(commands.contains(.rampBrightnessRestore))
        XCTAssertFalse(commands.contains(.applyBrightnessFloor))
        XCTAssertTrue(engine.engaged)
        XCTAssertFalse(engine.lidHygieneApplied)
    }

    func testPowerBKeepsWatchOnAndDoesNotSleepTheMac() {
        var prefs = UserPreferences.default
        prefs.duration = .untilAgentsSettle
        prefs.panelPowerMode = .displaySleep
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: false)
        _ = engine.lidDidClose(now: t0.addingTimeInterval(1))
        XCTAssertTrue(engine.engaged)
        XCTAssertEqual(engine.preferences.duration, .untilAgentsSettle)
        XCTAssertTrue(
            engine.tick(
                now: t0.addingTimeInterval(2),
                safety: .acPower,
                agents: .busy
            ).isEmpty
        )
        XCTAssertTrue(engine.engaged)
        XCTAssertFalse(engine.lidDidClose(now: t0.addingTimeInterval(3)).contains(.requestSleep))
    }

    func testPowerBBatterySafetyStillTurnsWatchOff() {
        var prefs = UserPreferences.default
        prefs.panelPowerMode = .displaySleep
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: true)
        XCTAssertEqual(
            engine.tick(
                now: t0.addingTimeInterval(1),
                safety: SafetyInputs(
                    batteryPercent: 12,
                    onBatteryDischarging: true,
                    thermalSerious: false,
                    lowPowerMode: false
                ),
                agents: .idle
            ),
            [.disengage(.batteryFloor), .requestSleep]
        )
        XCTAssertFalse(engine.engaged)
        XCTAssertEqual(engine.preferences.duration, .indefinite)
    }

    func testPowerBArmWithLidAlreadyClosedSleepsDisplayNotFloor() {
        var prefs = UserPreferences.default
        prefs.panelPowerMode = .displaySleep
        var engine = WatchEngine(preferences: prefs)
        let commands = engine.userSetEngaged(true, now: t0, lidClosed: true)
        XCTAssertEqual(
            commands,
            [.engage, .assertSleepDisabled, .requestDisplaySleep, .requestKeyboardBacklightOff]
        )
        XCTAssertFalse(commands.contains(.applyBrightnessFloor))
        XCTAssertTrue(engine.lidHygieneApplied)
        XCTAssertTrue(engine.engaged)
    }
}

final class PanelPowerChromeTests: XCTestCase {
    func testChromeIsMutuallyExclusiveAndPlain() {
        XCTAssertEqual(PanelPowerChrome.titles, ["Dim panel", "Sleep panel"])
        XCTAssertEqual(PanelPowerChrome.selectedSegment(mode: .floor), 0)
        XCTAssertEqual(PanelPowerChrome.selectedSegment(mode: .displaySleep), 1)
        XCTAssertEqual(PanelPowerChrome.mode(selectingSegment: 0), .floor)
        XCTAssertEqual(PanelPowerChrome.mode(selectingSegment: 1), .displaySleep)
        XCTAssertNil(PanelPowerChrome.mode(selectingSegment: 2))
        XCTAssertTrue(PanelPowerChrome.showsLidOpenRamp(.floor))
        XCTAssertFalse(PanelPowerChrome.showsLidOpenRamp(.displaySleep))
        XCTAssertTrue(PanelPowerChrome.caption(.floor).lowercased().contains("brightness floor"))
        XCTAssertFalse(PanelPowerChrome.caption(.floor).lowercased().contains("display asleep"))
        XCTAssertTrue(PanelPowerChrome.caption(.displaySleep).lowercased().contains("panel sleeps"))
        XCTAssertTrue(PanelPowerChrome.caption(.displaySleep).lowercased().contains("keep the watch"))
        let banned = [
            "mac asleep",
            "agents stopped",
            "job finished",
            "still thinking",
            "puts the computer to sleep",
            "watt",
        ]
        for blob in [
            PanelPowerChrome.caption(.floor),
            PanelPowerChrome.caption(.displaySleep),
            PanelPowerChrome.help(.floor),
            PanelPowerChrome.help(.displaySleep),
            PanelPowerMode.floor.statusLine,
            PanelPowerMode.displaySleep.statusLine,
        ] {
            let lower = blob.lowercased()
            for phrase in banned {
                XCTAssertFalse(lower.contains(phrase), "\(phrase) in \(blob)")
            }
        }
        XCTAssertTrue(PanelPowerChrome.help(.displaySleep).lowercased().contains("hidden"))
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
            kind: .cursor,
            processRunning: true,
            cpuBusy: false,
            recentSessionWrite: false,
            isBusy: true
        ),
    ])
}
