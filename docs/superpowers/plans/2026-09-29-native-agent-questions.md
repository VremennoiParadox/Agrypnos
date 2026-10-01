# Native Agent Questions Implementation Plan

**Execution status, 2026-09-29:** user authorized execution/local commits, **no push**, and subsequently chose to perform live Cursor checks after coding. Shared implementation may proceed; Task 1 live evidence remains outstanding and no unknown native API may be fabricated. All four still must work before release. See [compatibility evidence](../../reviews/2026-09-29-native-question-compatibility.md) and the [contract supplement](2026-09-29-native-question-contracts.md).

**Current status, 2026-10-01:** the separately authorized [OpenCode milestone](2026-10-01-opencode-relay-milestone.md) is wired and its Telegram/original-chat flow is human-confirmed. Other providers and the full release matrix remain gated. The unused Claude codec/tests were shelved in the authorized [cleanup](../../reviews/2026-10-01-question-relay-cleanup.md); Task 5 must establish its native contract before restoring them. The [one-button plan](2026-10-01-opencode-one-button-setup.md) is written, with its plugin feasibility gate still unpassed. Original task checkboxes below are not a claim that the staged milestone is unwired.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automatically forward structured questions from existing Cursor, Claude Code, Codex and OpenCode conversations to the user's Telegram/Discord bots, return chosen answers to the original requests, and end an unanswered-question wake allowance after ten minutes without interrupting other observed work.

**Architecture:** Native provider adapters feed an in-memory question coordinator; it reuses the existing bot consumers and retains each original response path. Pure Core code owns selection validation, request lifecycle and the ten-minute policy; macOS owns IPC, networking and the existing verified wake-release/sleep path. Provider adapters require concrete native contracts; live compatibility tests may follow coding at the user’s request, but all four must pass before release. No skill or model-guidance fallback.

**Tech Stack:** Swift tools 5.9, macOS 14+, Foundation/URLSession, AppKit, Darwin Unix sockets where needed, XCTest and the existing SwiftPM/Xcode targets. No new dependency or hosted service.

**Spec:** [Native agent questions design](../specs/2026-09-29-native-agent-questions-design.md). Read it together with the [research](../../reviews/2026-09-29-agent-question-relay-research.md). The research's earlier skill-first recommendation is superseded.

## Global Constraints

- **All four providers before release**; existing desktop/local conversations must work. Another ACP/SDK/app-server conversation does not count.
- One-time opt-in; no skill, per-prompt command, injected instruction, transcript mutation, UI automation or private attachment API.
- **600 seconds** per confirmed question, measured monotonically; no reset on duplicate events/taps/reconnect/new questions. No automatic arming.
- Preserve other work: busy or unknown selected-agent evidence defers disarm; after a deferral require the existing continuous quiet grace. Another unexpired question retains its own allowance.
- Preserve **45s** freshness, **2m–15m**, default **2m**, idle preferences. Manual off, battery, thermal and LPM still win. Question waiting never fabricates busy evidence.
- Default forwarding **OFF**; same existing Telegram long poll/Discord Gateway; configured sender ID plus destination/message validation. Idle POST opt-in is independent.
- **4 questions**, **20 options/question**, **32 pending batches**, **256 KiB** input frame; **1,800 UTF-16 code units** per complete question panel. Unsupported content returns to the Mac intact.
- **64 bytes** maximum Telegram callback data; **100 characters** maximum Discord custom ID. Discord initial acknowledgment within **3 seconds**.
- No question-history store or content logging; credentials/authorized IDs in existing mode-**0600** secrets file. No Discord mentions or text markup.
- No file over **600 lines**; prefer around **250**. Menu-bar only; existing **Watch · Power · Agents · Notif · General**; **0.25s ease-in-out**, Reduce Motion respected.
- Execution is authorized, with local commits only and no push. The user will perform live Cursor verification after coding; this does not authorize a private/fabricated native API or a reduced release. No release/merge into main is included.

## Review Focus

1. A local answer or cancellation racing a phone answer must never target another request or falsely report acceptance — Tasks 1, 2, 5–8.
2. Sleep/restart/credential change during an async callback must make every old control inert, including after reconnect — Tasks 2–4, 9.
3. A ten-minute timeout with another busy agent, an incomplete probe, or another pending question must preserve the watch — Tasks 2, 9.
4. Long/Unicode text, duplicate labels, and mixed multi-select batches must not silently lose meaning or submit partial answers — Tasks 2–8.
5. Kernel release failure, offline bot delivery, or re-arm during the timeout notification must not lie about disarm, wait indefinitely, or sleep a new watch — Task 9.

