# Watch last stand-down Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the last real watch end in the Watch popover: local time plus the Core `DisengageReason`, persisted across sleep and relaunch.

**Architecture:** `LastWatchEnd` (`endedAt` + `DisengageReason`) lives on `UserPreferences`. `WatchEngine.disengage` records it when leaving engaged, keeps it across re-arm, restores it on `rollbackDisarmFailure`. Mac saves prefs after a disarm that sticks. Watch gets a third caption-only card. No history log, no new tab, no invented reasons.

**Tech Stack:** Swift `AgrypnosCore` + XCTest (Linux), AppKit popover on macOS. No new dependencies. Local-only.

## Global Constraints

- Ends the watch and allows sleep (`pmset` SleepDisabled clear). Ban “we put the laptop to sleep”, “screen off”, “agent finished / job done / still thinking”.
- Copy: `Last watch ended at <local time>, because <plain reason>.` Empty: `No watch has ended yet.`
- Only existing `DisengageReason`: `user`, `timerExpired`, `batteryFloor`, `thermal`, `agentsSettled`, `lowPowerMode`. No “error occurred”, no “finished working”, no “ran out of battery” distinct from `batteryFloor`.
- Because-clauses: `you turned it off` · `the timer ended` · `the battery floor was reached` · `thermal pressure turned the watch off` · `local busy signals stayed idle after the wait` · `Low Power Mode was on`.
- Agents = idle-after-wait, not job-done. Thermal: no °C / health / warranty. `requestSleep` may still fire on lid-closed auto-off; copy must not say Agrypnos put the Mac to sleep.
- LPM: Keep-the-watch caption must not claim ended while a forced watch still holds. Last-end card is historical and stays visible while armed.
- Last event only (replace on next real end). Record only if `engaged` was true at disengage start. Re-arm does not clear it. Show in Watch when disarmed.
- Clock: `DateFormatter` `timeStyle = .short`; also `dateStyle = .medium` if not the same calendar day as `now`. Minutes, not seconds. Locale/calendar injectable for tests.
- Persist on `UserPreferences.lastWatchEnd` via existing `PreferencesStore` JSON key `lastWatchEnd`. Missing key = nil.
- Menu-bar only. Watch · Power · Agents · Notif · General, default Watch. No settings window, Licence, or About. Do not change `AgrypnosCopy.notification(for:)`.
- Core decides; Mac persists/displays. TDD in `AgrypnosCoreTests`. Files ≤600 lines. MIT, no telemetry. Product-only commits.

## File map

Core: `Sources/AgrypnosCore/Power/Safety.swift` (`LastWatchEnd`), `Sources/AgrypnosCore/Session/UserPreferences.swift` (`lastWatchEnd?`), `Sources/AgrypnosCore/Session/WatchEngine.swift` (`disengage(_:at:)`), `Sources/AgrypnosCore/Copy/AgrypnosCopy.swift`, `Sources/AgrypnosCore/Copy/CopyWrap.swift` (`lastWatchEndMaxLines = 3`), `Sources/AgrypnosCore/Copy/PopoverSection.swift` (`[.watch, .duration, .lastWatchEnd]`), `Sources/AgrypnosCore/Copy/PopoverStackLayout.swift` (slot). Mac: `Apps/Agrypnos/Sources/WatchRuntime.swift` (save), `Apps/Agrypnos/Sources/MenuBar/PopoverController.swift`, `Apps/Agrypnos/Sources/MenuBar/PopoverController+Canvas.swift`, `Apps/Agrypnos/Sources/MenuBar/PopoverController+Cards.swift`, `Apps/Agrypnos/Sources/MenuBar/PopoverController+Sections.swift`. Tests: `Tests/AgrypnosCoreTests/LastWatchEndTests.swift`, `Tests/AgrypnosCoreTests/PopoverSectionTests.swift`, `Tests/AgrypnosCoreTests/DurationHotkeyCopyTests.swift`. `PreferencesStore` unchanged.

### Task 1: LastWatchEnd on preferences

**Files:** Create `Tests/AgrypnosCoreTests/LastWatchEndTests.swift`. Modify `Safety.swift`, `UserPreferences.swift`.

