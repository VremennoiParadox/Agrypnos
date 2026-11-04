# Codex question relay — Agrypnos baseline

Date: 2026-10-06. Tree: `/Users/imightbeoufu/Developer/Agrypnos` on `codex-question-sup`.
Research only. No Swift edits. No Codex protocol invented here.

This note maps the **already-wired** question-forwarding surface so a later plan can add Codex the same way OpenCode and Claude were added: one button, same session, answers through `QuestionRelayCoordinator.receive`. Pattern to mirror: [Claude plan header / global constraints / file map](../superpowers/plans/2026-10-01-claude-question-relay.md). Same-session / one-button rules: [native-agent questions design](../superpowers/specs/2026-09-29-native-agent-questions-design.md).

## Docs read

| Path | Status |
| --- | --- |
| `docs/superpowers/plans/2026-10-01-claude-question-relay.md` | Present. Pattern to mirror (reuse coordinator; merge Claude settings; do not copy OpenCode TUI/HTTP). |
| `docs/superpowers/specs/2026-09-29-native-agent-questions-design.md` | Present. Codex gate + one-button / same-session rules (quoted below). |
| `docs/reviews/2026-09-29-agent-question-relay-research.md` | Present. Codex paragraph is **historical** (quoted below). |
| `docs/reviews/2026-09-29-claude-cursor-question-roundtrip.md` | Present. Claude/Cursor docs research (2026-09-29), not a 2026-10-01 Claude wiring note. |
| `docs/reviews/2026-10-01-opencode-question-review.md` | Present. |
| `docs/reviews/2026-10-01-opencode-question-verification.md` | Present. HTTP/Telegram human-confirmed; later superseded by one-button. |
| `docs/reviews/2026-10-01-opencode-one-button-verification.md` | Present. User Mac-verified one-button OpenCode. |
| `docs/reviews/2026-10-01-opencode-one-button-handoff.md` | Present. |
| `docs/reviews/2026-10-01-opencode-plugin-feasibility.md` | Present. **Historical FAIL** of a server-plugin probe; not the shipped TUI plugin. |
| `docs/reviews/2026-10-01-question-relay-cleanup.md` | Present. Removed unused `ClaudeQuestionPayload.swift` before the later Claude hook landed. |
| `docs/reviews/2026-10-01-claude-question-relay-agrypnos-baseline.md` | **Missing.** Referenced by the Claude plan; not in this tree. |
| `docs/reviews/2026-10-01-claude-question-relay-claude-docs.md` | **Missing.** |
| `docs/reviews/2026-10-01-claude-question-relay-local-signals.md` | **Missing.** |
| Any other `docs/reviews/2026-10-01-claude-question-relay*` | **Missing.** Claude wiring is in product Swift on this branch; the 2026-10-01 Claude *review notes* are not.

## AGENTS.md constraints that bind a Codex question button

Quoted, not the whole file.

- **Model (still on disk):** “Only the OpenCode 1.18.32 native source may be wired in this test build; Claude/Cursor/Codex remain unavailable.” (`AGENTS.md` 13–14.) Product Swift on this branch already wires Claude anyway. A Codex button still needs an explicit human authorize, the same way the Claude plan did, and must not edit that sentence unless the human says so.
- **File size:** “No file over 600 lines. Split *before* you hit the wall. Prefer ~250.” (`AGENTS.md` 40.)
- **Menu-bar / no settings window:** sections stay in the popover; switcher **Watch · Power · Agents · Notif · General**; no Licence/About; `LSUIElement`. (`AGENTS.md` 41 and Notif UI block.)
- **One user-owned bot stack:** “No shared Agrypnos bot.” Secrets in Application Support `notif-secrets.json`, mode **0600**, **Not Keychain**. (`AGENTS.md` 135–136, 152, 156.)
- **Discord inbound:** receive on the Mac. Do **not** set Discord’s Interactions Endpoint URL. Do **not** open a listen port. Webhook stays outbound-only. (`AGENTS.md` 140, 152.)
- **Enriched-status B scrapped:** Review blocks task text or a finish ETA on `/status` or elsewhere. (`AGENTS.md` 189–191, 296.)
- **Copy honesty:** every caption says what the control does. Ban “agent stopped” / “job finished” / “still thinking.” Facts-only bot copy. (`AGENTS.md` Personality / popover copy.)
- **Providers:** V1 names Cursor, Claude Code, Codex, and OpenCode for *busy heuristics*. That is not a claim that Codex *questions* are wired. “Do not promise every agent provider.” (`AGENTS.md` 44, 70.)
- **Forwarding never arms Keep the watch:** product copy and design. In-app: “Forwarding never arms it.” (`QuestionSetupChrome.policy`, `Sources/AgrypnosCore/Copy/QuestionSetupChrome.swift` 4.)