---

## Execution order and feasibility boundary

The original Task 1 gate was before production. The user subsequently chose to run live Cursor verification after coding. **Shared implementation can proceed without those optical checks; all four native round trips remain a release gate.** Concrete provider response contracts are still required before an adapter is implemented or enabled. Documentation has not established supported attachment to existing Cursor/Codex desktop requests. Do not manufacture those APIs, silently advertise desktop support, ship a reduced release or reintroduce a skill.

Tasks 2–4 are the shared mechanism. Tasks 5–8 are separate provider review units. Task 9 integrates wake policy. Task 10 exposes and verifies the complete feature. Each task gets its own focused check and commit; do not commit unrelated untracked build/review artifacts.

## File map

Paths below are repository-relative. New folders contain focused files, not a provider framework.

| Responsibility | Files |
| --- | --- |
| Frozen native evidence | New `docs/reviews/2026-09-29-native-question-compatibility.md`; new `docs/superpowers/plans/2026-09-29-native-question-contracts.md` after Task 1 |
| Normalized requests, drafts and lifecycle | New `Sources/AgrypnosCore/Questions/AgentQuestion.swift`, `QuestionRegistry.swift`, `QuestionWaitPolicy.swift` |
| Shared test fixtures | New `Tests/AgrypnosCoreTests/QuestionTestSupport.swift`; provider JSON fixtures under `Tests/AgrypnosCoreTests/Fixtures/Questions/`; add test resources in `Package.swift` |
| Runtime coordinator | New `Apps/Agrypnos/Sources/Questions/QuestionRelayCoordinator.swift`, `WatchRuntime+Questions.swift` |
| Telegram controls | New `Sources/AgrypnosCore/Questions/TelegramQuestionMessage.swift`; extend `Sources/AgrypnosCore/Notif/TelegramInbound.swift`, `NotifOutboundRequest.swift`; wire `Apps/Agrypnos/Sources/Notif/WatchRuntime+TelegramInbound.swift` |
| Discord controls | New `Sources/AgrypnosCore/Questions/DiscordQuestionMessage.swift`; extend `Sources/AgrypnosCore/Notif/DiscordInboundGateway.swift`, `DiscordGatewaySession.swift`, `DiscordInboundRequest.swift`; wire `Apps/Agrypnos/Sources/Notif/DiscordInboundGatewayClient.swift` |
| Claude native path | New `Sources/AgrypnosCore/Questions/ClaudeQuestionPayload.swift`; new `Apps/Agrypnos/Sources/Questions/ClaudeQuestionHook.swift`, `QuestionHookSocket.swift`; branch headless entry in `Apps/Agrypnos/Sources/AppMain.swift` |
| OpenCode native path | New `Sources/AgrypnosCore/Questions/OpenCodeQuestionPayload.swift`; new `Apps/Agrypnos/Sources/Questions/OpenCodeQuestionSource.swift` |
| Codex native path, only after gate | New `Sources/AgrypnosCore/Questions/CodexQuestionPayload.swift`; new `Apps/Agrypnos/Sources/Questions/CodexQuestionSource.swift` |
| Cursor native path, only after gate | New `Sources/AgrypnosCore/Questions/CursorQuestionPayload.swift`; new `Apps/Agrypnos/Sources/Questions/CursorQuestionSource.swift` |
| Watch timeout | Extend `Sources/AgrypnosCore/Session/WatchEngine.swift`, `WatchTickProbe.swift`, `Sources/AgrypnosCore/Power/Safety.swift`, `Sources/AgrypnosCore/Copy/AgrypnosCopy.swift`; extend `Apps/Agrypnos/Sources/WatchRuntime.swift`, `WatchRuntime+Poll.swift`, `WatchRuntime+Kernel.swift` |
| Setup and privacy | Extend `Sources/AgrypnosCore/Session/UserPreferences.swift`, `Sources/AgrypnosCore/Notif/NotifSecretsPayload.swift`, `Apps/Agrypnos/Sources/Notif/NotifSecretsStore.swift`; new `Sources/AgrypnosCore/Questions/QuestionRelaySettings.swift` |
| Popover and guide | New `Apps/Agrypnos/Sources/MenuBar/PopoverController+Questions.swift`; wire existing `PopoverController.swift`, `PopoverController+Canvas.swift`, `PopoverController+Sections.swift`; extend `Sources/AgrypnosCore/Copy/PopoverSection.swift`, `PopoverStackLayout.swift`, `BotGuideCopy.swift` and `AgrypnosCopy.swift` |
| Build and documentation | Regenerate `Apps/Agrypnos/Agrypnos.xcodeproj/project.pbxproj` with `Scripts/generate-xcodeproj.py`; update `README.md`, `SECURITY.md`, `AGENTS.md` for this authorized feature |

