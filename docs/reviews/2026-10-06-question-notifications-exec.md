# Question notifications execution

Branch: `codex-question-sup`. Did not switch, push, or merge. Did not execute `docs/superpowers/plans/2026-10-06-codex-question-relay.md`. Did not spawn Codex app-server, proxy, or exec. Did not edit `~/.codex/hooks.json` or `~/.claude/settings.json`. Tests used temp files.

## Status

DONE

## Tasks completed

1. Setup instructions is the first Notif card.
2. Question notifications disclosure under Telegram inbound, BETA in system orange. Agents busy list has no forwarding entry.
3. Info buttons open the existing read-only Bot setup window on tool tabs.
4. Codex alert sentence + `hooks.json` merge (keep `UserPromptSubmit` / `Stop`).
5. One-click Enable installs the hook, listens on a private socket, posts the sentence without idle opt-in, never arms Keep the watch.
6. README / SECURITY match the disclosure.

## Commits

| Task | Hash | Message |
| --- | --- | --- |
| 1 | `f1fcc7f1f1ae003a318848eed876a7fe549779fd` | Put setup instructions at the top of Notif. |
| 2 | `878b271d57fee21df347f57c5c35a40c487a5b20` | Show question notifications under Telegram inbound. |
| 3 | `6d3ce1fd89661740ff847693fb2a5d90cbac060c` | Open per-tool setup notes from the question cards. |
| 4 | `a82c182be4139c38d8075e426bc5841e38b929c9` | Add a Codex waiting alert and a hooks file merge. |
| 5 | `6d0f1531c39b9d7bf23999e46c5fa93ff4f572fc` | Install a one-click Codex waiting alert. |
| 6 | `706625004bd64190ce3bddb4d7dfaf7af7723ca1` | Document question notifications and the Codex waiting alert. |

## Tests

Filter syntax `swift test --filter ClassA --filter ClassB` works here (OR). Recorded commands:

- `swift test --filter CodexAlertHookTests` — 5 passed (Task 4).
- `swift test --filter AgrypnosCoreTests` — **680 passed, 0 failures** (Core package, Task 4).
- `swift test --filter CodexAlertHookProcessTests` — 5 passed (Task 5, missing-socket + temp `hooks.json`).
- `swift test --filter CodexAlertHookTests --filter CodexAlertHookProcessTests --filter ClaudeHookRuntimeTests --filter ClaudeHookSettingsMergeTests` — **19 passed, 0 failures**.

Unfiltered `swift test` after Task 4: **794 tests, 6 failures**, all from `OpenCodePluginNativeTests.testProductionPluginRepliesThroughRealSocketToOriginalOpenCodeChat` (65s live-socket timeout). Unrelated to this plan. Not treated as a Task 4 Core failure.

Live Codex `/hooks` in ChatGPT.app and Claude forwarding Mac optical: still unproven.

## Skipped

- Closed app-server answer plan.
- Push, merge, and `finishing-a-development-branch` remote steps (user override).
- Writing the user's `~/.codex/hooks.json`.
- A Cursor hook.
- Second alert switches on OpenCode / Claude cards.

Task 5 also committed `WatchRuntime+OpenCodeQuestions.swift` (start/stop the listener on the existing sync path) and three button ivars on `PopoverController.swift`. Enable/disable/post/socket logic stays in the new files. `WatchRuntime.swift` got no new logic.

## File line counts

- `Apps/Agrypnos/Sources/WatchRuntime.swift`: **513**
- `Apps/Agrypnos/Sources/MenuBar/PopoverController.swift`: **512**