---

## 1. Current providers (from this tree, not memory)

| Provider | Question adapter in this tree | Product copy | Verification notes (docs, not this research’s live run) |
| --- | --- | --- | --- |
| **OpenCode** | Yes. Plugin source + leftover HTTP source. | Enable OpenCode forwarding. | User says Mac-verified. Docs agree: [one-button verification](2026-10-01-opencode-one-button-verification.md) “Human verification — PASS” / “opencode is working.” HTTP/Telegram earlier confirmed in [opencode-question-verification](2026-10-01-opencode-question-verification.md). |
| **Claude Code** | Yes. `PreToolUse` / `AskUserQuestion` hook helper. | Enable Claude Code forwarding. | User says **not yet verified**. No 2026-10-01 Claude review note in this tree. Claude plan still said live AskUserQuestion round-trip is unproven. Do not claim Mac-proven. |
| **Cursor** | **Dropped.** No `Cursor*Question*` Swift. Help: “Cursor and Codex are unavailable in this test build.” (`QuestionSetupChrome.help` line 3.) | — | Historical: [claude-cursor-question-roundtrip](2026-09-29-claude-cursor-question-roundtrip.md). |
| **Codex** | **Not wired.** `AgentKind.codex` exists for busy classification only. No `CodexQuestion*` type, payload, source, installer, or hook flag. Bot guide: “Codex question forwarding is not there.” (`BotGuideCopy.swift` 57.) | — | Historical research + design gate only. |

Evidence OpenCode + Claude are the only `receive` callers:

- OpenCode plugin: `WatchRuntime+OpenCodePlugin.swift` 112–113 → `questionRelay.receive`.
- OpenCode HTTP leftover: `WatchRuntime+OpenCodeQuestions.swift` 56–61 → `questionRelay.receive`.
- Claude hook: `WatchRuntime+ClaudeHook.swift` 115–116 → `questionRelay.receive`.
- `syncQuestionSources()` starts those two families only (`WatchRuntime+OpenCodeQuestions.swift` 26–30): `syncOpenCodeQuestionSources()` + `syncClaudeQuestionHook()`.

`QuestionKey.provider` for those paths is `.openCode` (`OpenCodeQuestionPayload.identity`, line 62) or `.claudeCode` (`ClaudeAskUserQuestionPayload.request`, key at lines around 90–91). Nothing builds `QuestionKey(provider: .codex, ...)`.

---

## 2. Shared types a Codex adapter must reuse

Exact signatures from this tree.

### `QuestionKey`

`Sources/AgrypnosCore/Questions/AgentQuestion.swift` 3–14:

```swift
public struct QuestionKey: Hashable, Sendable {
    public let provider: AgentKind
    public let instanceID: String
    public let sessionID: String
    public let requestID: String
    public init(provider: AgentKind, instanceID: String, sessionID: String, requestID: String)
}
```

Codex spelling, if wired later: `QuestionKey(provider: .codex, ...)`. `.codex` already exists on `AgentKind`.