Use source files' actual tracked casing (`Scripts/`, even though this Mac resolves `scripts/`). If an existing file would exceed 600 lines, move only the touched responsibility into the listed Questions file. Do not restructure adjacent code.

## Task 1: Prove all four native question round trips

**Files:** Create the compatibility report and contract supplement listed above; sanitized provider fixtures are the only retained probe data.

**Interfaces:** Consumes the four candidate contracts from the spec. Produces, for each exact installed surface/version, the supported attachment/setup procedure, native request/cancel/response schemas, instance/session/request identity, acknowledgment semantics, timeout rules and pending-request recovery behavior.

- [ ] **Step 1: Record installed versions and supported attachment mechanisms.** Use public docs and read-only version queries. Prepare disposable local conversations and temporary, scoped configuration; show the exact bot destinations before sending test messages. Never copy unrelated private conversations or credentials into fixtures.
- [ ] **Step 2: Run a harmless same-conversation choice probe for each provider.** Ask A/B, return B through its native interface, and verify the original run prints/writes a unique B marker once. Test a reply near 600 seconds and native expiry. A new Cursor ACP or Codex app-server process serving another session is FAIL.
- [ ] **Step 3: Exercise source races and recovery.** Two simultaneous sessions; local answer first; cancellation first; disconnect before and after submission; reopen a pending request; existing hooks/denials. PASS requires stable routing and a documented safe outcome for each. Capture sanitized exact payloads, not inferred schemas.
- [ ] **Step 4: Freeze the contract supplement.** For all four adapters, specify exact initializer/configuration fields, event decoder input, reply encoder output, native API methods, version checks and fixture assertions. Explain what evidence permits `accepted` versus merely `returnedToHook`/`unconfirmed`. Populate Task 5–8 protocol-specific details from observed contracts before approving production work. If a gate fails, record its failing observation and STOP production execution.
- [ ] **Step 5: Review and commit the evidence.** Only after all four pass and the supplement is reviewed, proceed. Suggested commit: `docs: verify native question response contracts`.

## Task 2: Validate questions and model selection, expiry and watch decisions

**Files:** Create the three Core Questions files and `QuestionRegistryTests.swift`, `QuestionWaitPolicyTests.swift`, `QuestionTestSupport.swift` under `Tests/AgrypnosCoreTests/`.

**Interfaces:**

- `QuestionKey: Hashable, Sendable` contains `provider: AgentKind`, `instanceID`, `sessionID`, `requestID` as strings. Adapters retain the original typed RPC identity internally.
- `QuestionOption` contains `id`, `label`, `detail: String?`. `AgentQuestion` contains `id`, `prompt`, `options`, `multiple`, `allowsEmpty`, `allowsFreeText`. `QuestionBatch` contains `key`, optional `projectLabel`, `questions`, `receivedUptime: TimeInterval`, `deadlineUptime: TimeInterval`.
- `QuestionAnswer` contains ordered selections by question/option identity; never route by display text. `QuestionDestination` is `.telegram`/`.discord`. `QuestionMessageRef` contains destination, chat/channel ID and message ID. `QuestionCallback` contains that reference, sender ID, opaque action token and lifecycle generation.
- `QuestionRegistry.insert(_ batch: QuestionBatch, handle: UUID) -> Bool`; `bindMessage(handle: UUID, reference: QuestionMessageRef)`; `handle(_ callback: QuestionCallback, authorizedUserID: String, now: TimeInterval) -> QuestionEffect`; `complete(handle: UUID, result: QuestionDelivery)`; `cancel(key: QuestionKey)`; `invalidateAll()`.
- `QuestionEffect` is ignore, rerender a destination, submit a complete `QuestionAnswer`, or return that batch to the Mac. `QuestionDelivery` is `.accepted`, `.returnedToHook`, `.rejected`, `.unconfirmed`. A `QuestionView` exposes immutable batch/draft/current-page data to both formatters.
- `QuestionWaitPolicy.init()` and mutating `observe(pendingDeadlines: [QuestionKey: TimeInterval], newlyExpired: Set<QuestionKey>, cleared: Set<QuestionKey>, now: TimeInterval, busy: Bool?, grace: TimeInterval) -> QuestionWaitDecision`. Decision is a struct with `action` (`.normal`, `.hold`, `.deferTimeout`, `.endUnanswered`) plus newly reportable timeout reasons; static `.normal` is the empty default used by WatchEngine. `nil` busy is unknown. `reset()` clears a previous arm's decisions.