**Interfaces:**
- Consumes: `DisengageReason` (String raw Codable).
- Produces: `public struct LastWatchEnd: Equatable, Sendable, Codable { public var endedAt: Date; public var reason: DisengageReason; public init(endedAt: Date, reason: DisengageReason) }`. `UserPreferences.lastWatchEnd: LastWatchEnd? = nil`. JSON `lastWatchEnd`. `decodeIfPresent` / `encodeIfPresent`.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import AgrypnosCore

final class LastWatchEndTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 10_000)

    func testDefaultPreferencesHaveNoLastWatchEnd() {
        XCTAssertNil(UserPreferences.default.lastWatchEnd)
        XCTAssertNil(UserPreferences().lastWatchEnd)
    }

    func testLastWatchEndRoundTripsWithPreferences() throws {
        var prefs = UserPreferences.default
        prefs.lastWatchEnd = LastWatchEnd(endedAt: t0, reason: .batteryFloor)
        let loaded = try JSONDecoder().decode(UserPreferences.self, from: try JSONEncoder().encode(prefs))
        XCTAssertEqual(loaded.lastWatchEnd?.endedAt, t0)
        XCTAssertEqual(loaded.lastWatchEnd?.reason, .batteryFloor)
    }

    func testMissingLastWatchEndKeyDecodesNil() throws {
        let json = """
        {"batteryFloorPercent":15,"duration":"indefinite","keyboardBacklightOff":true,"applyBrightnessFloor":true,"brightnessFloorPercent":15,"agentSettleGrace":120,"sessionFreshness":45,"lidOpenRampSeconds":2,"hotkey":{"keyCode":0,"option":true,"command":true,"shift":false,"control":false},"thermalAutoOff":true,"notifEnabled":false}
        """
        let decoded = try JSONDecoder().decode(UserPreferences.self, from: Data(json.utf8))
        XCTAssertNil(decoded.lastWatchEnd)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter LastWatchEndTests`
Expected: FAIL compile (`LastWatchEnd` / `lastWatchEnd` missing).

- [ ] **Step 3: Write minimal implementation**

Append after `DisengageReason` in `Safety.swift`:

```swift
public struct LastWatchEnd: Equatable, Sendable, Codable {
    public var endedAt: Date
    public var reason: DisengageReason
    public init(endedAt: Date, reason: DisengageReason) {
        self.endedAt = endedAt
        self.reason = reason
    }
}
```

On `UserPreferences`: add `public var lastWatchEnd: LastWatchEnd?`, init param `lastWatchEnd: LastWatchEnd? = nil`, `self.lastWatchEnd = lastWatchEnd`, `CodingKeys.lastWatchEnd`, decode `try container.decodeIfPresent(LastWatchEnd.self, forKey: .lastWatchEnd)`, encode `try container.encodeIfPresent(lastWatchEnd, forKey: .lastWatchEnd)`.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter LastWatchEndTests` — Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/AgrypnosCore/Power/Safety.swift Sources/AgrypnosCore/Session/UserPreferences.swift Tests/AgrypnosCoreTests/LastWatchEndTests.swift
git commit -m "$(cat <<'EOF'
Persist the last watch end with user preferences.

EOF
)"
```

---

### Task 2: Last-end copy

**Files:** Modify `AgrypnosCopy.swift`, `CopyWrap.swift`, `LastWatchEndTests.swift`, `DurationHotkeyCopyTests.swift` (`allUserFacingCopy` only).

**Interfaces:**
- Consumes: `LastWatchEnd`, `DisengageReason`.
- Produces: `lastWatchEndNone`, `lastWatchEndReason(_:) -> String`, `lastWatchEndCaption(when:reason:) -> String`, `lastWatchEndClock(endedAt:now:calendar:locale:) -> String`, `lastWatchEndCaption(event:now:calendar:locale:) -> String`. `PopoverCopyLayout.lastWatchEndMaxLines = 3`, `lastWatchEndHeightPoints = 3 * lineHeightPoints`.

- [ ] **Step 1: Write the failing tests**

Append to `LastWatchEndTests`:

```swift
    func testLastWatchEndCopyMatchesLockedReasons() {
        XCTAssertEqual(AgrypnosCopy.lastWatchEndNone, "No watch has ended yet.")
        let expected: [(DisengageReason, String)] = [
            (.user, "Last watch ended at 23:04, because you turned it off."),
            (.timerExpired, "Last watch ended at 23:04, because the timer ended."),
            (.batteryFloor, "Last watch ended at 23:04, because the battery floor was reached."),
            (.thermal, "Last watch ended at 23:04, because thermal pressure turned the watch off."),
            (.agentsSettled, "Last watch ended at 23:04, because local busy signals stayed idle after the wait."),
            (.lowPowerMode, "Last watch ended at 23:04, because Low Power Mode was on."),
        ]
        for (reason, line) in expected {
            XCTAssertEqual(AgrypnosCopy.lastWatchEndCaption(when: "23:04", reason: reason), line)
        }
    }

    func testLastWatchEndCopyIsHonestAndFitsThreeLines() {
        let caption = AgrypnosCopy.lastWatchEndCaption(
            when: "September 17, 2026 at 11:04 PM", reason: .agentsSettled
        )
        let blob = (AgrypnosCopy.lastWatchEndNone + "\n" + caption).lowercased()
        for banned in [
            "we put the laptop to sleep", "screen off", "agent finished", "job done",
            "still thinking", "finished working", "ran out of battery", "error occurred",
            "agent stopped", "job finished", "stands down", "°c", "warranty",
        ] {
            XCTAssertFalse(blob.contains(banned), banned)
        }
        XCTAssertTrue(caption.contains("local busy signals"))
        XCTAssertTrue(caption.contains("after the wait"))
        XCTAssertEqual(PopoverCopyLayout.lastWatchEndMaxLines, 3)
        for reason in DisengageReason.allCases {
            let lines = CopyWrap.lineCount(
                AgrypnosCopy.lastWatchEndCaption(when: "September 17, 2026 at 11:04 PM", reason: reason),
                columns: PopoverCopyLayout.innerColumns
            )
            XCTAssertLessThanOrEqual(lines, PopoverCopyLayout.lastWatchEndMaxLines)
        }
    }

    func testLastWatchEndClockOmitsDateOnTheSameCalendarDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let locale = Locale(identifier: "en_GB")
        let ended = calendar.date(from: DateComponents(year: 2026, month: 9, day: 17, hour: 23, minute: 4))!
        let same = calendar.date(from: DateComponents(year: 2026, month: 9, day: 17, hour: 23, minute: 50))!
        let next = calendar.date(from: DateComponents(year: 2026, month: 9, day: 18, hour: 8, minute: 0))!
        let today = AgrypnosCopy.lastWatchEndClock(endedAt: ended, now: same, calendar: calendar, locale: locale)
        let other = AgrypnosCopy.lastWatchEndClock(endedAt: ended, now: next, calendar: calendar, locale: locale)
        XCTAssertFalse(today.contains("2026"))
        XCTAssertFalse(today.contains("Sep"))
        XCTAssertTrue(other.contains("2026"))
        let event = LastWatchEnd(endedAt: ended, reason: .user)
        XCTAssertEqual(
            AgrypnosCopy.lastWatchEndCaption(event: event, now: same, calendar: calendar, locale: locale),
            AgrypnosCopy.lastWatchEndCaption(when: today, reason: .user)
        )
        XCTAssertEqual(
            AgrypnosCopy.lastWatchEndCaption(event: nil, now: same, calendar: calendar, locale: locale),
            AgrypnosCopy.lastWatchEndNone
        )
    }