### `QuestionOption` / `AgentQuestion` / `QuestionBatch`

Same file, 17–62:

```swift
public struct QuestionOption: Equatable, Sendable {
    public let id: String
    public let label: String
    public let detail: String?
    public init(id: String, label: String, detail: String? = nil)
}

public struct AgentQuestion: Equatable, Sendable {
    public let id: String
    public let prompt: String
    public let options: [QuestionOption]
    public let multiple: Bool
    public let allowsEmpty: Bool
    public let allowsFreeText: Bool
    public init(id: String, prompt: String, options: [QuestionOption], multiple: Bool = false,
                allowsEmpty: Bool = false, allowsFreeText: Bool = false)
}

public struct QuestionBatch: Equatable, Sendable {
    public let key: QuestionKey
    public let projectLabel: String?
    public let questions: [AgentQuestion]
    public let receivedUptime: TimeInterval
    public let deadlineUptime: TimeInterval
    public init(key: QuestionKey, projectLabel: String? = nil, questions: [AgentQuestion],
                receivedUptime: TimeInterval, deadlineUptime: TimeInterval)
}
```

`QuestionBatch.init` clamps a finite deadline to `receivedUptime + 600` (line 61). `isValid` requires 1–4 questions, 1–20 options, unique option ids, identity strings non-empty, panel text ≤ 1,800 UTF-16 (lines 77–89 region).

### `QuestionAnswer` (submit payload)

Same file, 112–119:

```swift
public struct QuestionAnswer: Equatable, Sendable {
    public let key: QuestionKey
    public let selections: [QuestionSelection]
}
```

### `AgentKind`

`Sources/AgrypnosCore/Agent/AgentKind.swift` 1–14:

```swift
public enum AgentKind: String, Codable, CaseIterable, Sendable, Equatable, Hashable {
    case cursor
    case claudeCode
    case codex
    case openCode
}
```

`.codex` is live for Agents include / busy heuristics (`AgentKindClassifier` returns `.codex` for `codex` processes). It is **not** a question adapter.

### `QuestionDelivery`

`AgentQuestion.swift` 160–161:

```swift
public enum QuestionDelivery: Equatable, Sendable {
    case accepted, returnedToHook, rejected, unconfirmed
}
```

### `QuestionRelayCoordinator.receive`

`Apps/Agrypnos/Sources/Questions/QuestionRelayCoordinator.swift` 91–94:

```swift
@discardableResult
func receive(_ batch: QuestionBatch,
             submit: @escaping @MainActor (QuestionAnswer) async -> QuestionDelivery,
             returnLocal: @escaping @MainActor () async -> Void) -> Bool
```

Guards (96–99): `currentSettings.enabled` (`forwardAgentQuestions`), `includedKinds.contains(batch.key.provider)`, and at least one complete Telegram or Discord destination. Discord pages must preflight (`DiscordQuestionMessage.canRender`). Returns `false` if the batch is not published.

Submit is invoked from `apply(.submit)` (177–189) after Core has reserved submitting. The adapter’s closure is the **only** place that talks to the provider.

### `QuestionRegistry`

`Sources/AgrypnosCore/Questions/QuestionRegistry.swift` 3, insert 31–49:

```swift
public struct QuestionRegistry: Sendable
@discardableResult
public mutating func insert(_ batch: QuestionBatch, handle: UUID) -> Bool
```

Capacity 32 pending entries. Duplicate native keys do not insert a second live request. `complete(handle:result:)` records `QuestionDelivery` (line 138). Coordinator owns the registry; adapters do not.

### `QuestionWaitPolicy`

`Sources/AgrypnosCore/Questions/QuestionWaitPolicy.swift` 21, 37–39 (file exists; CodeGraph’s Questions listing omitted it):