- [ ] **Step 1: Add failing tests with a clock starting at 1,000.** `testTenMinuteDeadline` expects hold at 1,599 and end at 1,600 with `busy == false`; `testBusyAndUnknownDeferEnd` expects no end for true/nil, then requires 120 continuous quiet seconds after deferral; `testOtherQuestionKeepsOwnDeadline` leaves a second request's later deadline intact. `testFreshBusyProtectsEvenSameProvider` pins the conservative policy.

```swift
func testTenMinuteDeadline() {
    let key = QuestionKey(provider: .cursor, instanceID: "i", sessionID: "s", requestID: "q")
    var policy = QuestionWaitPolicy()
    XCTAssertEqual(policy.observe(pendingDeadlines: [key: 1600], newlyExpired: [],
        cleared: [], now: 1599, busy: false, grace: 120).action, .hold)
    XCTAssertEqual(policy.observe(pendingDeadlines: [:], newlyExpired: [key],
        cleared: [], now: 1600, busy: false, grace: 120).action, .endUnanswered)
}
```

- [ ] **Step 2: Add routing and shape tests.** `testFirstCompleteSubmissionWinsAcrossBots` asserts exactly one submit effect; `testDraftsNeverMixChannels` rejects a partial cross-channel batch; `testWrongUserMessageGenerationOrOptionIsIgnored` asserts no source call; `testDuplicateEventDoesNotExtendDeadline` expects 1,600 unchanged. Boundary tests accept 4/20/32 and reject 5/21/33, reject ambiguous IDs/labels, preserve Unicode and reject oversized whole panels. At expiry, no partial/default answer is emitted.
- [ ] **Step 3: Run `swift test --filter 'QuestionRegistryTests|QuestionWaitPolicyTests'`.** Expect failure because the new types/policy do not yet exist.
- [ ] **Step 4: Implement the interfaces.** Keep registry transitions synchronous; mark submitting before yielding. A valid complete human submission clears only that request's unanswered-timeout record immediately; slow/unconfirmed provider delivery remains distinct. Test a submission at 1599.9 with its acknowledgment arriving after 1600: no unanswered notification or duplicate submission, and no accepted copy without evidence. Keep terminal handles inert until the source is known cleared, bounded by the admitted request limit; overflow stays local. Generate opaque random action tokens. Existing request identity with changed payload invalidates old controls. Native local resolution clears only the matching policy record. No fake `AgentReport` or fake saw-busy fact.
- [ ] **Step 5: Re-run the focused command.** Expect PASS, including backward wall-clock changes having no effect on monotonic deadlines. Commit `feat: model native questions and bounded waiting` with only this task's files.

## Task 3: Relay Telegram questions through the existing poller

**Files:** Create `TelegramQuestionMessage.swift`, `QuestionRelayCoordinator.swift`; modify Telegram files in the map, `NotifSecretsPayload.swift`, `NotifSecretsStore.swift`, `UserPreferences.swift`; create `Tests/AgrypnosCoreTests/TelegramQuestionTests.swift` and `Tests/AgrypnosMacTests/QuestionRelayCoordinatorTests.swift`.

**Interfaces:** `@MainActor QuestionRelayCoordinator.receive(_ batch: QuestionBatch, submit: @escaping @MainActor (QuestionAnswer) async -> QuestionDelivery, returnLocal: @escaping @MainActor () async -> Void) -> Bool`, `cancel(key:)`, `invalidateAll()`. It owns registry, original response closures, a monotonic clock closure and one nearest-deadline task. `TelegramQuestionMessage.requests(view: QuestionView, botToken: String, chatID: String) -> [NotifOutboundRequest]`; builders also encode callback acknowledgments and message edits.

