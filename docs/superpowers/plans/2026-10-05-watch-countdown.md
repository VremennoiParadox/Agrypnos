# Watch Countdown Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make timed watches expire, show a live countdown, and send timer-specific notifications.

**Architecture:** Restore the existing Core deadline evaluator. Reuse the outbound hold coordinator and the single native sleep command path, with a timer-only known-open gate. Native timers schedule expiry and visible countdown refresh.

**Tech Stack:** Swift, XCTest, Foundation Timer, AppKit. No dependencies.

**Spec:** docs/superpowers/specs/2026-10-05-watch-countdown-design.md

## Global Constraints

- Timed choices are 1h, 3h, and custom minutes; countdown starts when armed.
- Lid reopening preserves the deadline; duration selection remains saved after expiry.
- Verify kernel release before sleep; timer expiry sleeps unless lid is known open.
- Stable-confirm hygiene and manual/inbound off gates stay unchanged.
- Outbound remains opt-in, user-owned destinations, bounded POST before sleep.
- Timer message: “Agrypnos: your watch timer ended.” Preserve honest Agents text.
- No new dependency, settings window, model mandate, or source file above 600 lines.

## Review Focus

- Lid opens during kernel release or POST: final gate skips sleep (TimedWatchRuntimeTests).
- Unknown lid at expiry: timer fallback sleeps, hygiene/manual gates stay conservative (TimedWatchRuntimeTests).
- Failed kernel clear: no sleep, original deadline restored (TimedWatchRuntimeTests).
- Re-arm during POST: stale completion cannot disarm or sleep new watch (TimedWatchRuntimeTests).
- Changing duration / reopening popover: deadline and countdown stay consistent (WatchCountdownTests; native build and visual inspection).

---

### Task 1: Restore timed watches end to end

**Files:**
- Modify: Sources/AgrypnosCore/Power/Safety.swift — expiry evaluation
- Modify: Sources/AgrypnosCore/Session/WatchEngine.swift, WatchTypes.swift — deadline, rollback, outbound commands
- Modify: Sources/AgrypnosCore/Copy/AgrypnosCopy.swift — countdown and expiry copy
- Modify: Sources/AgrypnosCore/Notif/TelegramStatus.swift — real remaining time
- Modify: Apps/Agrypnos/Sources/WatchRuntime.swift, WatchRuntime+Poll.swift, WatchRuntime+Kernel.swift, WatchRuntime+Lid.swift — schedule deadline and shared POST
- Modify: Apps/Agrypnos/Sources/Power/MachineSensors.swift, PowerHygieneCoordinator.swift — preserve unknown lid, final sleep gate
- Modify: Apps/Agrypnos/Sources/Notif/NotifIdlePoster.swift — reason-specific message
- Modify: Apps/Agrypnos/Sources/MenuBar/PopoverController.swift, PopoverController+Cards.swift — visible countdown
- Modify: active README, SECURITY, prd, AGENTS, bot guide/help copy
- Test: Tests/AgrypnosCoreTests/WatchCountdownTests.swift; Tests/AgrypnosMacTests/TimedWatchRuntimeTests.swift; revise tests that encode superseded policy

**Interfaces:**
- Consumes: WatchEngine.timerEnd, userSetDuration(_:now:), tick(now:safety:agents:kernelSleepDisabled:observeAgents:).
- Produces: WatchEngine.statusItemRemainingSeconds(now: Date) -> Int?; AgrypnosCopy.countdown(seconds: Int) -> String; timer-specific outbound command; optional native lid readings.

- [ ] **Step 1: Write regression tests**
Assert literal deadlines for 60/180/33 minutes; no deadline while off; expiry disarms and records timerExpired; reopening preserves deadline; changing duration resets it; Agents/infinity cancel it; rollback preserves it. Assert countdown 3600 → 1:00:00, 125 → 0:02:05, zero clamp, and live status. Native tests assert closed/unknown sleep once after release, known-open skips, open during release/POST skips, failed release retains original deadline, stale POST cannot end re-arm, and timer-specific reason reaches POST.

- [ ] **Step 2: Run tests and observe missing behavior**
Run: `swift test --filter 'WatchCountdownTests|TimedWatchRuntimeTests'`
Expected: FAIL on existing timer behavior (or missing new API; start with expiry regressions before introducing new API tests).

- [ ] **Step 3: Restore minimal Core and native timer behavior**
Use existing deadline and disengage path. Preserve unknown sensor reads, recheck before shared sleepnow. Extend existing outbound hold to expiry with reason-specific body. Add a deadline Timer in common run-loop mode, retaining the original deadline on failed release.

- [ ] **Step 4: Add countdown and active documentation**
Use `statusItemRemainingSeconds(now:)` for a monospaced countdown in How long and for status. Refresh only countdown text each second while popover is shown; release that Timer on close. Reserve its row without growing the duration card. Remove stale remembered-only copy and Grok mandate.

- [ ] **Step 5: Verify all targets**
Run: `swift test`; `bash Scripts/check-file-sizes.sh`; `bash Scripts/build-macos.sh`; `git diff --check`.
Expected: all tests pass, files ≤600 lines, native Release build succeeds, no whitespace errors. Inspect native countdown UI if possible without installing/replacing the user's running app or issuing real sleep/network commands.

- [ ] **Step 6: Commit**
Run: `git add <changed feature/tests/docs>; git commit -m "fix: expire timed watches and show a live countdown"`.
Expected: coherent committed slice on codex/watch-countdown; fresh whole-branch review before push/PR.