```swift
public struct QuestionWaitPolicy: Sendable
public mutating func observe(pendingDeadlines: [QuestionKey: TimeInterval],
                             newlyExpired: Set<QuestionKey>, cleared: Set<QuestionKey>,
                             now: TimeInterval, busy: Bool?, grace: TimeInterval) -> QuestionWaitDecision
```

`QuestionWaitDecision.Action`: `normal`, `hold`, `deferTimeout`, `endUnanswered` (lines 12–15). Wired from `WatchRuntime.questionWaitDecision` (`WatchRuntime+Questions.swift` 85–97). Ten-minute unanswered end uses the existing watch path; it does not arm.

### Forward switch and included kinds

`UserPreferences` (`Sources/AgrypnosCore/Session/UserPreferences.swift`):

- `openCodePluginEnabled: Bool` — default `false` (36, 68, decode 209).
- `claudeQuestionHookEnabled: Bool` — default `false` (37, 69, decode 210).
- `forwardAgentQuestions: Bool` — default `false` (38, 67, decode 208). **The one Forward toggle.**
- `includedAgentKinds: Set<AgentKind>` — never empty (43, 71–72, clamp 121–123).

`QuestionRelaySettings` (`QuestionRelayCoordinator.swift` 23–28):

```swift
struct QuestionRelaySettings: Equatable {
    var enabled: Bool
    var includedKinds: Set<AgentKind>
    var telegram: TelegramQuestionDestination?
    var discord: DiscordQuestionDestination? = nil
}
```

Filled by `WatchRuntime.questionRelaySettings()` (`WatchRuntime+Questions.swift` 16–34): `enabled: engine.preferences.forwardAgentQuestions`, `includedKinds: engine.preferences.includedAgentKinds`, Telegram/Discord only when inbound is on **and** bot secrets **and** answering-user IDs are set.

One setter: `setForwardAgentQuestions(_ on: Bool)` (36–44). Enable OpenCode / Enable Claude also set `forwardAgentQuestions = true` as a side effect of a successful one-button enable.

### `notif-secrets.json`

- File name: `NotifSecretsFileChrome.fileName = "notif-secrets.json"` (`Sources/AgrypnosCore/Notif/NotifFieldChrome.swift` 124–127).
- Mode **0600**: `Apps/Agrypnos/Sources/Notif/NotifSecretsStore.swift` 124 and 139 (`posixPermissions: 0o600`).
- Payload (`Sources/AgrypnosCore/Notif/NotifSecretsPayload.swift` 20–30, 81–90): existing bot fields plus `telegramQuestionUserId`, `discordQuestionUserId`, optional `openCodeQuestions` (manual HTTP leftover). **Not Keychain.** Question content is not persisted here.

---

## 3. How the one button works (OpenCode vs Claude)

Chrome is **not** a Notif card. Human decision recorded in the Claude plan: settings moved onto Agents. Current map:

- Agents include card button titled `QuestionSetupChrome.title` = `"Forward agent questions"` (`PopoverController+Cards.swift` 115–118).
- That toggles `showQuestionForwarding` and shows Agents cards: `.questionForwardingBack`, `.questionRelay`, `.pluginConnection`, `.claudeHook`, `.openCodeQuestions` (`PopoverSection.swift` 55–57).
- Notif cards stay outbound/inbound/setup/clear (`PopoverSection.swift` 60–63). Bot guide: “Notif does not have those cards.” (`BotGuideCopy.swift` 57.)

One **Forward agent questions** switch (`PopoverCard.questionRelay` / `forwardAgentQuestions`). Provider buttons sit beside it, not as a second Forward toggle.

### OpenCode — plugin install (Mac-verified path)