- [ ] **Step 1: Add failing wire tests.** Parse `callback_query` with sender, chat, message and action identity; preserve the old command path. Assert callback data <=64 bytes, full choice descriptions retained, no parse mode, multi-select review before submission, malformed callbacks ignored. A missing/wrong sender cannot select or submit.
- [ ] **Step 2: Add async coordinator tests.** Delay a fake provider result; a second Telegram/Discord submission must not enter it. Test local cancellation during send, stale generation after sleep, ambiguous delivery without retry, malformed/failed Telegram `ok` responses, missing message IDs, and HTTP 429. A callback ACK never changes provider state to accepted.
- [ ] **Step 3: Run `swift test --filter 'TelegramQuestionTests|QuestionRelayCoordinatorTests'`.** Expect FAIL for absent callback/control handling.
- [ ] **Step 4: Implement the smallest route.** Add optional callback/sender data to `TelegramInboundUpdate` with backward-compatible defaults. Include callbacks in the existing `getUpdates` request, consume them before command parsing even if rejected, and preserve its offset/generation/wake-miss drain. A callback containing `/disarm` must never enter the command path. Reuse `TelegramInboundHTTP`; add a question-specific response helper returning status/body/retry delay where needed rather than interpreting `Data?` as acceptance. Register each returned bot message ID before accepting its controls. Message-send ambiguity ends remote handling; do not blindly duplicate a question.
- [ ] **Step 5: Add settings support.** `UserPreferences.forwardAgentQuestions` defaults false on old/new installs; authorized `telegramQuestionUserId` and `discordQuestionUserId` round-trip through secrets without dropping existing fields. Only configured inbound destinations may receive question content. Inject transport/settings in tests; do not use live secrets.
- [ ] **Step 6: Run the focused tests plus `swift test --filter 'TelegramInbound|NotifOutbound|NotifIdle'`.** Expect PASS with unchanged arm/disarm/status/help behavior. Commit `feat: relay structured questions through Telegram`.

## Task 4: Add Discord question controls on the same coordinator

**Files:** Create `DiscordQuestionMessage.swift`, `Tests/AgrypnosCoreTests/DiscordQuestionTests.swift`; modify the Discord files in the map and coordinator wiring.

**Interfaces:** Add `.questionInteraction(DiscordQuestionInteraction)` to `DiscordGatewayEvent`/`DiscordGatewayEffect`; carry interaction/token/sender/channel/message/custom-ID data separately from slash commands. `DiscordQuestionMessage.requests(view: QuestionView, botToken: String, channelID: String) -> [NotifOutboundRequest]` feeds the Task 3 coordinator. Use component defer/update response types, not the existing slash-reply schema by accident.

- [ ] **Step 1: Add failing parser/request tests.** Type 3 interactions reach the question path, type 2 still reaches slash; obtain user ID from the documented guild-member or DM location; reject bot/wrong-user callbacks. Assert `allowed_mentions` disables all mention expansion, numbered buttons/custom IDs preserve long labels in the body, IDs <=100 characters, and all messages fit the spec limits.
- [ ] **Step 2: Run `swift test --filter 'DiscordQuestionTests|QuestionRelayCoordinatorTests'`.** Expect FAIL for the new component path.
- [ ] **Step 3: Implement Gateway and message handling.** Preserve sequence recording for question events and the existing resume/wake-miss behavior. Defer promptly before provider work; test initiation without awaiting it. Send/edit normal bot-authenticated messages; retain their returned IDs. Reuse Task 3's lifecycle, drafts and first-submission reservation. Do not add MESSAGE_CONTENT, a listen port, an Interactions Endpoint URL or a second Gateway.
- [ ] **Step 4: Add the two-channel race check and run `swift test --filter 'Discord|QuestionRelayCoordinatorTests'`.** The losing controls become inert even when their edit fails. Component handling survives a slow provider response without confusing the 15-minute interaction token lifetime with the question deadline. Expect PASS. Commit `feat: relay question choices through Discord`.

## Task 5: Connect Claude's ordinary question hook

**Files:** Create Claude/socket files in the map, `Tests/AgrypnosCoreTests/ClaudeQuestionPayloadTests.swift`, `Tests/AgrypnosMacTests/ClaudeQuestionHookTests.swift`; modify `AppMain.swift`. Use Task 1's exact fixtures and supplement.

**Interfaces:** `ClaudeQuestionPayload.decode(_ data: Data, instanceID: String, receivedUptime: TimeInterval) throws -> QuestionBatch`; `reply(original: Data, answer: QuestionAnswer) throws -> Data` preserves the original questions and maps IDs to the source's answers representation. `ClaudeQuestionHook.run(input: FileHandle, output: FileHandle) async -> Int32` is the headless entry; the private socket retains one original response channel per native tool call.

