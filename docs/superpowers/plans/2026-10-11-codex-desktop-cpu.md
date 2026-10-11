# Codex desktop CPU idle fix implementation plan

> Use superpowers:executing-plans. Implement inline and request one final independent review.

**Goal:** Codex desktop UI CPU must not prevent an otherwise idle Agents watch from ending.
**Architecture:** Keep desktop process recognition for fresh transcript detection; exclude desktop UI processes from CPU-only busy evidence in the shared classifier. Preserve real CLI, bundled CLI, and Node wrapper CPU behavior.
**Spec:** The approved correction in this conversation, plus the Agrypnos project bar: selected tools only, 45-second freshness, user settle grace, genuine local activity, and existing lid-gated sleep.

## Global Constraints
- No panel, sleep, network, notification, or saved preference changes.
- Keep the patch small; no dependencies or new runtime subsystem.
- Preserve Cursor nested subagent writes and CLI CPU evidence.
- Do not claim the historical incident is conclusively attributed without its missing CPU/decision logs.

## Review Focus
- Real CLI bundled inside ChatGPT/Codex app bundles remains CPU eligible.
- Full desktop executable paths include spaces and actual process arguments.
- CLI arguments naming a desktop app do not accidentally suppress legitimate CPU evidence.
- Desktop fresh transcript writes still count.
- Idle after a final Cursor subagent write reaches disengage and sleep commands with either panel mode.

### Task 1: Exclude Codex desktop CPU from idle settlement
**Files:** Sources/AgrypnosCore/Agent/AgentKindClassifier.swift; Tests/AgrypnosCoreTests/CodexDesktopBusyTests.swift
**Interfaces:** Consumes existing classifier, heuristic engine, and WatchEngine; produces no new public API.
- [ ] Write regression tests for desktop CPU-only idle, fresh transcript preservation, real bundled CLI CPU, CLI arguments naming desktop helpers, and Cursor subagent settlement under both panel modes.
- [ ] Run the focused test class before implementation. Expected: desktop CPU-only/settlement assertions FAIL.
- [ ] Apply the smallest shared CPU-eligibility guard.
- [ ] Run focused tests and the full Swift suite. Expected: all tests PASS.
- [ ] Build the macOS app without launching or replacing the current app. Expected: build succeeds.
- [ ] Commit the fix and tests; request independent review of this branch only; address material findings with failing tests first.
