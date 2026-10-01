# One-button OpenCode forwarding verification

Date: 2026-10-01. Branch: `codex/agent-question-relay`. Host: macOS, OpenCode **1.18.32**.

## Delivered behavior

After setting up their own inbound bot and answering user ID, the user selects OpenCode in Agents and clicks **Enable OpenCode forwarding** in Notif. Setup installs `configRoot/agrypnos-opencode.js`, registers its file URL in global `tui.json`, and enables forwarding. Restart OpenCode once to load the terminal plugin, then use normal interactive chats across projects without entering a server address, directory, port or password.

Installation shows waiting; only an authenticated 1.18.32 terminal increments the connected count. Disable leaves an inactive plugin. Remove deletes its registration and unchanged receipt-owned file. Bot secrets and manual HTTP settings are retained. Edited/foreign files, symlinks and unsupported `tui.json` content fail visibly. `tui.jsonc` stays byte-for-byte unchanged. The app and terminal must use the same global config root; a shell-only custom XDG root is not discoverable from an unrelated app process.

The plugin receives no bot credentials. The bridge uses same-UID Unix sockets, a random token and fresh lifecycle generation; its private directories are 0700 and files/socket 0600. There is no polling heartbeat. Native question text is sent only through the existing opted-in bot relay. A compromised same-user process remains outside this local token boundary.

## Automated evidence

- Installer and legacy migration: idempotent install, preserved other settings/JSONC, modified-file and symlink refusal, each injected write failure rolling back owned artifacts, private modes, removal and default-off migration.
- IPC: fragmented/coalesced Unicode frames, strict schemas/UTF-8/size bounds, actual temporary sockets, wrong credentials, duplicate hello, incomplete-handshake timeout, stopped-send failure and preserved existing file. Same-UID enforcement is implemented with Darwin `getpeereid`; cross-user live execution was not attempted.
- Source/plugin: native identity collisions across instances, ordered label mapping, local winner, resolution before acknowledgment, lost/spoofed acknowledgment, no duplicate native submission, unchanged reconnect deadline, unknown snapshot replay remaining local, disabled/offline behavior, disposal, return-local, ownership/label rejection and oversized frames.
- Runtime/layout: prerequisites, no arming/power commands during enable, real waiting state, listener/token revocation, install cancellation/double click, fresh sleep generation, safe removal, long config roots with short private sockets, collapsed manual form and active document sizing. Existing HTTP, bot/coordinator and timeout tests are retained.
- **Production native smoke passed:** `OpenCodePluginNativeTests.testProductionPluginRepliesThroughRealSocketToOriginalOpenCodeChat` runs actual OpenCode 1.18.32 ordinary TUI startup against a deterministic local model fixture. The production JS helper and actual Swift codec/socket/source submit B through the public native SDK. Its acknowledgment is accepted, the original session continues with a unique B marker exactly once, and disposal runs. The wrapper supplies an isolated manifest path; no global user config or bot is used. It does not simulate the native question registry, SDK, events or conversation. This is automated native evidence, separate from a human bot/Mac test.
- Task 1 independently proved two simultaneous native processes/projects, a supported native local winner and local prompt availability with absent IPC. The local-winner probe used the supported native API, not a physical keyboard click.

Commands:

```sh
swift test --disable-sandbox
node --test Tests/OpenCodePlugin/question-plugin.test.mjs
xcodebuild -project Apps/Agrypnos/Agrypnos.xcodeproj -scheme Agrypnos -configuration Debug -derivedDataPath /private/tmp/agrypnos-one-button-debug CODE_SIGN_IDENTITY=- build
xcodebuild -project Apps/Agrypnos/Agrypnos.xcodeproj -scheme Agrypnos -configuration Release -derivedDataPath /private/tmp/agrypnos-one-button-release CODE_SIGN_IDENTITY=- build
codesign --verify --deep --strict /private/tmp/agrypnos-one-button-debug/Build/Products/Debug/Agrypnos.app
codesign --verify --deep --strict /private/tmp/agrypnos-one-button-release/Build/Products/Release/Agrypnos.app
```

Swift module caches were redirected to private temporary paths. Socket/native tests require permission for temporary local sockets. Bundle resources were compared byte-for-byte with source. Final automated verification: **766 Swift tests, 0 failures; 11 JavaScript tests, 0 failures**. Debug and Release builds succeeded; both exact bundles passed signature verification and resource byte comparison. Relevant tracked/new files are at most 600 lines and `git diff --check` passed. Feature commit: `33c2006`, installer `4d8eb02`, IPC `bc1c778`; native feasibility `5a26ef7`. Build paths are the commands above; fresh review disposition follows below.

## Live evidence remains separate

| Check | Result |
|---|---|
| Prior original-chat HTTP/Telegram round trip | Human-confirmed in the handoff; preserved, not plugin proof |
| New one-button install in the user's global config | Not tested; no global user config changed |
| New production plugin → real Telegram bot → original chat | Not tested |
| New production plugin → real Discord bot → original chat | Not tested |
| Two human chats/processes with physical local answer and competing bots | Not tested; automated native/source characterization only |
| App/provider restart, lock, sleep/wake and 600-second policy on the user's Mac | Not tested for this plugin; automated lifecycle/timeout tests only |
| Notif optical, Reduce Motion, confirmed-lid Power A/B and safety | Not tested for this plugin; existing proof stays separately scoped |
| Forwarding off/on with matched workload/display/bots, energy or watts | Not measured; no energy claim |
| Headless or desktop OpenCode; other provider question forwarding | Unverified/unavailable; full-provider release remains gated |