- [ ] **Step 1: Add failing tests from the verified hook fixtures.** Correct multi-question/multi-select answer input, duplicate question text rejection where text keys would collide, unknown tool/native permission payload returning no decision, unavailable app fallback <=2s, full-frame limit, cancellation/EOF, 600s helper expiry and 630s configured hook timeout. Verify no answer or broad permission is emitted on any error.
- [ ] **Step 2: Run `swift test --filter 'ClaudeQuestionPayloadTests|ClaudeQuestionHookTests'`.** Expect FAIL.
- [ ] **Step 3: Implement the native hook path.** Choose headless mode before `NSApplication`/crash-guard/wake setup. Use a private Unix socket, 0700 parent/0600 socket, same-UID check, safe ownership/symlink handling and length-bounded framing; block on readability, never scan files. Returning to local UI exits with the source's verified no-override response. Coexisting explicit denial wins as proven by Task 1. Do not claim native local/remote parallel dialogs unless the gate proved that behavior.
- [ ] **Step 4: Run focused tests and the disposable original-session hook check.** Same request resumes once; delayed response remains valid; fallback works when the app quits. Regenerate the project for new app sources. Commit `feat: connect Claude native questions`.

## Task 6: Connect the active OpenCode instance

**Files:** Create OpenCode files in the map and `Tests/AgrypnosCoreTests/OpenCodeQuestionPayloadTests.swift`, `Tests/AgrypnosMacTests/OpenCodeQuestionSourceTests.swift`.

**Interfaces:** `OpenCodeQuestionSource.start(configuration: OpenCodeQuestionConfiguration, receive: @escaping @MainActor (QuestionBatch) -> Void, resolved: @escaping @MainActor (QuestionKey) -> Void)`, `submit(key: QuestionKey, answer: QuestionAnswer) async -> QuestionDelivery`, `stop()`. Configuration contains the verified loopback endpoint, directory/workspace selector, version and optional credentials. Exact paths/body schemas come from the reviewed Task 1 supplement.

- [ ] **Step 1: Add failing tests for the pinned fixture version.** Pending-list plus concurrent live event deduplicates once; a local reply removes controls; wrong instance/workspace never matches; duplicate labels never map ambiguously; request-path components are encoded as data; a dropped POST response is unconfirmed, not retried.
- [ ] **Step 2: Run `swift test --filter 'OpenCodeQuestion'`.** Expect FAIL.
- [ ] **Step 3: Implement URLSession event streaming and the verified question API.** Connect only to the chosen active instance; authenticate there and reject cross-origin redirects. Reconcile events/list without losing arrivals during the snapshot. Reuse same-instance deadlines after reconnect; pending requests with unknown age on fresh app launch stay local. Use bounded reconnect backoff; never launch `serve`, scan ports or reject the source question merely to stop forwarding it.
- [ ] **Step 4: Run focused tests and original-session smoke check.** Expect one accepted native response, cancellation visibility and no repeated question after reconnect. Commit `feat: connect OpenCode native questions`.

## Task 7: Connect the existing Codex desktop conversation

**Files:** Create Codex files in the map and `Tests/AgrypnosCoreTests/CodexQuestionPayloadTests.swift`, `Tests/AgrypnosMacTests/CodexQuestionSourceTests.swift`.

**Interfaces:** Same `start/submit/stop` lifecycle as Task 6 with `CodexQuestionConfiguration` defined by the Task 1 supplement; `CodexQuestionPayload` decodes the verified native request and encodes a response to its original typed JSON-RPC ID. The coordinator's `QuestionKey` is a lookup key, never a replacement RPC ID.

- [ ] **Step 1: Add fixture-driven failing tests.** Preserve request ID type, thread/turn ownership and the source's earlier auto-resolution deadline. Command/file/plan approvals cannot enter this route. `serverRequest/resolved` without evidence of our answer being consumed cannot produce `.accepted`.
- [ ] **Step 2: Run `swift test --filter 'CodexQuestion'`.** Expect FAIL.
- [ ] **Step 3: Implement only the supported, proven desktop attachment contract from Task 1.** Maintain original response ownership, stale-generation cancellation and local-first answer handling. Unknown attachment/version fails visibly. Do not launch another app-server, reuse this assistant's internal app tools, or assume a documented server transport implies desktop access.
- [ ] **Step 4: Run focused tests and the original-desktop-session smoke check.** Require correct continuation and safe behavior after desktop restart; recovered requests must be demonstrably pending. Commit `feat: connect Codex desktop questions`.

## Task 8: Connect the existing Cursor desktop conversation

**Files:** Create Cursor files in the map and `Tests/AgrypnosCoreTests/CursorQuestionPayloadTests.swift`, `Tests/AgrypnosMacTests/CursorQuestionSourceTests.swift`.

**Interfaces:** Same native lifecycle with `CursorQuestionConfiguration` and exact decoder/response contracts from the Task 1 supplement. Retain conversation/generation/tool identity if that verified interface supplies it; no guessed payload fields.