| Piece | This tree |
| --- | --- |
| Preference bool | `openCodePluginEnabled` |
| Card | `.pluginConnection` — title “OpenCode forwarding” (`PopoverController+OpenCodePlugin.swift` 7–8) |
| Enable | `"Enable OpenCode forwarding"` → `WatchRuntime.enableOpenCodeForwarding()` (32–71) |
| Disable | `disableOpenCodeForwarding()` sets `forwardAgentQuestions` false and stops sources (74–78). Does not delete files. |
| Remove | `removeOpenCodeForwarding()` disables then `OpenCodePluginInstaller.remove()` (79–89) |
| Files merged | Writes `configRoot/agrypnos-opencode.js`, patches global `tui.json` `plugin` array with that file URL, writes Application Support receipt `installation.json` (`OpenCodePluginInstaller.swift` 15–17, 30–55, `isInstalled` 63–71). Default config root `~/.config/opencode` (or `$XDG_CONFIG_HOME/opencode`). **Does not** spawn OpenCode. User must restart OpenCode once (`QuestionSetupChrome.pluginHelp` line 18). |
| Process Agrypnos starts | Unix-socket listener `OpenCodePluginQuestionSource.start` + `bridge.json` (`WatchRuntime+OpenCodePlugin.swift` 103–126). Same-UID, private dirs 0700, socket 0600. |
| Manual leftover | `.openCodeQuestions` HTTP source still exists when plugin is off (`syncOpenCodeQuestionSources` 40–71). Not the one-button path. |

### Claude — settings.json merge (wired, not Mac-verified)

| Piece | This tree |
| --- | --- |
| Preference bool | `claudeQuestionHookEnabled` |
| Card | `.claudeHook` — title “Claude Code forwarding” (`PopoverController+ClaudeHook.swift` 7–8) |
| Enable | `"Enable Claude Code forwarding"` → `enableClaudeQuestionHook()` (`WatchRuntime+ClaudeHook.swift` 54–75) |
| Disable | `disableClaudeQuestionHook()` (77–91): merge-remove **only** the Agrypnos `--claude-question-hook` entry; other hooks kept (`ClaudeHookSettingsMerge.disable` 25–32, `stripped` 45–54) |
| File merged | `~/.claude/settings.json` (`claudeSettingsURL` lines 7–9). `ClaudeHookSettingsMerge.enable` adds a `PreToolUse` group, matcher `AskUserQuestion`, command = app executable + `--claude-question-hook`, `timeout: 630` (`ClaudeHookSettingsMerge.swift` 6–22). Missing file starts from `{}` (enable path line 61). **MERGE. Never replace the file. Never delete other hooks.** |
| Process Agrypnos starts | Menu-bar Unix listener `ClaudeQuestionHookSource.start` (`syncClaudeQuestionHook` 100–119). When Claude runs the hook, `AppMain` (`Apps/Agrypnos/Sources/AppMain.swift` 12) branches to headless `ClaudeQuestionHookProcess.runIfRequested()` **before** `NSApplication`. Flag `--claude-question-hook` (`ClaudeAskUserQuestionPayload.flag` line 7). |

Enable for both providers also requires: forwarding not paused, that `AgentKind` selected in Agents, and a complete Telegram or Discord question destination (bot inbound + answering user ID). Neither enable path calls `setEngaged` / arms Keep the watch.

### What Codex must **not** copy blindly

These are **provider attachment** mechanisms, not the shared relay:

- **Do not copy OpenCode’s TUI plugin:** `agrypnos-opencode.js`, `tui.json` `plugin` array, `OpenCodeBridgeMessage` / `OpenCodeBridgeSocket` / `OpenCodePluginInstaller` / HTTP `/question`. Claude plan already banned that for Claude. Codex is a third native contract.
- **Do not copy Claude’s `~/.claude/settings.json` PreToolUse merge** or `--claude-question-hook` unless a later proved Codex contract is actually that hook shape. Historical Codex notes say hook presence is **not** a question-answer contract.
- **Do not copy** spawning a new Codex app-server, ACP/SDK replacement chat, MCP skill, transcript edits, Accessibility clicks, or Cursor ACP (design ban).
- **Do not** add a second Forward toggle or a Notif duplicate of the Agents cards.

