# One-button OpenCode setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After connecting their own bot once, the user clicks **Enable OpenCode forwarding**, restarts OpenCode if needed, and answers native structured questions in their original local conversations across projects without entering a server address, directory, port, or password.

**Architecture:** First prove that an external global plugin in OpenCode **1.18.32** can observe and answer the original native question through supported public interfaces during ordinary startup. If that gate passes, install one bundled JavaScript plugin and connect it to Agrypnos through authenticated Unix-domain IPC; reuse the existing question coordinator, bot controls, and watch policy. Keep the working explicit HTTP integration as a mutually exclusive fallback until the replacement is live-proven; a failed feasibility gate stops this plan before product implementation.

**Tech Stack:** macOS **14+**, Swift tools **5.9**, Foundation/Darwin/Dispatch, AppKit, OpenCode's existing JavaScript runtime and standard `node:` modules, XCTest and a standard-library JavaScript test runner. No new third-party dependency, daemon, or separately installed runtime.

**Spec:** [One-button handoff](../../reviews/2026-10-01-opencode-one-button-handoff.md), [native-question design](../specs/2026-09-29-native-agent-questions-design.md), and [OpenCode milestone](2026-10-01-opencode-relay-milestone.md). This plan proposes the specific replacement for the design's explicit OpenCode endpoint contract; all other relay contracts remain authoritative. Human review is required before execution.

## Global Constraints

- This request authorizes writing this plan only. Do not implement, install into global OpenCode configuration, clean up code, create a branch, push, merge, or release while planning.
- Continue from `codex/agent-question-relay`; planning HEAD is `5b50efd177985143a5e0c668a0e28020c931a23d`. Recheck Git state before execution. The handoff preserves the human's Grok-rule waiver for this task.
- Only OpenCode **1.18.32** may be enabled in this test build. Claude/Cursor/Codex remain unavailable; the full four-provider release gate is unchanged.
- Forwarding defaults **OFF**, never arms the watch, and requires selected OpenCode plus an enabled, complete inbound bot destination with an explicitly authorized answering-user ID. Outbound idle notifications remain independent.
- Preserve **600 seconds** from first Agrypnos observation, shortened by a source deadline; use monotonic time. Replay, reconnect, bot clicks, and newer questions never renew that window.
- Maximum **4 questions**, **20 options per question**, **32 pending batches**, **256 KiB** provider/IPC frame; each full question panel fits **1,800 UTF-16 code units**. Free text and permission approvals stay local.
- Preserve destination-specific drafts, complete review, **Send answers**, **Answer on Mac**, once-only native submission, and **Delivery unconfirmed — check the agent app** after an ambiguous result. Never retry a possibly submitted answer.
- Preserve manual/safety overrides, existing busy/unknown handling, **5-second** deferred-timeout probe cadence, **3-second** notice budget, original duration choice, and confirmed-lid sleep gates. Screen lock is not sleep.
- User-owned bots only. Bot credentials stay in Agrypnos's existing mode-**0600** secrets file. The plugin receives only local bridge credentials; no question content/history/credential logging.
- IPC parent directory mode **0700**, socket and bridge credential file **0600**, same-UID peers, no replacement or traversal of foreign/symlink paths. No TCP bridge, port scanning, replacement server, private provider imports, protected SDK fields, transcript edits, or UI automation.
- Retry a broken active IPC connection with **1, 2, 4, 8, 16, 30 seconds**, then 30; reset after a healthy connection. No question polling loop, heartbeat, or fake activity.
- No file over **600 lines**; prefer approximately **250**. Keep WatchRuntime as lifecycle wiring. No provider/plugin framework or registry rewrite.
- Menu-bar only: **Watch · Power · Agents · Notif · General**. Existing read-only Bot setup guide is allowed; no settings window. Preserve **0.25s ease-in-out** resizing and Reduce Motion, with no ghost paint or empty bottom.
- No new sudoers grant, telemetry, shared service, Discord Interactions Endpoint URL, or wattage claim. Existing **45s** session freshness and **2m–15m**, default **2m**, idle wait are unchanged.
- Automated checks, the previously human-confirmed HTTP/Telegram flow, new plugin/bot round trips, Mac optical checks, and energy observations are separate evidence categories.

## Review Focus

1. A plugin sees a question but lacks a supported reply/list/version interface: the native feasibility gate fails, and the working HTTP setup remains usable (Task 1).
2. Existing plugins, custom config roots, symlinks, or an interrupted installation: setup preserves unrelated files and settings, fails visibly, and never enables a half-installed bridge (Task 2).
3. Multiple projects/processes with colliding request IDs or malformed/unauthorized IPC: only the authenticated owning connection receives a reply; bounded input cannot cross-route or exhaust the app (Tasks 3–4).
4. Local resolution wins, or the answer acknowledgment disappears: controls become harmless and native submission occurs at most once, with no false acceptance or automatic retry (Task 4).
5. App/provider restart, sleep, disable, or a replayed event: old controls stay invalid, unknown-age questions remain local, and known deadlines never extend (Tasks 4–5).