- [ ] **Step 1: Add fixture-driven failing tests.** A question in desktop conversation A is answered only in A, two simultaneous generations remain separate, local answer/cancel invalidates remote controls, and missing native question support reports unavailable rather than waiting silently.
- [ ] **Step 2: Run `swift test --filter 'CursorQuestion'`.** Expect FAIL.
- [ ] **Step 3: Implement the verified native desktop path.** No ACP replacement launch, transcript parser, hidden rule, MCP question-tool substitute, private database/socket or UI clicking. If the installed version regresses the proven contract, turn this integration unavailable and retain local answering.
- [ ] **Step 4: Run focused tests and the existing-desktop-session smoke check.** PASS requires the original question consuming the selected answer once. Commit `feat: connect Cursor desktop questions`.

## Task 9: Apply the ten-minute policy through the existing watch lifecycle

**Files:** Modify watch/power files in the map; create `Tests/AgrypnosCoreTests/QuestionWatchTests.swift`, `Tests/AgrypnosMacTests/QuestionTimeoutRuntimeTests.swift`; extend `WatchTickProbeTests.swift`, `RuntimeFixture.swift`, `LastWatchEndTests.swift`.

**Interfaces:** Add `DisengageReason.questionUnanswered`. Extend `WatchEngine.tick(..., questionWait: QuestionWaitDecision = .normal) -> [WatchCommand]` and `WatchTickProbe.needed(engaged:mode:questionTimeoutPending: Bool = false)`. `WatchRuntime+Questions` translates coordinator changes and fresh `AgentProbeObservation.settleBusy(...)` values into policy decisions; the nearest-deadline callback runs this evaluation even if the normal probe is in flight. Expose `QuestionRelayCoordinator.cancelForWatchEnd()` and `resetForUserArm()` to invalidate old pending end decisions while preserving explicit feature opt-in.

- [ ] **Step 1: Add Core tests.** Quiet Agents at 120 seconds cannot disarm while a question deadline is live. Idle at 600 seconds ends with `.questionUnanswered`, does not emit `.postIdleAfterWaitNotif`, and preserves How long. A fresh busy, unknown/incomplete/stale observation or another live question prevents end. After busy/unknown deferral, require the configured continuous quiet grace. Source acceptance/cancellation releases that question's allowance. Manual/safety end wins; watch-off questions never arm.
- [ ] **Step 2: Run `swift test --filter 'QuestionWatchTests|QuestionWaitPolicyTests|WatchTickProbeTests'`.** Expect FAIL for absent policy integration.
- [ ] **Step 3: Implement Core integration.** Safety evaluation stays first. Evaluate unanswered timeout before ordinary idle-settle, suppress settle only for a real hold/deferred timeout, and keep kernel reassertion active. Preserve actual saw-busy, interrupt quiet continuity during a live question, resume ordinary grace after answers. Request existing agent probes during deferred timeout in any duration mode; stop that added demand when cleared.
- [ ] **Step 4: Add native race tests.** Kernel clear fails: previous watch state/reason restored and no successful-disarm bot copy. Successful clear: persist the real reason and attempt the spec's exact message; bound delivery to 3 seconds. Re-arm during send prevents old sleep. Lid opens during send: no sleep. Unknown/unconfirmed close: no sleep. Offline/429 bot cannot extend the hold. Sleep invalidates clicks; lock alone does not. No idle-after-wait message accompanies a question timeout.
- [ ] **Step 5: Run `swift test --filter 'QuestionTimeoutRuntimeTests|WatchDisarmRollbackTests|RuntimeRaceTests'`.** Expect new cases to FAIL before native wiring.
- [ ] **Step 6: Integrate in the shared disarm flow.** Extend `finishTickCommands` only for the new reason: use its existing kernel clear/readback and rollback, then persist the reason before the bounded bot-send task. Defer only the final existing hygiene/sleep commands, not kernel release; cancellation plus arm generation guards prevent stale commands. Recheck raw lid and captured stable confirmation immediately before deferred sleep. `setEngaged`, manual disarm, safety, quit, secrets changes and system sleep cancel relevant tasks/handles. Do not add a second pmset/sudoers stack or wait for notification delivery to prove release.
- [ ] **Step 7: Verify all focused tests and `swift test --filter 'Watch|AgentObservation|Question'`.** At a busy/unknown timeout report the spec's corresponding watch-remains-on reason once; eventual disarm reports the actual end. Commit `feat: end unanswered question waits without interrupting observed work`.

## Task 10: Expose one-time setup and verify the whole feature

**Files:** Modify setup/UI/build/docs files in the map; create `Tests/AgrypnosCoreTests/QuestionRelaySettingsTests.swift` and `docs/reviews/2026-09-29-native-question-verification.md` during execution.