The built app is concrete and reviewable. Live validation requires the user's existing bot and a one-time global installation; implementation authorization has not been treated as permission to send real bot messages or change those live files.

## Final review and fix pass

A fresh reviewer examined the whole branch (`e615e00..47b1094`) and reported six Important findings, no Critical. All six entered one fix pass; each reproducer failed before its implementation fix, then passed. The 42 affected Swift tests and all 11 plugin tests passed; the full Swift suite passed 766/766, including the real native production smoke. No second review was performed.

| Finding | Corrected behavior / regression |
|---|---|
| Startup snapshot predates a fresh question | Native events during the list operation amend its result; a newly observed question remains answerable without renewing unknown baseline deadlines. `startup snapshot preserves newer question` |
| Disconnected instances exhaust 32 records | Expired disconnected payloads no longer consume new capacity; bounded seen identities still prevent replay. `testExpiredDisconnectedInstancesDoNotConsumeNewQuestionCapacity` |
| Concurrent unrelated config save lost | Changed bytes abort installation before replacement; rollback removes only unchanged artifacts from this invocation and preserves the concurrent save. `testConcurrentConfigSaveIsKeptAndInstallationRollsBack` |
| Manual fallback disables plugin removal | Removal availability follows installed artifacts independently of the selected source. `testInstalledIntegrationCanBeRemovedWhileManualSourceIsSelected` |
| Later Discord page cannot render | Every page/state is preflighted before any destination is offered; subsequent edit rendering failure explicitly ends locally. `testUnrenderableLaterDiscordPanelStaysLocalBeforeOfferingControls` |
| Socket floods main-actor tasks | Per peer: one ordered callback outstanding, at most 64 messages/256 KiB retained; overload closes the peer. Its connection slot stays occupied until disconnect acknowledgment, bounding reconnect churn too. `testFloodWhileMainActorIsBusyClosesWithBoundedOrderedDeliveries` |

Configuration checks detect concurrent saves observed before replacement; they do not establish mutual exclusion with an unrelated editor that does not share a file lock. Real bot and Mac acceptance categories above remain unperformed.

## Execution decisions (chronological)

- Continue in the existing codex/agent-question-relay checkout — the handoff retains this branch and inline work, and no new branch/worktree was chosen — cost if wrong: probe/evidence commits need moving to another branch; no production work before feasibility PASS.
- Stop Tasks 2–6 on the missing public reply/list contract — the plan explicitly gates product work on native PASS; substituting private access or a new listener would change the design — cost if wrong: a supported alternative may have been overlooked and must be proved before resuming.
- Record the failed gate without task-done or a fabricated green native test — the script's completion contract requires passing evidence, which this run does not have — cost if wrong: ledger automation will not mark the probe task complete; the tracked report preserves the conditional-stop outcome.
- Use the existing Scripts/ directory for the probe rather than the plan's lowercase scripts/ — macOS resolves both to one directory, but Git staging uses the existing capitalized spelling — cost if wrong: plan examples need their path capitalization corrected on case-sensitive systems. Probe staged in a follow-up commit after noticing it was absent from the first commit.
- Uphold non-execution of Tasks 2–6 set aside by the reviewer — Task 1 PASS is their explicit prerequisite — cost if wrong: implementation waits for proof of an overlooked public transport.
- Leave historic HTTP code and new live bot/Mac/energy acceptance outside this probe review — no product files changed and evidence categories remain separate — cost if wrong: historic defects or new live integration failures remain unassessed by this review.
- Install the TUI-only module at configRoot/agrypnos-opencode.js and register in tui.json, outside the server-scanned plugins directory — prevents the server loader interpreting a TUI module as a server plugin — cost if wrong: revise installed path. Plain JSON global config is patched; tui.jsonc is left byte-for-byte intact; unsupported tui.json fails visibly.
- Use a unique socket filename per generation and refuse all existing socket paths — avoids unlinking a live listener or foreign symlink; stale files are inert in the private directory — cost if wrong: abandoned sockets may need manual cleanup.
- Replace the stale server-hook interface with the proved default {id,tui} entry and public api.event/onDispose/SDK v2 contracts — Task 1 PASS is authoritative — cost if wrong: plugin stops loading and remains local.
- Commit the source/resource and runtime/UI together after their separate RED→GREEN checks — Xcode membership and shared Swift test compilation otherwise name not-yet-existing files — cost if wrong: less granular task commit history.
- Keep real bot delivery, physical local-answer races, global installation, Mac optical/sleep and energy proof unclaimed — isolated native automation is not the user's live environment — cost if wrong: live integration defects remain for the acceptance run.
- Keep Claude/Cursor/Codex question sources unavailable and full-provider release gated — this milestone authorizes OpenCode 1.18.32 only — cost if wrong: broader provider coverage remains unavailable.
- Keep compromised same-user credential theft outside the local-token boundary — the plugin intentionally runs as the same user and has no bot secrets — cost if wrong: a malicious same-user process could impersonate a local peer.
- Keep shell-only custom XDG discovery as a documented limitation — the GUI has no supported way to infer an unrelated shell environment — cost if wrong: affected users need matching app environment or the manual connection.
- Keep the branch local and launch its verified Release build — the user's current request is to try the app, not merge or publish — cost if wrong: commits remain unpublished pending an integration decision.

## Deferred minors

- Probe CLI usage prints lowercase scripts/ instead of tracked Scripts/; incorrect on case-sensitive filesystems.