Reuse the **relay** (section 2), not the **installer**.

---

## 4. Answer return path and “fake accepted”

Enum values (`AgentQuestion.swift` 160–161): `.accepted`, `.returnedToHook`, `.rejected`, `.unconfirmed`.

Coordinator stores whatever the adapter’s `submit` closure returns (`QuestionRelayCoordinator.swift` 185–187 → `registry.complete`). Bot copy is `QuestionMessageText.render` (`TelegramQuestionMessage.swift` 67+; Discord uses the same via `DiscordQuestionMessage.body` line 109):

| Delivery | Bot footer (`TelegramQuestionMessage.swift` 81–84) |
| --- | --- |
| `.accepted` | “The agent accepted the answers.” |
| `.returnedToHook` | “Answers returned to the local hook; agent acceptance is not confirmed.” |
| `.rejected` | “The agent rejected the answers. Check the question on your Mac.” |
| `.unconfirmed` | “Answer delivery is unconfirmed. Check the question on your Mac; Agrypnos will not retry it.” |

**Who returns what today**

- **Claude:** `ClaudeQuestionHookSource.serve` writes stdout (`allow` + `updatedInput.answers`) then `return .returnedToHook` (87–91). Writing stdout is **not** provider acceptance. Design: “If no reliable consumption acknowledgment exists, use the exact status **Answer returned to Claude's question hook**; never show **Answer accepted** merely because stdout was written.” ([design](../superpowers/specs/2026-09-29-native-agent-questions-design.md) Provider gates, Claude paragraph.)
- **OpenCode plugin:** waits for a native `.result` frame. `OpenCodeBridgeMessage` **rejects encoding `.returnedToHook`** (46: `throw Error.invalidFrame`). Plugin results are `accepted` / `rejected` / `unconfirmed` only (43–47, decode 107–108). Lost/slow ack → `.unconfirmed` after `resultTimeout` default **5** seconds (`OpenCodePluginQuestionSource.swift` 47, 122–124).
- **OpenCode HTTP leftover:** POST `/question/{id}/reply`; `true` body → `.accepted` (`OpenCodeQuestionSource.swift` 214–236).

**“Fake accepted” (banned):** labeling a request `.accepted` because Agrypnos successfully wrote bytes (hook stdout, socket frame, HTTP 200) without a **provider** acknowledgment that the original session consumed the answers. Claude’s stdout path is deliberately `.returnedToHook`. Design also: a lost response shows unconfirmed, never retries an answer blindly.

OpenCode plugin `returnedToHook` is not a valid IPC delivery. A Codex adapter that is hook-like should use `.returnedToHook`; one with a native accept ack may use `.accepted`. Do not invent the ack.

---

## 5. Timeouts already in Agrypnos

Still in code:

**600-second question deadline (clamp)** — `QuestionBatch.init` (`AgentQuestion.swift` 61):

```swift
self.deadlineUptime = deadlineUptime.isFinite ? min(deadlineUptime, receivedUptime + 600) : deadlineUptime
```

Claude decode uses `receivedUptime + 600` (`ClaudeAskUserQuestionPayload.swift` ~91). OpenCode payload the same (`OpenCodeQuestionPayload.swift` 49). Coordinator `receive` publishes `onChange(.observed(batch.key, batch.receivedUptime + 600))` (line 127) — watch allowance is ten minutes even if the native deadline is shorter. `expireDueQuestions` (194–207): native expiry earlier than ten minutes is `.cleared`, not unanswered.

**2-second helper fallback** — `ClaudeAskUserQuestionPayload.swift` 8–9:

```swift
public static let commandTimeoutSeconds = 630
public static let unavailableFallbackSeconds: TimeInterval = 2
```

`ClaudeQuestionHookProcess` connect loop uses `unavailableFallbackSeconds` (`ClaudeQuestionHookProcess.swift` 11–13, 32–43). Failure / insufficient stdout → `nativeFallback = Data("{}".utf8)` (payload lines 6, 96–103). No output that selects an answer on failure.