---

## Decisions and current evidence

The user confirmed the original OpenCode → Agrypnos → Telegram → original-question flow. That proves the current explicit HTTP connection's tested flow, not this plugin candidate. The current source already supports sessions on its configured server/directory; one explicit connection is its setup limitation.

Choose a **global plugin + narrow authenticated IPC** if the native gate passes. It can retain the supplied project context and original request ownership without asking the user to manage individual servers. Current documentation describes automatic global plugin loading and event hooks; the pinned loader accepts `.js` and `.ts` files. See [plugin documentation](https://opencode.ai/docs/plugins/) and [1.18.32 plugin discovery](https://github.com/anomalyco/opencode/blob/v1.18.32/packages/opencode/src/config/plugin.ts).

The pinned implementation supplies a client with an in-process fetch fallback when no server URL is present. This establishes a candidate transport, not a public question reply contract. The pinned legacy SDK has no generated question method and its underlying client is protected. Inspect and test supported alternatives before selecting one. See [plugin implementation](https://github.com/anomalyco/opencode/blob/v1.18.32/packages/opencode/src/plugin/index.ts), [plugin interface](https://github.com/anomalyco/opencode/blob/v1.18.32/packages/plugin/src/index.ts), and [legacy SDK](https://github.com/anomalyco/opencode/blob/v1.18.32/packages/sdk/js/src/gen/sdk.gen.ts).

Keep **explicit HTTP** as the fallback: already working, but does not meet the one-button experience. Do not add automatic HTTP discovery here: authentication, endpoint ownership, and startup exposure would require a different reviewed design. If the native gate fails, record the exact missing capability and stop; do not quietly ship discovery or a wrapper that launches a replacement session.

## File map and boundaries

Paths below are repository-relative. Runtime installation paths are distinct and are written only during later authorized setup.

| File | Responsibility |
| --- | --- |
| `scripts/probes/opencode-plugin-question.js` (new) | Disposable native feasibility probe; never installed by the shipping app. |
| `docs/reviews/2026-10-01-opencode-plugin-feasibility.md` (new) | Exact tested public interfaces, loading/config paths, acknowledgment semantics, sanitized live evidence, pass/fail decision. |
| `Sources/AgrypnosCore/Questions/OpenCodeBridgeMessage.swift` (new) | Bounded typed IPC frames and incremental framing; no sockets or bot credentials. |
| `Apps/Agrypnos/Resources/agrypnos-opencode.js` (new) | One exported OpenCode plugin; native request ownership, IPC client, public reply/list calls proved by Task 1. |
| `Apps/Agrypnos/Sources/Questions/OpenCodePluginInstaller.swift` (new) | Safe install/remove of only Agrypnos-owned plugin and bridge metadata. |
| `Apps/Agrypnos/Sources/Questions/OpenCodeBridgeSocket.swift` (new) | Same-UID authenticated Unix listener, bounded reads/writes, socket lifecycle. |
| `Apps/Agrypnos/Sources/Questions/OpenCodePluginQuestionSource.swift` (new) | Per-instance native records, reconciliation and request-scoped relay closures. |
| `Sources/AgrypnosCore/Session/UserPreferences.swift` (modify) | One backward-compatible `openCodePluginEnabled: Bool = false`; never store a token in preferences. |
| `Apps/Agrypnos/Sources/WatchRuntime.swift`, `Questions/WatchRuntime+OpenCodeQuestions.swift`, `Questions/WatchRuntime+Questions.swift` (modify) | Select exactly one native source; bind installer/bridge to existing lifecycle and policy. |
| `Apps/Agrypnos/Sources/Notif/WatchRuntime+TelegramInbound.swift` (modify) | Existing `noteMacWillSleep()` / `noteMacDidWake()` source suspension and wake generation. |
| `Sources/AgrypnosCore/Copy/QuestionSetupChrome.swift`, `Copy/BotGuideCopy.swift`, `Copy/PopoverStackLayout.swift` (modify) | Setup copy, small plugin card, optional retained manual card sizing. |
| `Apps/Agrypnos/Sources/MenuBar/PopoverController.swift`, `PopoverController+Questions.swift`, `PopoverController+Cards.swift`, `PopoverController+Sections.swift` (modify) | One-button setup, genuine status, disable/remove, manual fallback disclosure. |
| `Apps/Agrypnos/Agrypnos.xcodeproj/project.pbxproj`, `Package.swift` (modify) | Register native sources and bundle the plugin; exclude the resource from SwiftPM source discovery if needed. |
| `README.md`, `SECURITY.md` (modify) | Setup/privacy/rollback instructions tied to the delivered behavior. |

Reuse `OpenCodeQuestionPayload.decode(_:instanceID:receivedUptime:)`, `identity(_:instanceID:)`, and `reply(original:answer:instanceID:)`. Do not change its HTTP event-envelope contract to accommodate IPC. Reuse `QuestionRelayCoordinator.receive(_:submit:returnLocal:)` and `cancel(key:)`; neither bot knows how the native connection is implemented.

Keep `OpenCodeQuestionSource.swift`, existing settings/secrets codecs, and their tests. The separately authorized [branch cleanup](../../reviews/2026-10-01-question-relay-cleanup.md) shelved the unused Claude codec/tests; they are recoverable from `499dcba` and need not be recreated for OpenCode. Further cleanup is outside this feature plan. New test files are specified with their owning task below.

## Local contract, conditional on Task 1 passing

- Install a self-contained `.js` file at the **proved** global plugin root as `plugins/agrypnos-opencode.js`, default `~/.config/opencode/plugins/agrypnos-opencode.js`. Respect a supported `XDG_CONFIG_HOME` root. Do not edit `opencode.json/jsonc`, other plugins, shell files, or project configuration. If the app cannot establish a custom root shared with ordinary OpenCode, report it rather than scatter copies.
- Use `~/Library/Application Support/Agrypnos/opencode-bridge/` for private `bridge.json` and an install receipt containing only the installed path and SHA-256. `bridge.json` holds protocol `1`, active generation UUID, socket path, and a cryptographically random 32-byte token encoded as hex; no bot secrets or content. A disabled manifest contains no token.
- Use a short private socket path under the user's Darwin temporary directory in an Agrypnos-owned **0700** child. Validate the `sockaddr_un.sun_path` byte limit before binding; a long Application Support path must not cause silent failure. Never take over a live/foreign socket or unlink a symlink.
- Frames are newline-delimited UTF-8 JSON, maximum **262144 bytes including newline**. Embedded content newlines must be JSON-escaped. Reject invalid UTF-8, unknown message types, trailing data, overlong unterminated frames, and unauthorized handshakes before question allocation. Bound clients to **32**, incomplete-handshake time to **2 seconds**, and each outbound queue to **256 KiB**; close a stalled/full connection.
- Plugin → app: `hello` (protocol, token, instance UUID, generation, proved host version, directory, optional source project label); `asked` (original native properties); `resolved` (sessionID, requestID); `snapshot` (current native pending identities/properties); `result` (attempt UUID, delivery). App → plugin: `ready` (generation), `reply` (attempt UUID, sessionID, requestID, native `answers`), `local` (sessionID, requestID). Use typed payloads, not an arbitrary command dispatcher.
- Bind directory, version, and instance to an authenticated channel. Reject duplicate live instance ownership and messages for another channel/generation. The app constructs `QuestionKey(provider: .openCode, instanceID: ..., sessionID: ..., requestID: ...)`; the plugin must find the original request in its own pending map before calling the native API.
- The app assigns `receivedUptime` and deadline on a fresh event in an active generation. Never compare JS process-relative clocks with Swift uptime. Keep original app records across transient connection loss, invalidate old controls immediately, and reissue only after a supported native pending snapshot verifies unchanged content before the original deadline. Unknown snapshot items stay local.
- A new app/source generation makes pre-existing plugin questions local. App restart, sleep/wake, manual/safety reset, disable, destination changes, and clear-secrets do not resurrect those questions. Preserve known expired identities long enough for a subsequent verified native resolution to clear a deferred watch-end decision; do not treat transport loss itself as a native answer.
- Reserve an attempt before socket I/O and before native async work. A native resolved event during an in-flight reply is not proof that the remote answer won. Only the proved native acknowledgment yields `.accepted`; an explicit no-longer-pending result yields `.rejected`; lost/ambiguous outcomes yield `.unconfirmed`. `local` never calls reject/abort/reply.
- Plugin hooks do not wait for a bot answer or failed connection. When disabled, watch the private manifest directory for activation rather than poll questions. During a broken active connection use bounded reconnect; no answer retry. On disposal, close socket/watchers and clear content.

### Task 1: Prove the supported native plugin path before building it

**Files:** Create `scripts/probes/opencode-plugin-question.js` and `docs/reviews/2026-10-01-opencode-plugin-feasibility.md`. Read the pinned plugin/SDK/question routes and local installed package; do not patch OpenCode.

**Interfaces:** Consumes OpenCode 1.18.32's public `PluginInput` and `event`/`dispose` hooks. Produces a PASS/FAIL record specifying exact public call expressions, signatures, directory/auth behavior, version verification, pending listing, native acceptance/error semantics, and verified global loading path. Tasks 2–6 may execute only after PASS; their native calls must match this record.

- [ ] **Step 1: Write the probe's failing acceptance checks.** Name cases `ordinaryStartupOriginalReply`, `localAnswerWins`, `resolvedBeforeAcknowledgment`, `twoProjectsAndProcesses`, `appUnavailableLeavesLocal`, and `publicContractOnly`. Assert original instance/session/request identity, a B continuation marker exactly once, no reply after local resolution, distinct ownership for simultaneous chats, and no prompt blocking when IPC is absent. Require both reply and pending-list access without private imports, `_client`, monkey patches, or an explicitly exposed listener. Include a host-version check that cannot merely echo the plugin's compiled version.

  The probe's recorded result per case is `{ hostVersion, originalSessionID, continuedSessionID, markerCount, replyAttempts, requiresExplicitListener }`. Its check for `ordinaryStartupOriginalReply` is:

  ```javascript
  assert.equal(result.hostVersion, "1.18.32")
  assert.equal(result.continuedSessionID, result.originalSessionID)
  assert.equal(result.markerCount, 1)
  assert.equal(result.replyAttempts, 1)
  assert.equal(result.requiresExplicitListener, false)
  ```
- [ ] **Step 2: Establish the baseline failure.** Start the probe in an isolated temporary OpenCode config/home fixture on the installed 1.18.32, with normal startup and no `--hostname`/`--port`. Run the acceptance cases and record the missing reply/acknowledgment proof as FAIL. Do not touch the user's live global configuration or compete with Telegram polling. Read-only inspection alone cannot mark this gate passed.
- [ ] **Step 3: Try the smallest public native path.** Use only externally supported exports/calls. Check the actual configured runtime, `.js` discovery, `node:net` availability, default/XDG/custom-root behavior, disabled-plugin modes, directory scoping, pending listing, reliable host version, and disposal. Normal startup may have OpenCode's own listener; prove the plugin needs no user-managed listener, while documenting any actual exposure. A URL-shaped client default does not prove a listener exists.
- [ ] **Step 4: Run the same checks against ordinary existing chats.** On PASS, capture sanitized native schemas and exact public call signatures in the evidence file; verify local-cancel/answer races and the original B marker once in two projects/processes. Record observed facts separately from inference. Any absent or unsupported reply/list/version contract is FAIL: stop here, retain HTTP, and present the missing capability for a revised design.
- [ ] **Step 5: Commit the probe/evidence only.** `git add scripts/probes/opencode-plugin-question.js docs/reviews/2026-10-01-opencode-plugin-feasibility.md`; `git commit -m "docs: prove OpenCode plugin question contract"`. No product source, global install, or HTTP deletion belongs to this task.

### Task 2: Make setup a safe, reversible owned-file install

**Files:** Create `Apps/Agrypnos/Sources/Questions/OpenCodePluginInstaller.swift`, `Tests/AgrypnosMacTests/OpenCodePluginInstallerTests.swift`; modify `Sources/AgrypnosCore/Session/UserPreferences.swift`, `Tests/AgrypnosCoreTests/OpenCodeQuestionSettingsTests.swift`, and Xcode project source registration. Task 4 supplies the production plugin resource; installer tests use fixed fixture bytes.

**Interfaces:** `OpenCodePluginInstaller.init(configRoot: URL, bridgeRoot: URL, pluginData: Data)`; `install() throws -> URL`; `remove() throws -> Void`. Throw `OpenCodePluginSetupError` cases `unsafePath`, `foreignFile`, `writeFailed`, `unsupportedConfiguration`. Add `openCodePluginEnabled` to initializer/CodingKeys/decode/encode, default false. Installer does not change prefs or start forwarding.

- [ ] **Step 1: Write failing installer and migration tests.** Assertions: legacy prefs decode plugin mode false without losing `forwardAgentQuestions`; round-trip true; identical install is idempotent; default/XDG root resolved as Task 1 proved; `opencode.jsonc` and another plugin retain exact bytes; symlinked parent/target, foreign ownership, and a modified Agrypnos filename are rejected unchanged. Force failure at each write/rename boundary and assert no false installed state or unrelated removal. Removal only deletes receipt-owned unchanged bytes and preserves manual connection and bot secrets.

  Pin migration with `testMissingPluginPreferenceDefaultsOff`:

  ```swift
  let original = UserPreferences(forwardAgentQuestions: true)
  let data = try JSONEncoder().encode(original)
  var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
  object.removeValue(forKey: "openCodePluginEnabled")
  let legacy = try JSONSerialization.data(withJSONObject: object)
  let decoded = try JSONDecoder().decode(UserPreferences.self, from: legacy)
  XCTAssertFalse(decoded.openCodePluginEnabled)
  XCTAssertTrue(decoded.forwardAgentQuestions)
  ```
- [ ] **Step 2: Run red.** `swift test --filter OpenCodePluginInstallerTests` and `swift test --filter OpenCodeQuestionSettingsTests`. Expect missing installer/property compilation errors or failing new assertions; preserve baseline tests.
- [ ] **Step 3: Implement the stated installer interface.** Use Foundation plus no-follow filesystem operations for ownership checks and atomic replacement. Cryptographic receipt hash identifies exact Agrypnos-owned bytes; serialize install/remove within the app. Roll back only new owned artifacts, never an existing directory/plugin. Keep token creation out of preferences; create bridge directory 0700 and metadata/receipt 0600. Do not run npm, sudo, or OpenCode startup as part of installation.
- [ ] **Step 4: Run green.** Repeat both commands; all new and existing cases pass, including temp-root mode/ownership checks. Add source membership to Xcode in this commit; no real home-directory writes in tests.
- [ ] **Step 5: Commit.** Stage this task's files and commit `feat: add reversible OpenCode plugin setup`.

### Task 3: Add bounded authenticated local IPC

**Files:** Create `Sources/AgrypnosCore/Questions/OpenCodeBridgeMessage.swift`, `Apps/Agrypnos/Sources/Questions/OpenCodeBridgeSocket.swift`, `Tests/AgrypnosCoreTests/OpenCodeBridgeMessageTests.swift`, `Tests/AgrypnosMacTests/OpenCodeBridgeSocketTests.swift`; register native source in Xcode.

**Interfaces:** `OpenCodeBridgeFrameDecoder.append(_ bytes: Data) throws -> [OpenCodeBridgeMessage]`; `OpenCodeBridgeMessage.encodedFrame() throws -> Data`. Define `OpenCodeBridgeConnectionID: Hashable` wrapping UUID and `OpenCodeBridgeConfiguration(socketURL: URL, token: String, generation: UUID)`. `@MainActor OpenCodeBridgeSocket.init(configuration:receive:disconnected:)` takes `(OpenCodeBridgeConnectionID, OpenCodeBridgeMessage) -> Void` and `(OpenCodeBridgeConnectionID) -> Void` closures; `start() throws`, `send(_:to:) async -> Bool`, `stop()`. `send` success means only frame transport, never native acceptance.

`OpenCodeBridgeMessage` cases are `hello(protocolVersion: Int, token: String, instanceID: UUID, generation: UUID, hostVersion: String, directory: String, projectLabel: String?)`, `ready(generation: UUID)`, `asked(original: Data)`, `resolved(sessionID: String, requestID: String)`, `snapshot(originals: [Data])`, `reply(attemptID: UUID, sessionID: String, requestID: String, answers: [[String]])`, `local(sessionID: String, requestID: String)`, and `result(attemptID: UUID, delivery: QuestionDelivery)`. Encode the original `Data` as embedded native JSON properties, not Base64; allow only accepted/rejected/unconfirmed result values. Validate the complete encoded frame size before sending; an oversized snapshot or question is left local with a plain limitation, never truncated.

- [ ] **Step 1: Write failing boundary tests.** Pin all frame variants and exact protocol/limits from the local contract. Assert fragmented/coalesced frames, escaped Unicode/newlines, oversized/no-newline input, invalid UTF-8, unknown type, missing fields, malformed token, mismatched version/generation, same-UID rejection, and duplicate hello cannot allocate a question. A 33rd client is rejected; incomplete hello closes after 2 seconds; full write queue closes at 256 KiB. Test short/overlong socket paths, stale owned sockets, live foreign listeners, and symlinks without unlinking them.

  Pin the allocation boundary with `testOversizedUnterminatedFrameIsRejected`:

  ```swift
  var decoder = OpenCodeBridgeFrameDecoder()
  XCTAssertThrowsError(try decoder.append(Data(repeating: 0x20, count: 262145)))
  ```
- [ ] **Step 2: Run red.** `swift test --filter OpenCodeBridgeMessageTests`; `swift test --filter OpenCodeBridgeSocketTests`. Expect undefined types or failing boundary assertions.
- [ ] **Step 3: Implement those interfaces.** Keep codec Linux-testable. Use Darwin Unix sockets, `getpeereid`, and Dispatch I/O off the main actor; deliver validated callbacks on the main actor. Use restrictive creation permissions from the first write/bind, authenticate before native payloads, suppress SIGPIPE, cap buffers, and close descriptors/tasks on stop. Check the peer and token in both directions; app sends `ready` only after authentication. Token possession is not protection from compromised same-user processes.
- [ ] **Step 4: Run green.** Repeat both commands against real temporary Unix sockets as well as codec fixtures. Verify stop removes only the owned socket and emits each disconnect once; no token/body appears in diagnostic output.
- [ ] **Step 5: Commit.** Stage these files plus project membership; commit `feat: add authenticated OpenCode question IPC`.

### Task 4: Route plugin questions back to their original native requests

**Files:** Create `Apps/Agrypnos/Resources/agrypnos-opencode.js`, `Apps/Agrypnos/Sources/Questions/OpenCodePluginQuestionSource.swift`, `Tests/OpenCodePlugin/question-plugin.test.mjs`, `Tests/AgrypnosMacTests/OpenCodePluginQuestionSourceTests.swift`; register source/resource in Xcode and adjust `Package.swift` only if needed for resource exclusion.

**Interfaces:** Plugin exports only `AgrypnosOpenCodePlugin = async (ctx) => hooks`; `hooks.event({ event })` and `hooks.dispose()` use Task 1's proved contracts. `@MainActor OpenCodePluginQuestionSource.init(configuration: OpenCodeBridgeConfiguration, uptime: @escaping () -> TimeInterval, receive: @escaping (QuestionBatch, @escaping @MainActor (QuestionAnswer) async -> QuestionDelivery, @escaping @MainActor () async -> Void) -> Bool, resolved: @escaping (QuestionKey) -> Void)`; `start() throws`, `stop()`. It owns the socket, native records, original schemas and answer-result continuations; production gets no generic provider protocol.

- [ ] **Step 1: Write failing ownership/race tests.** Instantiate the real plugin with a fake public client using the exact Task 1 interface and a temporary Unix peer. Swift tests drive actual framed source callbacks. Assert two projects/processes sharing `sessionID/requestID` get different keys and replies; duplicate/changed events never create new deadlines; malformed/ambiguous label payload stays local; one complete answer maps to original ordered label arrays. Explicitly cover local resolution before send, resolution during send before native acknowledgment, lost acknowledgment, spoofed result/attempt UUID, wrong owner/generation, expired replies, return-local, and plugin disposal. Native reply call count must be 0 or 1, never 2.

  In `testLostAcknowledgmentNeverRetries`, the fake public client records `replyAttempts`; the source's `receive` closure captures its real submit closure. Drop the result after native application, then invoke that captured closure twice for the same valid answer:

  ```swift
  XCTAssertEqual(firstDelivery, .unconfirmed)
  XCTAssertEqual(secondDelivery, .rejected)
  XCTAssertEqual(replyAttempts, 1)
  ```
- [ ] **Step 2: Run red.** `node --test Tests/OpenCodePlugin/question-plugin.test.mjs`; `swift test --filter OpenCodePluginQuestionSourceTests`. Use the bundled Node path if `node` is absent; do not install a runtime. Tests import the resource source as an ES module and require only standard modules. Expect missing plugin/source or failing acceptance assertions.
- [ ] **Step 3: Implement the plugin and source interfaces.** Use the Task 3 frames and existing OpenCode codec/relay closures. The plugin validates directory/request ownership, records attempts before calling Task 1's public reply API, and reports only that API's proved outcome. Ignore permission events and free-text-only requests; never wrap or replace the question tool. Disconnect invalidates app controls; reconnect snapshots verify known unchanged questions against original deadlines. Events observed offline/disabled and unknown-age pending requests stay local. On a new generation, clear prior remote eligibility without resolving native questions. Keep app-known expired identity reconciliation so a real native answer can clear deferred watch ending.
- [ ] **Step 4: Run green.** Repeat both commands. Assert bounded 32-record state and queues, retries exactly 1/2/4/8/16/30, no queued answer retry, no periodic question query, no activity while disabled except manifest watch, and no synchronous hook wait for Agrypnos. Add bundle membership and verify the `.js` resource bytes are present in an app build.
- [ ] **Step 5: Commit.** Stage task files/build membership and commit `feat: forward original OpenCode plugin questions`.

### Task 5: Wire one-button setup and existing lifecycle without duplicate sources

**Files:** Modify the runtime/UI/copy/layout files in the file map, including `Apps/Agrypnos/Sources/Notif/WatchRuntime+TelegramInbound.swift`, and `Apps/Agrypnos/Sources/WatchRuntime+Kernel.swift` only if shutdown wiring needs it. Create `Tests/AgrypnosMacTests/OpenCodePluginRuntimeTests.swift`; extend `Tests/AgrypnosCoreTests/QuestionRelayLayoutTests.swift`, `BotGuideCopyTests.swift`, and `Tests/AgrypnosMacTests/OpenCodeQuestionRuntimeTests.swift`. Keep the existing HTTP fixtures intact.

**Interfaces:** `WatchRuntime.enableOpenCodeForwarding() async -> Bool`, `disableOpenCodeForwarding() -> Void`, `removeOpenCodeForwarding() async -> Bool`; retain `syncQuestionSources()`, `stopQuestionSources()`, `setForwardAgentQuestions(_:)`, and `openCodeQuestionCaption`. Add `openCodePluginSource: OpenCodePluginQuestionSource?`, with concrete install/remove/source-factory closures injected into runtime for tests. Extend `PopoverStackLayout.make(section:panelPowerMode:)` with `showManualOpenCodeConnection: Bool = false` for the explicit fallback disclosure; existing manual settings remain saved independently. Add a `pluginConnection` Notif slot for the compact plugin setup card; the existing `openCodeQuestions` slot remains the manual form.

- [ ] **Step 1: Write failing runtime/UI checks.** Ready bot + selected OpenCode + successful install sets plugin mode and forwarding true, never arms or executes a power command. Missing owner/inbound/selection or installation failure leaves preferences unchanged and shows the exact reason. Double-click installs/starts once. Plugin mode suppresses HTTP; manual mode suppresses plugin; unavailable plugin never silently falls back. Assert sleep, quit, manual/safety end, re-arm, changed destination, exclusion, disable and clear-secrets invalidate old handles before asynchronous cleanup. Restart with unknown pending question gives no bot controls; transient reconnect retains deadline 600, never 800 after reconnect at uptime 200.

  Pin card selection with `testOneButtonLayoutKeepsManualFormCollapsed`:

  ```swift
  let compact = PopoverStackLayout.make(section: .notif)
  let manual = PopoverStackLayout.make(section: .notif, showManualOpenCodeConnection: true)
  XCTAssertNotNil(compact.pluginConnection)
  XCTAssertNil(compact.openCodeQuestions)
  XCTAssertNotNil(manual.openCodeQuestions)
  XCTAssertGreaterThan(manual.contentHeight, compact.contentHeight)
  XCTAssertNil(PopoverStackLayout.make(section: .watch).pluginConnection)
  ```
- [ ] **Step 2: Run red.** `swift test --filter OpenCodePluginRuntimeTests`; `swift test --filter QuestionRelayLayoutTests`; `swift test --filter BotGuideCopyTests`. Expect missing runtime actions/layout argument or new assertion failures. Add two-instance Telegram/Discord routing tests using the existing coordinator and verify stale/unauthorized clicks never reach either native source.
- [ ] **Step 3: Implement runtime actions.** Check bot/selection prerequisites, serialize setup, install the resource, create active bridge metadata/token, start the bridge, then persist `openCodePluginEnabled = true` and `forwardAgentQuestions = true`. Roll back newly created owned installation on failure; retain prior manual config and all bot settings. Successful install means **installed, waiting for OpenCode**, not connected. Sync exactly one source. Normal global forwarding-off stops the listener and publishes inactive metadata without uninstalling; remove also deletes only receipt-owned plugin bytes. Clear-secrets removes/revokes bridge token and invalidates sockets synchronously; later enable generates a new token. Sleep pauses/revokes the active generation; wake publishes a fresh one, leaving old questions local.

  Keep source replacement synchronous until handles are invalidated. `disableOpenCodeForwarding()` turns global forwarding off but retains the installed inactive plugin and saved HTTP fields. `removeOpenCodeForwarding()` first disables forwarding, then performs owned removal; a removal failure leaves forwarding off and reports the problem. Choosing the explicit manual fallback sets plugin mode false, revokes IPC, and uses the existing saved HTTP configuration and forwarding opt-in. No source should run during a failed/half-published transition.
- [ ] **Step 4: Implement the Notif UI and guide.** Use **Enable OpenCode forwarding** as the first-time action; it performs the install and forwarding opt-in together. Show **Restart OpenCode once to load forwarding.** until an authenticated supported host connects; show a real connected instance count, never an install-derived connection claim. Provide **Disable OpenCode forwarding**, **Remove OpenCode integration**, and a collapsed **Manual server connection…** fallback that retains existing Save/Remove fields and explicitly switches to manual mode. Missing prerequisites point to the existing bot/user-ID and Agents controls; never secretly enable inbound or select a provider. Keep bot fields, full answer review, and existing forwarding policy copy. Shrink the default connection card to its actual active contents; preserve section animation/Reduce Motion and accessibility labels.
- [ ] **Step 5: Run green.** Repeat targeted commands plus `swift test --filter OpenCodeQuestionRuntimeTests`, `swift test --filter QuestionTimeoutRuntimeTests`, and `swift test --filter PopoverSectionResizeTests`. Check default Notif layout hides the manual form, disclosure height contains its controls, other sections contain neither, and short sections still hug content. Do not change default `PopoverStackLayout.make(section:)` semantics outside this card.
- [ ] **Step 6: Commit.** Stage task files and commit `feat: enable OpenCode forwarding from Notif`.

### Task 6: Verify the shipped setup and original-chat bot round trips

**Files:** Modify `README.md` and `SECURITY.md`; create `docs/reviews/2026-10-01-opencode-one-button-verification.md`. Change production code only to fix a demonstrated failure with a regression, using systematic debugging/TDD; do not delete HTTP or Claude code in this task.

**Interfaces:** Consumes the delivered button, actual bundle, original native chat, user-owned inbound bots and authorization. Produces separate automated, Telegram-live, Discord-live, Mac-optical, and energy evidence with version/commit/build identity. Full release remains gated independently.

- [ ] **Step 1: Document the delivered flow.** Bot credentials/inbound/answering-user ID once → select OpenCode → **Enable OpenCode forwarding** → restart OpenCode once if needed → native choices automatically forward. Explain install location/config limitations, question-content egress, same-user IPC boundary, disable/remove, manual fallback and local fallback when Agrypnos is unavailable. State no user-managed address/directory/port/password only after Task 1 and live setup pass. Preserve separate bot/outbound instructions and all privacy/sleep honesty.
- [ ] **Step 2: Run automated verification.** Run `swift test` and the JavaScript test command. Build Debug and Release with `xcodebuild -project Apps/Agrypnos/Agrypnos.xcodeproj -scheme Agrypnos -configuration Debug -derivedDataPath /private/tmp/agrypnos-one-button-debug CODE_SIGN_IDENTITY=- build`, then the same command with Release and `/private/tmp/agrypnos-one-button-release`. Verify both bundles contain `Contents/Resources/agrypnos-opencode.js` matching source bytes; run `codesign --verify --deep --strict` on each exact app path. Run `git diff --check` and a file-size check on tracked plus this task's new source/doc files; avoid counting pre-existing generated artifacts as tracked failures. Expected: zero test failures, both builds/signature checks exit 0, all relevant files ≤600 lines.
- [ ] **Step 3: Request fresh review notes and resolve important findings.** Review installer ownership/rollback, supported native call expressions, IPC bounds/auth, original-request races, lifecycle invalidation and HTTP exclusivity. Preserve the recorded model waiver; do not silently substitute a model if new applicable instructions change it. Every important fix gets its smallest meaningful regression; rerun only affected checks, then full checks if production changes warrant them.
- [ ] **Step 4: Perform the authorized live setup test.** Obtain the human's approval before a probe/global install or real bot test that has not already been authorized in the executing session. Build first so they approve a concrete app and file changes. With their own bot already configured, click the button once, restart ordinary OpenCode once, and use two local projects and two processes without server flags or per-chat instructions. Ask harmless A/B questions and submit B via the existing number → **Review / next** → **Send answers** flow. Each original conversation writes a unique B marker once. Repeat with Telegram and Discord; permission-only/free-text questions stay local. Never use a replacement chat as proof.
- [ ] **Step 5: Exercise live failures and Mac optical.** Check native-local answer racing a bot send, stale/unauthorized/duplicate clicks, app absent/restarted, OpenCode restarted, dropped native acknowledgment, both bots submitting, disable/remove/re-enable, offline bot/429, sleep/wake and screen lock. Verify original local question stays usable on fallback, no blind retry or renewed deadline, and a local answer clears any deferred timeout. Check the 600-second unanswered policy, manual/safety overrides, re-arm during notice delivery, lid-open/unconfirmed/confirmed sleep gates, Power A/B hygiene, and Notif sizing/Reduce Motion. Record each unperformed case as **not tested**, never passed by association.
- [ ] **Step 6: Record evidence and commit docs.** Compare the same awake workload/display/bot configuration with forwarding off/on before making any energy statement; CPU time is not watts. Keep logs sanitized and question contents out of persistent history. Commit `docs: verify one-button OpenCode setup`. A missing live category remains open; do not claim completion of the broader provider/release matrix.

## Exit criteria and preserved work

The plugin candidate is accepted only after the native gate passes and the shipped one-button path proves original-chat replies, multiple projects/processes, ownership/race safety, and a usable local fallback. Automated evidence alone can finish implementation tasks but cannot replace human/bot/Mac evidence.

If Task 1 fails, the useful deliverable is the exact failure record and unchanged working HTTP integration; Tasks 2–6 do not run. If subsequent tasks fail, leave HTTP explicitly selectable and report the missing acceptance item. The separate authorized cleanup shelved the unused Claude codec/tests. Removal of manual fields/settings/source still requires replacement proof and a separate concrete proposal; this feature plan does not authorize it.

Planning self-review: the handoff's once-only setup, feasibility uncertainty, original-conversation ownership, multi-instance scope, privacy, watch policy, fallback, cleanup restraint and staged-provider honesty each map to the tasks above. Public OpenCode calls are deliberately decided by Task 1's evidence rather than invented in this document. No implementation or probe was run while writing this plan.

**Stop after saving and reviewing this plan. Execution method, global installation, and live-test approval are later decisions.**