**Interfaces:** `QuestionRelaySettings` owns the supported provider configuration types fixed by Task 1. `WatchRuntime.setForwardAgentQuestions(_ enabled: Bool)` synchronizes sources and destination eligibility. `PopoverController+Questions` owns the new controls/actions; existing controller/canvas/section files only wire them. No separate preference window or automatic provider-config overwrite.

- [ ] **Step 1: Add failing settings/setup tests.** Old preferences decode forwarding false; old secrets preserve existing values; missing sender ID or disabled inbound blocks forwarding to that destination. Provider selection filters events. Clearing secrets/disabling forwarding expires all callbacks and releases hook ownership without auto-selecting answers. The guide contains only the four verified surfaces, exact tested setup and the ten-minute/busy exception.
- [ ] **Step 2: Run `swift test --filter 'QuestionRelaySettingsTests|PopoverSectionTests|BotGuideCopyTests'`.** Expect FAIL for new settings/guide behavior.
- [ ] **Step 3: Add the minimal Notif card and read-only setup steps.** Title **Forward agent questions**; explain automatic structured choices, authorized sender IDs, ten-minute limit, busy/unknown deferral and awake requirement. Existing Agents selection applies. Display a per-provider connected/unavailable reason based on real adapter state, not process presence. OpenCode endpoint/auth fields and other verified required configuration stay in the popover; guide supplies exact one-time hook/connection instructions without changing unrelated provider settings. Free text and permission approvals clearly remain local. Update privacy/network scope and last-end copy in README/SECURITY/AGENTS; no unsupported coverage or wattage claims.
- [ ] **Step 4: Run `python3 Scripts/generate-xcodeproj.py`, then `swift test`.** Expect all Core and macOS tests PASS; use `bash Scripts/verify-linux.sh` on Linux/CI. Run the repository file-size check in a clean checkout or account separately for existing untracked build artifacts; do not delete the user's artifacts to make it pass.
- [ ] **Step 5: Build both configurations.** Run `xcodebuild -project Apps/Agrypnos/Agrypnos.xcodeproj -scheme Agrypnos -configuration Debug -derivedDataPath /tmp/agrypnos-question-debug CODE_SIGN_IDENTITY=- build`, then the same command with Release and `/tmp/agrypnos-question-release`. Expect `BUILD SUCCEEDED`. Do not replace the user's running build or merge as part of this check.
- [ ] **Step 6: Run the optical matrix on all four providers and both bots.** Original conversation resumes once; single/multi/batch selection; two sessions; both bots race; wrong user; native local answer; expiry; delayed/replayed click; provider/app restart; offline/429; Sleep panel while locked; explicit system sleep/wake; 600s unanswered with idle, busy and unknown evidence; safety/manual off/re-arm. Check the new reason in Telegram, `/status` and Watch caption, and popover height/Reduce Motion. Record exact versions and failures; do not mark a provider supported from fixture tests alone.
- [ ] **Step 7: Measure overhead under matched conditions.** Compare forwarding off/on for repeated 10-minute idle-event windows with the same Mac awake, same bot connections, same workload/display state. Separately measure the deliberate ten-minute wake allowance. Record CPU time, wakeups and Activity Monitor Energy Impact; use appropriate system power instrumentation if available. Do not turn CPU percentage/Energy Impact into invented watts. Verify there is no added periodic provider scan or second bot consumer.
- [ ] **Step 8: Commit and request whole-branch review.** Suggested commit: `feat: expose native question forwarding setup`. Review question authorization, provider attachment evidence, lifecycle races and wake behavior. All four provider gates plus the full matrix must pass before proposing release; no merge/release in this plan.

## Self-review and handoff

Checked spec coverage: automatic capture/no skill → Tasks 1, 5–8; complete selection and bot identity → Tasks 2–4; 600s and other-agent protection → Tasks 2, 9; truthful notifications and rollback → Task 9; opt-in/setup/privacy/version limits → Tasks 1, 10; energy → Task 10. All five Review Focus items have owning tests above. Shared interfaces and constants are defined once and reused.

The remaining technical uncertainty is explicit and blocking: supported live Cursor/Codex desktop attachment has not been proven. Task 1 must produce the concrete provider-contract supplement before the gated adapter steps can be executed. This plan is reviewable now, but is not evidence that all four integrations are feasible or already supported.

Recommended execution approach after review: **Native**, sequentially in this session, with a fresh whole-branch review at the end. The shared lifecycle/power interfaces are tightly coupled; keeping their implementation in one context is simpler. Subagent-driven execution is an alternative if the user prefers a fresh implementer/reviewer for each task.