```

In `DurationHotkeyCopyTests.allUserFacingCopy()` append:

```swift
            AgrypnosCopy.lastWatchEndNone,
            AgrypnosCopy.lastWatchEndCaption(when: "23:04", reason: .user),
            AgrypnosCopy.lastWatchEndCaption(when: "23:04", reason: .timerExpired),
            AgrypnosCopy.lastWatchEndCaption(when: "23:04", reason: .batteryFloor),
            AgrypnosCopy.lastWatchEndCaption(when: "23:04", reason: .thermal),
            AgrypnosCopy.lastWatchEndCaption(when: "23:04", reason: .agentsSettled),
            AgrypnosCopy.lastWatchEndCaption(when: "23:04", reason: .lowPowerMode),
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter LastWatchEndTests` — Expected: FAIL (copy APIs missing).

- [ ] **Step 3: Write minimal implementation**

`CopyWrap.swift` on `PopoverCopyLayout`:

```swift
    public static let lastWatchEndMaxLines = 3
    public static var lastWatchEndHeightPoints: Int { lastWatchEndMaxLines * lineHeightPoints }
```

`AgrypnosCopy.swift`:

```swift
    public static let lastWatchEndNone = "No watch has ended yet."

    public static func lastWatchEndReason(_ reason: DisengageReason) -> String {
        switch reason {
        case .user: return "you turned it off"
        case .timerExpired: return "the timer ended"
        case .batteryFloor: return "the battery floor was reached"
        case .thermal: return "thermal pressure turned the watch off"
        case .agentsSettled: return "local busy signals stayed idle after the wait"
        case .lowPowerMode: return "Low Power Mode was on"
        }
    }

    public static func lastWatchEndCaption(when: String, reason: DisengageReason) -> String {
        "Last watch ended at \(when), because \(lastWatchEndReason(reason))."
    }

    public static func lastWatchEndClock(
        endedAt: Date, now: Date, calendar: Calendar = .current, locale: Locale = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        formatter.timeStyle = .short
        formatter.dateStyle = calendar.isDate(endedAt, inSameDayAs: now) ? .none : .medium
        return formatter.string(from: endedAt)
    }

    public static func lastWatchEndCaption(
        event: LastWatchEnd?, now: Date, calendar: Calendar = .current, locale: Locale = .current
    ) -> String {
        guard let event else { return lastWatchEndNone }
        let when = lastWatchEndClock(endedAt: event.endedAt, now: now, calendar: calendar, locale: locale)
        return lastWatchEndCaption(when: when, reason: event.reason)
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter LastWatchEndTests --filter AgrypnosCopyTests` — Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/AgrypnosCore/Copy/AgrypnosCopy.swift Sources/AgrypnosCore/Copy/CopyWrap.swift Tests/AgrypnosCoreTests/LastWatchEndTests.swift Tests/AgrypnosCoreTests/DurationHotkeyCopyTests.swift
git commit -m "$(cat <<'EOF'
Add Watch last-end copy mapped to DisengageReason.

EOF
)"
```

---

### Task 3: WatchEngine records the last end

**Files:** Modify `WatchEngine.swift`, `LastWatchEndTests.swift`.

**Interfaces:**
- Consumes: `LastWatchEnd`, `preferences.lastWatchEnd`.
- Produces: `mutating func disengage(_ reason: DisengageReason, at now: Date) -> [WatchCommand]`. Records only when `wasEngaged`. `engage` does not clear `lastWatchEnd`. `rollbackDisarmFailure` restores `lastWatchEndRollback`. Existing command arrays unchanged.

- [ ] **Step 1: Write the failing tests**

Append to `LastWatchEndTests`, including the helpers:

```swift
    func testEveryRealDisengageRecordsLastWatchEnd() {
        func record(_ duration: DurationOption, safety: SafetyInputs, wait: TimeInterval, busyFirst: Bool = false) -> WatchEngine {
            var prefs = UserPreferences.default
            prefs.duration = duration
            var engine = WatchEngine(preferences: prefs)
            _ = engine.userSetEngaged(true, now: t0)
            if busyFirst { _ = engine.tick(now: t0, safety: .acPower, agents: .busy) }
            _ = engine.tick(now: t0.addingTimeInterval(wait), safety: safety, agents: .idle)
            return engine
        }
        var manual = WatchEngine(preferences: .default)
        _ = manual.userSetEngaged(true, now: t0)
        _ = manual.userSetEngaged(false, now: t0.addingTimeInterval(1))
        XCTAssertEqual(manual.preferences.lastWatchEnd, LastWatchEnd(endedAt: t0.addingTimeInterval(1), reason: .user))

        let timer = record(.oneHour, safety: .acPower, wait: 3600)
        XCTAssertEqual(timer.preferences.lastWatchEnd, LastWatchEnd(endedAt: t0.addingTimeInterval(3600), reason: .timerExpired))

        let battery = record(.indefinite, safety: SafetyInputs(batteryPercent: 12, onBatteryDischarging: true, thermalSerious: false, lowPowerMode: false), wait: 1)
        XCTAssertEqual(battery.preferences.lastWatchEnd?.reason, .batteryFloor)

        let thermal = record(.indefinite, safety: SafetyInputs(batteryPercent: 90, onBatteryDischarging: false, thermalSerious: true, lowPowerMode: false), wait: 1)
        XCTAssertEqual(thermal.preferences.lastWatchEnd?.reason, .thermal)

        let agents = record(.untilAgentsSettle, safety: .acPower, wait: 120, busyFirst: true)
        XCTAssertEqual(agents.preferences.lastWatchEnd, LastWatchEnd(endedAt: t0.addingTimeInterval(120), reason: .agentsSettled))

        var leftover = WatchEngine(preferences: .default)
        _ = leftover.adoptLeftoverKernel(now: t0)
        _ = leftover.tick(now: t0.addingTimeInterval(1), safety: .lowPowerDischarging, agents: .idle)
        XCTAssertEqual(leftover.preferences.lastWatchEnd, LastWatchEnd(endedAt: t0.addingTimeInterval(1), reason: .lowPowerMode))
    }

    func testReArmKeepsLastWatchEndUntilTheNextRealEnd() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0)
        _ = engine.userSetEngaged(false, now: t0.addingTimeInterval(5))
        let first = engine.preferences.lastWatchEnd
        _ = engine.userSetEngaged(true, now: t0.addingTimeInterval(10))
        XCTAssertEqual(engine.preferences.lastWatchEnd, first)
        XCTAssertTrue(engine.engaged)
        _ = engine.userSetEngaged(false, now: t0.addingTimeInterval(20))
        XCTAssertEqual(engine.preferences.lastWatchEnd?.endedAt, t0.addingTimeInterval(20))
        _ = engine.userSetEngaged(false, now: t0.addingTimeInterval(30))
        XCTAssertEqual(engine.preferences.lastWatchEnd?.endedAt, t0.addingTimeInterval(20))
    }

    func testForcedLowPowerModeDoesNotRecordAnEnd() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0)
        XCTAssertTrue(engine.tick(now: t0.addingTimeInterval(1), safety: .lowPowerDischarging, agents: .idle).isEmpty)
        XCTAssertTrue(engine.engaged)
        XCTAssertNil(engine.preferences.lastWatchEnd)
    }

    func testRollbackDisarmFailureRestoresPreviousLastWatchEnd() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0)
        _ = engine.userSetEngaged(false, now: t0.addingTimeInterval(5))
        let previous = engine.preferences.lastWatchEnd
        _ = engine.userSetEngaged(true, now: t0.addingTimeInterval(10))
        _ = engine.userSetDuration(.oneHour, now: t0.addingTimeInterval(10))
        XCTAssertEqual(
            engine.tick(now: t0.addingTimeInterval(10 + 3600), safety: .acPower, agents: .idle),
            [.disengage(.timerExpired)]
        )
        XCTAssertEqual(engine.preferences.lastWatchEnd?.reason, .timerExpired)
        _ = engine.rollbackDisarmFailure(now: t0.addingTimeInterval(3611), lidClosed: false)
        XCTAssertTrue(engine.engaged)
        XCTAssertEqual(engine.preferences.lastWatchEnd, previous)
    }
```

Put those methods inside `LastWatchEndTests`. Put the extensions after the class:

```swift
private extension SafetyInputs {
    static let acPower = SafetyInputs(
        batteryPercent: 90, onBatteryDischarging: false, thermalSerious: false, lowPowerMode: false
    )
    static let lowPowerDischarging = SafetyInputs(
        batteryPercent: 50, onBatteryDischarging: true, thermalSerious: false, lowPowerMode: true
    )
}

private extension AgentSnapshot {
    static let idle = AgentSnapshot(reports: [])
    static let busy = AgentSnapshot(reports: [
        AgentReport(kind: .claudeCode, processRunning: true, cpuBusy: true, recentSessionWrite: true, isBusy: true)
    ])
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter LastWatchEndTests` — Expected: FAIL (`lastWatchEnd` nil after disengage).

- [ ] **Step 3: Write minimal implementation**

Add `var lastWatchEndRollback: LastWatchEnd?` on `WatchEngine`. Call `disengage(.user, at: now)` from `userSetEngaged`, and `disengage(reason, at: now)` / `disengage(.agentsSettled, at: now)` from `tick`.

```swift
    mutating func disengage(_ reason: DisengageReason, at now: Date) -> [WatchCommand] {
        let wasEngaged = engaged
        let postIdleAfterWait = !postedThisUserArm && NotifIdlePostPolicy.shouldPost(
            enabled: preferences.notifEnabled, reason: reason, sawBusy: settle.sawBusy
        )
        if wasEngaged {
            lastWatchEndRollback = preferences.lastWatchEnd
            preferences.lastWatchEnd = LastWatchEnd(endedAt: now, reason: reason)
        }
        engaged = false
        mode = .idle
        timerEnd = nil
        userForcedThisSession = false
        leftoverAdopted = false
        lidHygieneApplied = false
        settle.reset()
        var commands: [WatchCommand] = [.disengage(reason)]
        if postIdleAfterWait {
            postedThisUserArm = true
            commands.append(.postIdleAfterWaitNotif)
        }
        if lidClosed, reason != .user {
            commands.append(.requestSleep)
        }
        return commands
    }
```

`rollbackDisarmFailure`:

```swift
    public mutating func rollbackDisarmFailure(now: Date, lidClosed: Bool = false) -> [WatchCommand] {
        let restored = lastWatchEndRollback
        lastWatchEndRollback = nil
        leftoverAdopted = false
        self.lidClosed = lidClosed
        let commands = engage(now: now, forcedByUser: true, resetPostedThisUserArm: false)
        preferences.lastWatchEnd = restored
        return commands
    }
```

Do not clear `preferences.lastWatchEnd` in `engage`.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter LastWatchEndTests --filter WatchEngineTests --filter WatchLidHygieneTests --filter AutoOffEvaluatorTests` — Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/AgrypnosCore/Session/WatchEngine.swift Tests/AgrypnosCoreTests/LastWatchEndTests.swift
git commit -m "$(cat <<'EOF'
Record the last watch end when Core actually disengages.

EOF
)"
```

---

### Task 4: Watch section layout

**Files:** Modify `PopoverSection.swift`, `PopoverStackLayout.swift`, `PopoverSectionTests.swift`, and `PopoverSettingsChromeTests.swift` if Watch still expects two cards.

**Interfaces:**
- Consumes: `PopoverCopyLayout.lastWatchEndHeightPoints`.
- Produces: `PopoverCard.lastWatchEnd`. `PopoverSection.watch.cards == [.watch, .duration, .lastWatchEnd]`. `PopoverStackLayout.lastWatchEnd: PopoverSlot?`. Height `inset + lastWatchEndHeightPoints + inset`. Switcher titles unchanged.

- [ ] **Step 1: Write the failing tests**

Change `testCardMapKeepsExistingControlsAndFillsNotif` Watch line to `XCTAssertEqual(PopoverSection.watch.cards, [.watch, .duration, .lastWatchEnd])`.

Rename `testWatchSectionShowsArmAndDurationOnly` → `testWatchSectionShowsArmDurationAndLastEnd`:

```swift
    func testWatchSectionShowsArmDurationAndLastEnd() {
        let layout = PopoverStackLayout.make(section: .watch)
        XCTAssertEqual(layout.stackedCards.map(\.y), compactYs(layout.watch, layout.duration, layout.lastWatchEnd))
        XCTAssertEqual(layout.lastWatchEnd?.y, layout.duration!.maxY + PopoverStackLayout.cardGap)
        XCTAssertEqual(
            layout.lastWatchEnd?.height,
            PopoverStackLayout.inset + PopoverCopyLayout.lastWatchEndHeightPoints + PopoverStackLayout.inset
        )
        XCTAssertNil(layout.hygiene)
        XCTAssertEqual(layout.contentHeight, layout.lastWatchEnd!.maxY + PopoverStackLayout.pad)
        XCTAssertFalse(layout.needsScroll)
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter PopoverSectionTests` — Expected: FAIL (`lastWatchEnd` missing).

- [ ] **Step 3: Write minimal implementation**

`PopoverCard` add `case lastWatchEnd`. Watch cards `[.watch, .duration, .lastWatchEnd]`.

`PopoverStackLayout` add `public let lastWatchEnd: PopoverSlot?`. In `slot` and `height(for:)`: `.lastWatchEnd` → slot / `inset + PopoverCopyLayout.lastWatchEndHeightPoints + inset`. `make` passes `lastWatchEnd: placed[.lastWatchEnd]`.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter PopoverSectionTests --filter PopoverStackLayoutTests` — Expected: PASS. If Watch still assumed two cards, update those assertions only.

- [ ] **Step 5: Commit**

```bash
git add Sources/AgrypnosCore/Copy/PopoverSection.swift Sources/AgrypnosCore/Copy/PopoverStackLayout.swift Tests/AgrypnosCoreTests/PopoverSectionTests.swift Tests/AgrypnosCoreTests/PopoverSettingsChromeTests.swift
git commit -m "$(cat <<'EOF'
Add a last-end card to the Watch popover section.

EOF
)"
```

---

### Task 5: Popover display and disk save

**Files:** Modify `WatchRuntime.swift`, `PopoverController.swift`, `PopoverController+Canvas.swift`, `PopoverController+Cards.swift`, `PopoverController+Sections.swift`.

**Interfaces:**
- Consumes: `AgrypnosCopy.lastWatchEndCaption(event:now:)`, `layout.lastWatchEnd`, `preferences.lastWatchEnd`.
- Produces: Always-visible Watch card. `store.save(engine.preferences)` after `setEngaged(false)` apply, after `finishTickCommands` when commands contained `.disengage` (success or rollback), and after `prepareForTermination` if it called `userSetEngaged(false)`.

- [ ] **Step 1: Write the failing Core gate**

Run: `swift test --filter LastWatchEndTests --filter PopoverSectionTests` — Expected: PASS (layout/copy already exist; AppKit has no XCTest).

- [ ] **Step 2: Confirm Mac files lack the card**

`lastWatchEndCard` / `lastWatchEndLabel` are absent. That is the fail-before-wire check.

- [ ] **Step 3: Write minimal implementation**

`PopoverController.swift`: `var lastWatchEndCard: CardView!`, `var lastWatchEndLabel: NSTextField!`. In `refresh()` after the Keep-the-watch caption:

```swift
        lastWatchEndLabel?.stringValue = AgrypnosCopy.lastWatchEndCaption(
            event: runtime.preferences.lastWatchEnd, now: Date()
        )