**Hook command timeout 630** — written into Claude `settings.json` (`WatchRuntime+ClaudeHook.swift` 62–63; merge 17). 630 leaves room for the 600s helper deadline (design Limits).

**Other (not the 600s window):** OpenCode plugin native-result wait default 5s (`OpenCodePluginQuestionSource.swift` 47). Coordinator edit retries cap delay using `seconds <= 600` for 429 `retry_after` (`QuestionRelayCoordinator.swift` 382). `QuestionWaitPolicy` clamps settle grace to 120…900 when deferring unanswered end (line 72).

---

## 6. File-size pressure (wc -l, this tree)

Hard cap 600; prefer ~250. Question-area files:

| Lines | File | Near 600? |
| --- | --- | --- |
| 513 | `Apps/Agrypnos/Sources/WatchRuntime.swift` | **Yes — properties only; new Codex logic must not land here.** |
| 511 | `Apps/Agrypnos/Sources/MenuBar/PopoverController.swift` | **Yes — same; new card logic in an extension file.** |
| 426 | `Apps/Agrypnos/Sources/Questions/QuestionRelayCoordinator.swift` | Closest *question* file. Do not grow it for Codex. |
| 402 | `Tests/AgrypnosMacTests/QuestionRelayCoordinatorTests.swift` | Test file; still under 600. |
| 363 | `Tests/AgrypnosMacTests/OpenCodeQuestionSourceTests.swift` | |
| 322 | `Apps/Agrypnos/Sources/Questions/OpenCodeQuestionSource.swift` | HTTP leftover; do not extend for Codex. |
| 205 | `OpenCodeBridgeSocket.swift` | |
| 191 | `PopoverController+Questions.swift` | |
| 187 | `QuestionRegistry.swift` | |
| 186 | `AgentQuestion.swift` | Shared types; keep new Codex schema in a new file. |
| 181 | `OpenCodePluginQuestionSource.swift` | |

No question file is over 600. WatchRuntime and PopoverController are the files already in the danger zone (Claude plan said the same at 509 / 496; they have grown).

---

## 7. `AgentKind.codex` vs unused Codex question types

- **Has a Codex case:** yes. `AgentKind.codex` (`AgentKind.swift` 4). Display name `"Codex"`. Used by process classification and Agents include. `cpuCountsTowardBusy` is true for `.codex` (`AgentKindClassifier.swift` 29).
- **Unused Codex *question* type:** none. No `CodexQuestionPayload`, `CodexQuestionSource`, `CodexAsk*`, hook flag, or plugin installer. Tests do not mention `CodexQuestion`. Busy snapshots may use `.codex` (`QuestionTimeoutRuntimeTests` uses an `AgentReport(kind: .codex, ...)` for watch-policy busy, not questions).

---

## 8. Must stay untouched

From AGENTS.md, the design, and the Claude plan’s reuse list, applied to this tree:

- **No second bot.** Same Telegram long poll and Discord Gateway. No shared Agrypnos bot.
- **No second Forward toggle.** One `forwardAgentQuestions`. Codex gets a provider enable button + `includedAgentKinds.contains(.codex)`, not a parallel switcher.
- **No Discord listen port / Interactions Endpoint URL.** Gateway only. Webhook outbound-only.
- **No Keychain** for secrets. `notif-secrets.json` mode 0600.
- **Forwarding never arms Keep the watch.** `QuestionSetupChrome.policy`; `enable*` paths do not call `setEngaged`.
- **Enriched-status B stays scrapped.** No task text / finish ETA on `/status` or question messages.
- **No second arm/disarm stack, no second poller.**
- **Do not spawn a replacement Codex session** (design: “A newly launched app-server does not pass.”).
- **Do not invent** private DB, undocumented sockets, transcript edits, Accessibility clicks (design Provider gates).
- **Cursor stays dropped** in this test-build copy until a separate authorize.