```

`PopoverController+Cards.swift`:

```swift
    func addLastWatchEndCard(_ card: CardView, ci: CGFloat, cw: CGFloat) {
        lastWatchEndLabel = LabelFactory.wrapping(
            "", font: .systemFont(ofSize: 12), color: .secondaryLabelColor,
            lines: PopoverCopyLayout.lastWatchEndMaxLines
        )
        lastWatchEndLabel.frame = NSRect(
            x: ci, y: CGFloat(PopoverStackLayout.inset), width: cw,
            height: CGFloat(PopoverCopyLayout.lastWatchEndHeightPoints)
        )
        lastWatchEndLabel.preferredMaxLayoutWidth = cw
        lastWatchEndLabel.setAccessibilityLabel("Last watch")
        card.addSubview(lastWatchEndLabel)
    }
```

`PopoverController+Canvas.swift` after `addDurationCard(...)`:

```swift
        lastWatchEndCard = PopoverForm.card(in: document, slot: layout.lastWatchEnd!, pad: pad, width: contentW)
        addLastWatchEndCard(lastWatchEndCard, ci: ci, cw: cw)
```

`PopoverController+Sections.swift` after duration apply:

```swift
        PopoverForm.apply(lastWatchEndCard, slot: layout.lastWatchEnd, pad: pad, width: contentW)