### Design: Codex gate and same-session / one-button (this is not a protocol)

From [2026-09-29-native-agent-questions-design.md](../superpowers/specs/2026-09-29-native-agent-questions-design.md):

- Intent: question from an **existing** conversation appears on the user’s own bot; selected answers return to **that same request**. “Setup happens once. No skill, per-prompt command, injected model instruction, or replacement conversation is required.”
- Codex row: “Documented connection to the desktop's actual app-server and original user-input RPC.” Proof: “A supported attachment mechanism, correct response ownership, local/remote race behavior and disconnect handling. **A newly launched app-server does not pass.**”
- “Do not invent a Cursor/Codex implementation around private databases, undocumented sockets, transcript edits or Accessibility clicks. If a new supported contract is discovered, add a concrete adapter task to the plan before implementing it.”

This baseline **does not** specify Codex RPC method names as current Agrypnos contracts. Those belong in a later protocol note, after a proved attachment path.

### Historical Codex paragraph (label: historical)

From [2026-09-29-agent-question-relay-research.md](2026-09-29-agent-question-relay-research.md) **§ Codex** (lines 28–32). Feasibility research on 2026-09-29. **Not** an approved adapter. **Not** implemented in this tree:

> App-server uses bidirectional JSON-RPC. `item/tool/requestUserInput` is answered by responding to the original request ID; `serverRequest/resolved` also fires when a request is cleared by interruption or turn changes. A resolved event alone does not prove an answer was applied. Requests may include an automatic-resolution timeout. Command/file/permission approvals have different response schemas. Unix-socket transport is documented, while the app-server command and TCP WebSocket transport carry experimental limitations. An installed desktop attachment path, pending-request recovery, and behavior when two clients answer were not established by the inspected documentation.
>
> The hook reference documents permission interception and generic tool paths, with exceptions for specialized tools. It does not establish a dedicated native user-question answer contract. Hook presence alone is therefore insufficient evidence for this feature.

Later compatibility probe ([2026-09-29-native-question-compatibility.md](2026-09-29-native-question-compatibility.md)) is also **historical** attachment-blocked evidence, not a shipped path.

---

## Reuse

Facts from this tree only — same spirit as the Claude plan file map.

- `QuestionRelayCoordinator.receive(_:submit:returnLocal:)`
- `QuestionRegistry`, `QuestionWaitPolicy` / `QuestionWaitDecision`
- `QuestionKey`, `QuestionOption`, `AgentQuestion`, `QuestionBatch`, `QuestionAnswer`, `QuestionDelivery`
- `AgentKind.codex` (already on the enum; busy include already knows it)
- One `forwardAgentQuestions` switch; `includedAgentKinds` gate
- `notif-secrets.json` 0600 + answering-user IDs; existing Telegram/Discord inbound
- `QuestionMessageText` (`.accepted` vs `.returnedToHook` honesty)
- Agents → “Which tools count as busy” → **Forward agent questions** (not a Notif card; not a settings window)
- File-size split: new Codex files, not WatchRuntime / PopoverController / QuestionRelayCoordinator growth

## Do not create

- A second bot, second Forward toggle, second arm stack, second poller
- Discord Interactions Endpoint URL or listen port
- Keychain secrets
- Arming Keep the watch from a question
- Enriched status / task text / finish ETA
- Codex copy of `agrypnos-opencode.js` / `tui.json` / `OpenCodeBridge*` / HTTP `/question`
- Codex copy of `~/.claude/settings.json` merge / `--claude-question-hook` unless a later proved contract is that shape
- A replacement Codex app-server, MCP skill, Cursor ACP host, or fake `.accepted` from writing bytes
- Restoring dropped Cursor in this slice
- An invented Codex protocol in product Swift before a concrete adapter task names the proved contract