```

`WatchRuntime.setEngaged` false path after `restoreHygiene()`: `store.save(engine.preferences)`.

End of `finishTickCommands`:

```swift
        apply(applyCommands)
        if commands.contains(where: { if case .disengage = $0 { return true }; return false }) {
            store.save(engine.preferences)
        }
```

`prepareForTermination` when it applies `userSetEngaged(false)`:

```swift
        if engine.engaged {
            apply(engine.userSetEngaged(false, now: Date(), lidClosed: LidStateReader.isClosed()))
            store.save(engine.preferences)
        }
```

Do not save every 5s poll. Do not add a tab or window.

- [ ] **Step 4: Run tests, file-size check, Mac build**

Run: `swift test` then `bash Scripts/check-file-sizes.sh` — Expected: PASS, every tracked file ≤600 lines (`DurationHotkeyCopyTests.swift` and this plan included).

On a Mac: `bash Scripts/build-macos.sh` — Expected: `Built dist/Agrypnos.app`. Then: off → last-end line → relaunch → re-arm (line stays) → end again (replaces).

- [ ] **Step 5: Commit**

```bash
git add Apps/Agrypnos/Sources/WatchRuntime.swift Apps/Agrypnos/Sources/MenuBar/PopoverController.swift Apps/Agrypnos/Sources/MenuBar/PopoverController+Canvas.swift Apps/Agrypnos/Sources/MenuBar/PopoverController+Cards.swift Apps/Agrypnos/Sources/MenuBar/PopoverController+Sections.swift
git commit -m "$(cat <<'EOF'
Show the last watch end in Watch and save it after disarm.

EOF
)"
```
