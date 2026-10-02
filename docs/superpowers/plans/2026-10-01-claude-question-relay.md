# Claude Code question relay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One Agrypnos button merges a `PreToolUse` hook whose matcher is `AskUserQuestion` into the user's existing Claude settings, starts the existing question forward path, and when that hook runs in the Claude session they already started, posts the question to their Telegram or Discord and writes the chosen labels back as `updatedInput.answers` on that same tool call.

**Architecture:** Official same-session path only: a command hook on `PreToolUse` matching tool name `AskUserQuestion`. The hook process is the existing Agrypnos executable with `--claude-question-hook`. It reads stdin, talks to the already-running menu-bar app over the design's private Unix socket, and writes stdout `permissionDecision: "allow"` plus `updatedInput` that echoes `questions` and sets `answers` as question text → selected label. `"allow"` alone is not enough. Delivery honesty is `QuestionDelivery.returnedToHook`. If Agrypnos is down, the helper returns native fallback (`{}`, no answers) within 2 seconds. If the user has not answered by the existing 600-second question deadline, the helper returns the same native fallback so Claude's native card remains. Do not spawn a second Claude, do not use PermissionRequest, Notification, Stop, Agent SDK `query`/`canUseTool`, official Channels, or Remote Control.

**Tech Stack:** macOS 14+, Swift tools 5.9, AgrypnosCore (Foundation JSON, Linux-testable), Darwin Unix socket in the Mac target, AppKit Notif popover. No new dependency. No OpenCode TUI plugin, no `OpenCodeBridge*`, no HTTP `/question`.

**Evidence:** [Agrypnos baseline](../../reviews/2026-10-01-claude-question-relay-agrypnos-baseline.md), [Claude official docs](../../reviews/2026-10-01-claude-question-relay-claude-docs.md), [local signals on this Mac](../../reviews/2026-10-01-claude-question-relay-local-signals.md). Spec: [native-agent questions](../specs/2026-09-29-native-agent-questions-design.md) Claude `PreToolUse` / `AskUserQuestion` / `--claude-question-hook` section. OpenCode “one button” meaning: [OpenCode relay milestone](2026-10-01-opencode-relay-milestone.md) — existing session, answer returns to that session. Branch: `claude-notif-question`. Do not switch or rename it. Installed CLI on this Mac: `claude` 2.1.183 at `~/.local/bin/claude`. Live AskUserQuestion round-trip on 2.1.183 is **not** proven; Task 6 is the human optical. Do not claim Mac-proven.

## Global Constraints

- AGENTS.md Model still reads: “Only the OpenCode 1.18.32 native source may be wired in this test build; Claude/Cursor/Codex remain unavailable.” This plan does **not** edit that sentence. The human authorizes wiring Claude in product Swift **only when they tell an implementer to execute this plan**.
- Stay on `claude-notif-question`. Do not switch branches. Do not rename the branch.
- Official path: `PreToolUse` matcher `AskUserQuestion`. Return `hookSpecificOutput.permissionDecision` `"allow"` plus `updatedInput.questions` (echo) plus `updatedInput.answers` mapping each question's text to the chosen option **label** (multi-select: comma-joined labels). Source: https://code.claude.com/docs/en/hooks as captured in the docs note. `"allow"` alone is not sufficient.
- `PermissionRequest` is allow/deny for permission prompts, not the answers map. `Notification` is observe-only. `Stop` is end-of-turn. Agent SDK `canUseTool`/`query` spawns a new Claude binary. Official Channels is a different product. Do not implement those.
- Design bans ACP/SDK replacement chats. Do not spawn a second Claude to replace the user's session. Do not use `claude -p`, `defer`, or `--resume` as the answer path.
- Design helper: existing app executable, headless `--claude-question-hook`. Private local Unix socket (not a public TCP endpoint). Parent directory mode **0700**, socket **0600**, same-UID peer check, no replacement of foreign/symlink paths. Hook command timeout **630** seconds. Helper deadline **600** seconds (same as `QuestionBatch` clamp). If Agrypnos is unavailable, native fallback within **2** seconds. No output that selects an answer on failure. Do not invent a different timeout.
- Plug-in: `QuestionRelayCoordinator.receive(_ batch:submit:returnLocal:) -> Bool`. Provider spelling is `QuestionKey(provider: .claudeCode, ...)`. Delivery is `.returnedToHook`. Never fake `.accepted` from writing stdout.
- Reuse bots, `QuestionRegistry`, `QuestionWaitPolicy`, `notif-secrets.json` mode 0600, one `forwardAgentQuestions` switch, `includedAgentKinds`. No second Forward toggle, no second arm stack, no second poller, no Discord Interactions Endpoint URL, no listen port.
- Do not copy `agrypnos-opencode.js`, `tui.json`, `OpenCodePluginInstaller`, `OpenCodeBridgeMessage`, `OpenCodeBridgeSocket`, HTTP `/question`. A Claude socket is the design's hook helper, not a copy of the OpenCode TUI bridge.
- This machine already has `UserPromptSubmit` / `Stop` / `StopFailure` hooks in `~/.claude/settings.json` pointing at `~/.brainrot/brainrot-state.sh`. **MERGE. Never replace `settings.json`. Never delete those brainrot hooks.** Disable removes **only** the Agrypnos `--claude-question-hook` entry.
- Hook config is a `hooks` object inside `~/.claude/settings.json` (and project `.claude/settings.json`). One-button writes the **user** file `~/.claude/settings.json`. Do not treat Cursor `~/.cursor/hooks.json` as Claude config. There is no `~/.claude/hooks.json`.
- Workspace trust (docs): interactive sessions hold hooks from every settings file, including `~/.claude/settings.json`, until the user trusts the folder. Button caption must say that in plain language. Do not invent poetry.
- `QuestionOption` needs an `id`; Claude's schema has labels, not option ids. Use the **label** as `QuestionOption.id` and as `AgentQuestion.id` use the **question text**. Answers consumed by Claude are still question text → label.
- One button, plain caption, same Notif section, no second settings window. File size: no file over 600 lines; prefer ~250. `WatchRuntime.swift` (509) and `PopoverController.swift` (496) take properties only; new logic goes in new extension files.
- Forwarding never arms Keep the watch. Free text and permission/plan approvals stay on Mac (`Answer on Mac` / native fallback). Facts-only bot copy. No watt claims. No telemetry.
- Core JSON parse/build/merge tests are Linux-testable (`swift test`, `Scripts/verify-linux.sh`). Live Claude round-trip is Task 6 and is unproven until the human runs it.
- Do not edit `docs/reviews/2026-10-01-cursor-question-relay-*.md` or `docs/superpowers/plans/2026-10-01-cursor-question-relay.md`.

---

## File map

| File | Responsibility |
| --- | --- |
| `Sources/AgrypnosCore/Questions/ClaudeAskUserQuestionPayload.swift` | Parse PreToolUse AskUserQuestion stdin into `QuestionBatch`; build sufficient stdout; native fallback `{}`; `helperStdout`. |
| `Sources/AgrypnosCore/Questions/ClaudeHookSettingsMerge.swift` | Pure merge/remove of the Agrypnos PreToolUse entry; preserve every other settings key and every other hook. |
| `Tests/AgrypnosCoreTests/ClaudeAskUserQuestionPayloadTests.swift` | Linux tests for parse, stdout, allow-alone, PermissionRequest reject, native fallback. |
| `Tests/AgrypnosCoreTests/ClaudeHookSettingsMergeTests.swift` | Linux tests for brainrot-preserving merge/disable and `claudeQuestionHookEnabled` default off. |
| `Apps/Agrypnos/Sources/Questions/ClaudeQuestionHookProcess.swift` | Headless `--claude-question-hook` process: 2s connect, write stdin, read stdout from the local socket. |
| `Apps/Agrypnos/Sources/Questions/ClaudeQuestionHookSource.swift` | Menu-bar Unix listener; `receive` + `.returnedToHook`; native fallback on `returnLocal`. |
| `Apps/Agrypnos/Sources/Questions/WatchRuntime+ClaudeHook.swift` | Enable/disable, merge file IO, start/stop listener. |
| `Apps/Agrypnos/Sources/AppMain.swift` | Branch on `--claude-question-hook` before `NSApplication`. |
| `Apps/Agrypnos/Sources/Questions/WatchRuntime+OpenCodeQuestions.swift` | Split `syncQuestionSources` so OpenCode-off does not stop the Claude listener. |
| `Sources/AgrypnosCore/Session/UserPreferences.swift` | `claudeQuestionHookEnabled: Bool = false`. |
| `Sources/AgrypnosCore/Copy/QuestionSetupChrome.swift` | Claude enable title, trust caption, card height. |
| `Sources/AgrypnosCore/Copy/PopoverSection.swift`, `PopoverStackLayout.swift` | Notif card `.claudeHook` after `.pluginConnection`. |
| `Apps/Agrypnos/Sources/MenuBar/PopoverController+ClaudeHook.swift` | Enable/Disable buttons mirroring OpenCode's setupButton, without TUI plugin/remove/manual. |
| `Apps/Agrypnos/Sources/MenuBar/PopoverController.swift`, `+Canvas.swift`, `+Sections.swift`, `+Questions.swift` | Card, slots, refresh. |
| `Sources/AgrypnosCore/Copy/BotGuideCopy.swift`, `README.md`, `SECURITY.md` | Setup honesty; merge warning; not Mac-proven. |
| `Apps/Agrypnos/Agrypnos.xcodeproj/project.pbxproj` | Register new Mac sources. |
| `Tests/AgrypnosMacTests/ClaudeHookRuntimeTests.swift` | Enable/disable against a temp settings file; missing socket → `{}`. |

Reuse, do not modify: `QuestionRelayCoordinator.receive`, `QuestionRegistry`, `QuestionWaitPolicy`, Telegram/Discord inbound, `notif-secrets.json`, `AgentKind.claudeCode`, `QuestionDelivery.returnedToHook` (already on the enum and in `QuestionMessageText`).

Do not create: a second bot, a Claude TUI plugin, `OpenCodeBridge` copy, HTTP hook URL, PermissionRequest hook, Agent SDK host, Channels plugin.

---

### Task 1: Parse PreToolUse AskUserQuestion stdin into QuestionBatch

**Files:**
- Create: `Sources/AgrypnosCore/Questions/ClaudeAskUserQuestionPayload.swift`
- Test: `Tests/AgrypnosCoreTests/ClaudeAskUserQuestionPayloadTests.swift`

**Interfaces:**
- Consumes: `QuestionKey(provider:instanceID:sessionID:requestID:)`, `QuestionOption(id:label:detail:)`, `AgentQuestion`, `QuestionBatch`, `AgentKind.claudeCode`
- Produces: `ClaudeAskUserQuestionPayload.decode(_ data: Data, receivedUptime: TimeInterval) throws -> QuestionBatch` and `ClaudeAskUserQuestionPayload.Error.invalidRequest`

- [x] **Step 1: Write the failing test**

```swift
import Foundation
import XCTest
@testable import AgrypnosCore

final class ClaudeAskUserQuestionPayloadTests: XCTestCase {
    private let fixture = Data(#"""
    {"session_id":"sess_test","transcript_path":"/tmp/t.jsonl","cwd":"/Users/test/project","hook_event_name":"PreToolUse","tool_name":"AskUserQuestion","tool_use_id":"toolu_01","tool_input":{"questions":[{"question":"Which framework?","header":"Framework","options":[{"label":"React","description":"SPA"},{"label":"Vue","description":"Also SPA"}],"multiSelect":false}]}}
    """#.utf8)

    func testDecodeMapsQuestionTextAndOptionLabels() throws {
        let batch = try ClaudeAskUserQuestionPayload.decode(fixture, receivedUptime: 1000)
        XCTAssertEqual(batch.key, QuestionKey(provider: .claudeCode, instanceID: "/Users/test/project",
            sessionID: "sess_test", requestID: "toolu_01"))
        XCTAssertEqual(batch.projectLabel, "project")
        XCTAssertEqual(batch.deadlineUptime, 1600)
        XCTAssertEqual(batch.questions.count, 1)
        XCTAssertEqual(batch.questions[0].id, "Which framework?")
        XCTAssertEqual(batch.questions[0].prompt, "Which framework?")
        XCTAssertEqual(batch.questions[0].options.map(\.id), ["React", "Vue"])
        XCTAssertEqual(batch.questions[0].options.map(\.label), ["React", "Vue"])
        XCTAssertEqual(batch.questions[0].options[0].detail, "SPA")
        XCTAssertFalse(batch.questions[0].multiple)
        XCTAssertTrue(batch.questions[0].allowsFreeText)
        XCTAssertTrue(batch.isValid)
    }

    func testRejectsPermissionRequestAndWrongTool() {
        let permission = Data(#"""
        {"session_id":"sess_test","cwd":"/Users/test/project","hook_event_name":"PermissionRequest","tool_name":"AskUserQuestion","tool_input":{"questions":[{"question":"Which?","header":"Q","options":[{"label":"A","description":"a"},{"label":"B","description":"b"}],"multiSelect":false}]}}
        """#.utf8)
        XCTAssertThrowsError(try ClaudeAskUserQuestionPayload.decode(permission, receivedUptime: 1))
        let bash = Data(#"""
        {"session_id":"sess_test","cwd":"/Users/test/project","hook_event_name":"PreToolUse","tool_name":"Bash","tool_use_id":"toolu_01","tool_input":{"command":"ls"}}
        """#.utf8)
        XCTAssertThrowsError(try ClaudeAskUserQuestionPayload.decode(bash, receivedUptime: 1))
    }
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `swift test --filter ClaudeAskUserQuestionPayloadTests.testDecodeMapsQuestionTextAndOptionLabels`

Expected: FAIL with `cannot find 'ClaudeAskUserQuestionPayload' in scope`

- [x] **Step 3: Write minimal implementation**

```swift
import Foundation

public enum ClaudeAskUserQuestionPayload {
    public enum Error: Swift.Error { case invalidRequest, invalidAnswer }

    public static let nativeFallback = Data("{}".utf8)
    public static let flag = "--claude-question-hook"
    public static let commandTimeoutSeconds = 630
    public static let unavailableFallbackSeconds: TimeInterval = 2

    public static func decode(_ data: Data, receivedUptime: TimeInterval) throws -> QuestionBatch {
        let request = try request(data)
        return request.batch
    }

    static func request(_ data: Data) throws -> (batch: QuestionBatch, originalQuestions: Any) {
        guard data.count <= 256 * 1024 else { throw Error.invalidRequest }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Error.invalidRequest
        }
        let event = (root["hook_event_name"] as? String) ?? (root["hookEventName"] as? String)
        guard event == "PreToolUse" else { throw Error.invalidRequest }
        guard root["tool_name"] as? String == "AskUserQuestion" else { throw Error.invalidRequest }
        let session = (root["session_id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let cwd = (root["cwd"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let toolUse = (root["tool_use_id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !session.isEmpty, !cwd.isEmpty, !toolUse.isEmpty else { throw Error.invalidRequest }
        guard let input = root["tool_input"] as? [String: Any],
              let questions = input["questions"] as? [[String: Any]], !questions.isEmpty else {
            throw Error.invalidRequest
        }
        let agents: [AgentQuestion] = try questions.map { item in
            guard let prompt = item["question"] as? String,
                  !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let options = item["options"] as? [[String: Any]], !options.isEmpty else {
                throw Error.invalidRequest
            }
            let mapped = try options.map { option -> QuestionOption in
                guard let label = option["label"] as? String,
                      !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw Error.invalidRequest
                }
                return QuestionOption(id: label, label: label, detail: option["description"] as? String)
            }
            return AgentQuestion(id: prompt, prompt: prompt, options: mapped,
                multiple: item["multiSelect"] as? Bool ?? false, allowsFreeText: true)
        }
        let key = QuestionKey(provider: .claudeCode, instanceID: cwd, sessionID: session, requestID: toolUse)
        let label = URL(fileURLWithPath: cwd).lastPathComponent
        let batch = QuestionBatch(key: key, projectLabel: label.isEmpty ? nil : label,
            questions: agents, receivedUptime: receivedUptime, deadlineUptime: receivedUptime + 600)
        guard batch.isValid else { throw Error.invalidRequest }
        return (batch, questions)
    }
}
```

Keep this file under ~250 lines. Stdout and `helperStdout` land in Task 2–3 on the same type.

- [x] **Step 4: Run tests and make sure they pass**

Run: `swift test --filter ClaudeAskUserQuestionPayloadTests`

Expected: PASS (the two tests in this task)

- [x] **Step 5: Commit**

```bash
git add Sources/AgrypnosCore/Questions/ClaudeAskUserQuestionPayload.swift \
  Tests/AgrypnosCoreTests/ClaudeAskUserQuestionPayloadTests.swift
git commit -m "$(cat <<'EOF'
Parse Claude AskUserQuestion hook stdin into the question batch.

EOF
)"
```

---

### Task 2: Build hook stdout allow + updatedInput.answers

**Files:**
- Modify: `Sources/AgrypnosCore/Questions/ClaudeAskUserQuestionPayload.swift`
- Modify: `Tests/AgrypnosCoreTests/ClaudeAskUserQuestionPayloadTests.swift`

**Interfaces:**
- Consumes: `QuestionAnswer`, `QuestionSelection`, Task 1 `request(_:)`
- Produces: `ClaudeAskUserQuestionPayload.stdout(original:answer:) throws -> Data`, `isSufficientAskUserQuestionOutput(_ data: Data) -> Bool`, `nativeFallback`

- [x] **Step 1: Write the failing tests**

Add to `ClaudeAskUserQuestionPayloadTests`:

```swift
    func testStdoutAllowEchoesQuestionsAndMapsLabels() throws {
        let batch = try ClaudeAskUserQuestionPayload.decode(fixture, receivedUptime: 1000)
        let answer = QuestionAnswer(key: batch.key, selections: [
            QuestionSelection(questionID: "Which framework?", optionIDs: ["Vue"])
        ])
        let body = try ClaudeAskUserQuestionPayload.stdout(original: fixture, answer: answer)
        XCTAssertTrue(ClaudeAskUserQuestionPayload.isSufficientAskUserQuestionOutput(body))
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let specific = try XCTUnwrap(root["hookSpecificOutput"] as? [String: Any])
        XCTAssertEqual(specific["hookEventName"] as? String, "PreToolUse")
        XCTAssertEqual(specific["permissionDecision"] as? String, "allow")
        let updated = try XCTUnwrap(specific["updatedInput"] as? [String: Any])
        let questions = try XCTUnwrap(updated["questions"] as? [[String: Any]])
        XCTAssertEqual(questions.first?["question"] as? String, "Which framework?")
        XCTAssertEqual(questions.first?["header"] as? String, "Framework")
        XCTAssertEqual(updated["answers"] as? [String: String], ["Which framework?": "Vue"])
    }

    func testAllowAloneIsNotSufficient() throws {
        let allowAlone = Data(#"""
        {"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}
        """#.utf8)
        XCTAssertFalse(ClaudeAskUserQuestionPayload.isSufficientAskUserQuestionOutput(allowAlone))
        XCTAssertFalse(ClaudeAskUserQuestionPayload.isSufficientAskUserQuestionOutput(
            ClaudeAskUserQuestionPayload.nativeFallback))
    }

    func testMultiSelectJoinsLabelsWithComma() throws {
        let multi = Data(#"""
        {"session_id":"sess_test","cwd":"/Users/test/project","hook_event_name":"PreToolUse","tool_name":"AskUserQuestion","tool_use_id":"toolu_02","tool_input":{"questions":[{"question":"Which colors?","header":"Colors","options":[{"label":"Red","description":"Warm"},{"label":"Blue","description":"Cool"}],"multiSelect":true}]}}
        """#.utf8)
        let batch = try ClaudeAskUserQuestionPayload.decode(multi, receivedUptime: 10)
        XCTAssertTrue(batch.questions[0].multiple)
        let answer = QuestionAnswer(key: batch.key, selections: [
            QuestionSelection(questionID: "Which colors?", optionIDs: ["Red", "Blue"])
        ])
        let body = try ClaudeAskUserQuestionPayload.stdout(original: multi, answer: answer)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let specific = try XCTUnwrap(root["hookSpecificOutput"] as? [String: Any])
        let updated = try XCTUnwrap(specific["updatedInput"] as? [String: Any])
        XCTAssertEqual(updated["answers"] as? [String: String], ["Which colors?": "Red, Blue"])
    }
```

- [x] **Step 2: Run test to verify it fails**

Run: `swift test --filter ClaudeAskUserQuestionPayloadTests.testAllowAloneIsNotSufficient`

Expected: FAIL with `isSufficientAskUserQuestionOutput` not found (or `stdout` not found)

- [x] **Step 3: Write minimal implementation**

Add to `ClaudeAskUserQuestionPayload`:

```swift
    public static func stdout(original: Data, answer: QuestionAnswer) throws -> Data {
        let parsed = try request(original)
        guard answer.key == parsed.batch.key,
              answer.selections.count == parsed.batch.questions.count else { throw Error.invalidAnswer }
        var answers: [String: String] = [:]
        for (question, selection) in zip(parsed.batch.questions, answer.selections) {
            guard selection.questionID == question.id,
                  !selection.optionIDs.isEmpty,
                  Set(selection.optionIDs).count == selection.optionIDs.count,
                  question.multiple || selection.optionIDs.count == 1 else { throw Error.invalidAnswer }
            let selected = Set(selection.optionIDs)
            guard selected.isSubset(of: Set(question.options.map(\.id))) else { throw Error.invalidAnswer }
            let labels = question.options.filter { selected.contains($0.id) }.map(\.label)
            answers[question.prompt] = labels.joined(separator: ", ")
        }
        let updated: [String: Any] = ["questions": parsed.originalQuestions, "answers": answers]
        let specific: [String: Any] = [
            "hookEventName": "PreToolUse",
            "permissionDecision": "allow",
            "updatedInput": updated
        ]
        let data = try JSONSerialization.data(withJSONObject: ["hookSpecificOutput": specific])
        guard isSufficientAskUserQuestionOutput(data) else { throw Error.invalidAnswer }
        return data
    }

    public static func isSufficientAskUserQuestionOutput(_ data: Data) -> Bool {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let specific = root["hookSpecificOutput"] as? [String: Any],
              specific["hookEventName"] as? String == "PreToolUse",
              specific["permissionDecision"] as? String == "allow",
              let updated = specific["updatedInput"] as? [String: Any],
              let questions = updated["questions"] as? [Any], !questions.isEmpty,
              let answers = updated["answers"] as? [String: String],
              !answers.isEmpty,
              answers.values.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        else { return false }
        return true
    }
```

Change `request` so `originalQuestions` is the raw `questions` array (`Any` / `[Any]`), not rebuilt.

- [x] **Step 4: Run tests and make sure they pass**

Run: `swift test --filter ClaudeAskUserQuestionPayloadTests`

Expected: PASS

- [x] **Step 5: Commit**

```bash
git add Sources/AgrypnosCore/Questions/ClaudeAskUserQuestionPayload.swift \
  Tests/AgrypnosCoreTests/ClaudeAskUserQuestionPayloadTests.swift
git commit -m "$(cat <<'EOF'
Build AskUserQuestion hook stdout from selected labels.

EOF
)"
```

---

### Task 3: `--claude-question-hook` helper process

**Files:**
- Modify: `Sources/AgrypnosCore/Questions/ClaudeAskUserQuestionPayload.swift`
- Modify: `Tests/AgrypnosCoreTests/ClaudeAskUserQuestionPayloadTests.swift`
- Create: `Apps/Agrypnos/Sources/Questions/ClaudeQuestionHookProcess.swift`
- Modify: `Apps/Agrypnos/Sources/AppMain.swift`
- Modify: `Apps/Agrypnos/Agrypnos.xcodeproj/project.pbxproj` (add `ClaudeQuestionHookProcess.swift` to the Questions group and Sources build phase, same pattern as `OpenCodePluginQuestionSource.swift`)

**Interfaces:**
- Consumes: `ClaudeAskUserQuestionPayload.decode`, `stdout`, `isSufficientAskUserQuestionOutput`, `nativeFallback`, `flag` (`"--claude-question-hook"`)
- Produces: `ClaudeAskUserQuestionPayload.helperStdout(stdin:exchange:) -> Data`; `ClaudeQuestionHookProcess.runIfRequested() -> Bool`; socket at `~/Library/Application Support/Agrypnos/claude-question-hook/hook.sock`

The design already names this helper: headless `--claude-question-hook` on the existing app executable. It does not exist in this checkout. This task creates it. The listener that answers the socket is Task 5; this task still ships a helper that returns `{}` when the socket is missing (2s connect timeout).

- [x] **Step 1: Write the failing Linux tests**

Add to `ClaudeAskUserQuestionPayloadTests`:

```swift
    func testHelperStdoutWritesAnswersFromExchange() throws {
        let batch = try ClaudeAskUserQuestionPayload.decode(fixture, receivedUptime: 0)
        let answer = QuestionAnswer(key: batch.key, selections: [
            QuestionSelection(questionID: "Which framework?", optionIDs: ["Vue"])
        ])
        let expected = try ClaudeAskUserQuestionPayload.stdout(original: fixture, answer: answer)
        let out = ClaudeAskUserQuestionPayload.helperStdout(stdin: fixture) { stdin in
            XCTAssertEqual(stdin, fixture)
            return expected
        }
        XCTAssertEqual(out, expected)
        XCTAssertTrue(ClaudeAskUserQuestionPayload.isSufficientAskUserQuestionOutput(out))
    }

    func testHelperStdoutFallsBackWhenAgrypnosUnavailable() {
        let out = ClaudeAskUserQuestionPayload.helperStdout(stdin: fixture) { _ in
            throw ClaudeAskUserQuestionPayload.Error.invalidRequest
        }
        XCTAssertEqual(out, ClaudeAskUserQuestionPayload.nativeFallback)
        XCTAssertFalse(ClaudeAskUserQuestionPayload.isSufficientAskUserQuestionOutput(out))
    }

    func testHelperStdoutRejectsAllowAloneFromExchange() {
        let allowAlone = Data(#"""
        {"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}
        """#.utf8)
        let out = ClaudeAskUserQuestionPayload.helperStdout(stdin: fixture) { _ in allowAlone }
        XCTAssertEqual(out, ClaudeAskUserQuestionPayload.nativeFallback)
    }

    func testHelperStdoutFallsBackOnUnparseableStdin() {
        let out = ClaudeAskUserQuestionPayload.helperStdout(stdin: Data("not-json".utf8)) { _ in
            XCTFail("must not contact Agrypnos")
            return Data()
        }
        XCTAssertEqual(out, ClaudeAskUserQuestionPayload.nativeFallback)
    }
```

- [x] **Step 2: Run test to verify it fails**

Run: `swift test --filter ClaudeAskUserQuestionPayloadTests.testHelperStdoutFallsBackWhenAgrypnosUnavailable`

Expected: FAIL with `helperStdout` not found

- [x] **Step 3: Implement helperStdout and the Mac process**

Add to `ClaudeAskUserQuestionPayload`:

```swift
    public static func helperStdout(stdin: Data, exchange: (Data) throws -> Data) -> Data {
        do {
            _ = try decode(stdin, receivedUptime: 0)
            let reply = try exchange(stdin)
            return isSufficientAskUserQuestionOutput(reply) ? reply : nativeFallback
        } catch {
            return nativeFallback
        }
    }

    public static func defaultSocketURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Agrypnos/claude-question-hook", isDirectory: true)
            .appendingPathComponent("hook.sock")
    }
```

Create `Apps/Agrypnos/Sources/Questions/ClaudeQuestionHookProcess.swift`:

```swift
import Foundation
import Darwin
#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

enum ClaudeQuestionHookProcess {
    static func runIfRequested() -> Bool {
        guard CommandLine.arguments.contains(ClaudeAskUserQuestionPayload.flag) else { return false }
        let stdin = FileHandle.standardInput.readDataToEndOfFile()
        let out = ClaudeAskUserQuestionPayload.helperStdout(stdin: stdin) { payload in
            try exchange(payload, socketURL: ClaudeAskUserQuestionPayload.defaultSocketURL(),
                connectTimeout: ClaudeAskUserQuestionPayload.unavailableFallbackSeconds)
        }
        FileHandle.standardOutput.write(out)
        return true
    }

    static func exchange(_ payload: Data, socketURL: URL, connectTimeout: TimeInterval) throws -> Data {
        guard payload.count <= 256 * 1024 else { throw ClaudeAskUserQuestionPayload.Error.invalidRequest }
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw ClaudeAskUserQuestionPayload.Error.invalidRequest }
        defer { close(fd) }
        var address = sockaddr_un()
        let path = Array(socketURL.path.utf8) + [0]
        guard path.count <= MemoryLayout.size(ofValue: address.sun_path) else {
            throw ClaudeAskUserQuestionPayload.Error.invalidRequest
        }
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: path) }
        let deadline = Date().addingTimeInterval(connectTimeout)
        var connected = false
        while Date() < deadline {
            let result = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
                }
            }
            if result == 0 { connected = true; break }
            usleep(50_000)
        }
        guard connected else { throw ClaudeAskUserQuestionPayload.Error.invalidRequest }
        var uid = uid_t(), gid = gid_t()
        guard getpeereid(fd, &uid, &gid) == 0, uid == getuid() else {
            throw ClaudeAskUserQuestionPayload.Error.invalidRequest
        }
        try writeAll(fd, payload)
        shutdown(fd, SHUT_WR)
        return try readAll(fd)
    }

    private static func writeAll(_ fd: Int32, _ data: Data) throws {
        try data.withUnsafeBytes { raw in
            var sent = 0
            while sent < data.count {
                let n = Darwin.write(fd, raw.baseAddress!.advanced(by: sent), data.count - sent)
                guard n > 0 else { throw ClaudeAskUserQuestionPayload.Error.invalidRequest }
                sent += n
            }
        }
    }

    private static func readAll(_ fd: Int32) throws -> Data {
        var out = Data()
        var buffer = [UInt8](repeating: 0, count: 8192)
        while true {
            let n = Darwin.read(fd, &buffer, buffer.count)
            if n == 0 { return out }
            guard n > 0 else { throw ClaudeAskUserQuestionPayload.Error.invalidRequest }
            out.append(buffer, count: n)
            guard out.count <= 256 * 1024 else { throw ClaudeAskUserQuestionPayload.Error.invalidRequest }
        }
    }
}
```

Replace `Apps/Agrypnos/Sources/AppMain.swift` `main()` with:

```swift
    @MainActor
    static func main() {
        if ClaudeQuestionHookProcess.runIfRequested() { return }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        AppHolder.shared.delegate = delegate
        app.delegate = delegate
        app.run()
    }
```

Do not start `NSApplication`, `SleepDisabledCrashGuard`, or the menu bar in the hook process.

pbxproj (24-character IDs, same groups as existing OpenCode files):

- `PBXFileReference` `C4A91E07B2D84F1A9E6C3B50` path `ClaudeQuestionHookProcess.swift`
- `PBXBuildFile` `D5B02F18C3E95A2B0F7D4C61` `ClaudeQuestionHookProcess.swift in Sources`
- Add the fileRef to the `Questions` group next to `WatchRuntime+OpenCodePlugin.swift`
- Add the build file to `PBXSourcesBuildPhase`

Protocol on the socket (not OpenCode frames, no token, no hello): helper writes the raw PreToolUse JSON and shuts down write; the app (Task 5) writes one JSON reply and closes. Auth is directory **0700**, socket **0600**, `getpeereid` same UID.

- [x] **Step 4: Run Linux tests**

Run: `swift test --filter ClaudeAskUserQuestionPayloadTests`

Expected: PASS

- [x] **Step 5: Commit**

```bash
git add Sources/AgrypnosCore/Questions/ClaudeAskUserQuestionPayload.swift \
  Tests/AgrypnosCoreTests/ClaudeAskUserQuestionPayloadTests.swift \
  Apps/Agrypnos/Sources/Questions/ClaudeQuestionHookProcess.swift \
  Apps/Agrypnos/Sources/AppMain.swift \
  Apps/Agrypnos/Agrypnos.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
Add the Claude question hook helper entry point.

EOF
)"
```

---

### Task 4: Enable button that merges settings and sets forwarding

> **Human decision (supersedes the 148pt Notif card):** Question settings moved out of Notif onto an Agents button under “Which tools count as busy.” OpenCode + Claude controls show in the same popover; Codex is not in this slice. Missing `~/.claude/settings.json` uses the existing create-or-replace write.


**Files:**
- Create: `Sources/AgrypnosCore/Questions/ClaudeHookSettingsMerge.swift`
- Test: `Tests/AgrypnosCoreTests/ClaudeHookSettingsMergeTests.swift`
- Modify: `Sources/AgrypnosCore/Session/UserPreferences.swift` (`claudeQuestionHookEnabled: Bool = false`, CodingKeys, init, decode default false, encode)
- Modify: `Sources/AgrypnosCore/Copy/QuestionSetupChrome.swift`
- Modify: `Sources/AgrypnosCore/Copy/PopoverSection.swift` (add `claudeHook` after `pluginConnection` in `PopoverCard` and in `.notif.cards`)
- Modify: `Sources/AgrypnosCore/Copy/PopoverStackLayout.swift` (slot, `height(for:)`, `make` initializer)
- Modify: `Sources/AgrypnosCore/Copy/BotGuideCopy.swift` (`questionSetup` gains a Claude enable step; keep the OpenCode steps)
- Create: `Apps/Agrypnos/Sources/MenuBar/PopoverController+ClaudeHook.swift`
- Modify: `Apps/Agrypnos/Sources/MenuBar/PopoverController.swift` (card + two buttons)
- Modify: `Apps/Agrypnos/Sources/MenuBar/PopoverController+Canvas.swift`
- Modify: `Apps/Agrypnos/Sources/MenuBar/PopoverController+Sections.swift`
- Modify: `Apps/Agrypnos/Sources/MenuBar/PopoverController+Questions.swift` (`refreshQuestionChrome`)
- Create: `Apps/Agrypnos/Sources/Questions/WatchRuntime+ClaudeHook.swift` (file IO + prefs; listener start is Task 5)
- Modify: `Apps/Agrypnos/Agrypnos.xcodeproj/project.pbxproj`
- Modify tests that hard-code Notif card lists:
  - `Tests/AgrypnosCoreTests/NotifPopoverChromeTests.swift`
  - `Tests/AgrypnosCoreTests/TelegramInboundPopoverChromeTests.swift`
  - `Tests/AgrypnosCoreTests/DiscordInboundPopoverChromeTests.swift`
  - `Tests/AgrypnosCoreTests/PopoverSectionTests.swift`
  - `Tests/AgrypnosCoreTests/QuestionRelayLayoutTests.swift`
- Modify: `README.md`, `SECURITY.md`
- Test: `Tests/AgrypnosMacTests/ClaudeHookRuntimeTests.swift` (temp settings file, never `~/.claude/settings.json`)

**Interfaces:**
- Consumes: `ClaudeAskUserQuestionPayload.flag`, `commandTimeoutSeconds` (630)
- Produces: `ClaudeHookSettingsMerge.enable(settingsJSON:command:timeoutSeconds:) throws -> Data`, `ClaudeHookSettingsMerge.disable(settingsJSON:) throws -> Data`, `WatchRuntime.enableClaudeQuestionHook() async -> Bool`, `WatchRuntime.disableClaudeQuestionHook()`, `QuestionSetupChrome.claudeEnableTitle`, `QuestionSetupChrome.claudeHelp`

Copy (plain, from the docs note; do not invent):

```swift
public static let claudeEnableTitle = "Enable Claude Code forwarding"
public static let claudeHelp = "Adds a PreToolUse AskUserQuestion hook to your Claude settings. Interactive sessions hold hooks until you trust the folder."
public static let claudeCardHeight = 148
```

Update `QuestionSetupChrome.help` to: `"Structured OpenCode and Claude Code choices on your bot. Free text and approvals stay on Mac. Cursor and Codex are unavailable in this test build."` Do not edit `AGENTS.md`.

- [x] **Step 1: Write the failing merge tests**

```swift
import Foundation
import XCTest
@testable import AgrypnosCore

final class ClaudeHookSettingsMergeTests: XCTestCase {
    private let brainrot = "/Users/test/.brainrot/brainrot-state.sh"
    private var existing: Data {
        Data(#"""
        {"permissions":{"allow":["mcp__x"]},"model":"opus","hooks":{"UserPromptSubmit":[{"hooks":[{"type":"command","command":"/Users/test/.brainrot/brainrot-state.sh"}]}],"Stop":[{"hooks":[{"type":"command","command":"/Users/test/.brainrot/brainrot-state.sh"}]}],"StopFailure":[{"hooks":[{"type":"command","command":"/Users/test/.brainrot/brainrot-state.sh"}]}]},"enableWorkflows":true}
        """#.utf8)
    }

    func testEnableKeepsBrainrotAndAddsAskUserQuestionMatcher() throws {
        let command = "/Applications/Agrypnos.app/Contents/MacOS/Agrypnos --claude-question-hook"
        let merged = try ClaudeHookSettingsMerge.enable(settingsJSON: existing, command: command, timeoutSeconds: 630)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: merged) as? [String: Any])
        XCTAssertEqual(root["model"] as? String, "opus")
        XCTAssertEqual((root["permissions"] as? [String: Any])?["allow"] as? [String], ["mcp__x"])
        XCTAssertEqual(root["enableWorkflows"] as? Bool, true)
        let hooks = try XCTUnwrap(root["hooks"] as? [String: Any])
        XCTAssertEqual(command(in: hooks, event: "UserPromptSubmit"), brainrot)
        XCTAssertEqual(command(in: hooks, event: "Stop"), brainrot)
        XCTAssertEqual(command(in: hooks, event: "StopFailure"), brainrot)
        let pre = try XCTUnwrap(hooks["PreToolUse"] as? [[String: Any]])
        let ask = try XCTUnwrap(pre.first { $0["matcher"] as? String == "AskUserQuestion" })
        let hook = try XCTUnwrap((ask["hooks"] as? [[String: Any]])?.first)
        XCTAssertEqual(hook["type"] as? String, "command")
        XCTAssertEqual(hook["command"] as? String, command)
        XCTAssertEqual(hook["timeout"] as? Int, 630)
        XCTAssertTrue(command.contains(ClaudeAskUserQuestionPayload.flag))
    }

    func testDisableRemovesOnlyAgrypnosHook() throws {
        let command = "/tmp/Agrypnos --claude-question-hook"
        let withBash = try ClaudeHookSettingsMerge.enable(settingsJSON: existing, command: command, timeoutSeconds: 630)
        var root = try JSONSerialization.jsonObject(with: withBash) as! [String: Any]
        var hooks = root["hooks"] as! [String: Any]
        var pre = hooks["PreToolUse"] as! [[String: Any]]
        pre.insert(["matcher": "Bash", "hooks": [["type": "command", "command": "echo bash"]]], at: 0)
        hooks["PreToolUse"] = pre
        root["hooks"] = hooks
        let mixed = try JSONSerialization.data(withJSONObject: root)
        let disabled = try ClaudeHookSettingsMerge.disable(settingsJSON: mixed)
        let out = try XCTUnwrap(JSONSerialization.jsonObject(with: disabled) as? [String: Any])
        let outHooks = try XCTUnwrap(out["hooks"] as? [String: Any])
        XCTAssertEqual(command(in: outHooks, event: "UserPromptSubmit"), brainrot)
        XCTAssertEqual(command(in: outHooks, event: "Stop"), brainrot)
        XCTAssertEqual(command(in: outHooks, event: "StopFailure"), brainrot)
        let leftover = try XCTUnwrap(outHooks["PreToolUse"] as? [[String: Any]])
        XCTAssertEqual(leftover.count, 1)
        XCTAssertEqual(leftover.first?["matcher"] as? String, "Bash")
        XCTAssertFalse(String(data: disabled, encoding: .utf8)!.contains("--claude-question-hook"))
    }

    func testEnableIsIdempotentAndInvalidJSONIsRejected() throws {
        let command = "/tmp/Agrypnos --claude-question-hook"
        let once = try ClaudeHookSettingsMerge.enable(settingsJSON: existing, command: command, timeoutSeconds: 630)
        let twice = try ClaudeHookSettingsMerge.enable(settingsJSON: once, command: command, timeoutSeconds: 630)
        let hooks = try XCTUnwrap((JSONSerialization.jsonObject(with: twice) as? [String: Any])?["hooks"] as? [String: Any])
        let pre = try XCTUnwrap(hooks["PreToolUse"] as? [[String: Any]])
        XCTAssertEqual(pre.filter { $0["matcher"] as? String == "AskUserQuestion" }.count, 1)
        XCTAssertThrowsError(try ClaudeHookSettingsMerge.enable(settingsJSON: Data("not-json".utf8),
            command: command, timeoutSeconds: 630))
        XCTAssertThrowsError(try ClaudeHookSettingsMerge.disable(settingsJSON: Data("{".utf8)))
    }

    func testMissingClaudeHookPreferenceDefaultsOff() throws {
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(UserPreferences())) as! [String: Any]
        object.removeValue(forKey: "claudeQuestionHookEnabled")
        let decoded = try JSONDecoder().decode(UserPreferences.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertFalse(decoded.claudeQuestionHookEnabled)
        XCTAssertFalse(UserPreferences().claudeQuestionHookEnabled)
        var on = decoded
        on.claudeQuestionHookEnabled = true
        XCTAssertTrue(try JSONDecoder().decode(UserPreferences.self, from: JSONEncoder().encode(on)).claudeQuestionHookEnabled)
    }

    private func command(in hooks: [String: Any], event: String) -> String? {
        let groups = hooks[event] as? [[String: Any]]
        let hooks = groups?.first?["hooks"] as? [[String: Any]]
        return hooks?.first?["command"] as? String
    }
}
```

- [x] **Step 2: Run merge test to verify it fails**

Run: `swift test --filter ClaudeHookSettingsMergeTests.testEnableKeepsBrainrotAndAddsAskUserQuestionMatcher`

Expected: FAIL with `cannot find 'ClaudeHookSettingsMerge' in scope`

- [x] **Step 3: Implement merge, prefs, chrome, button, file IO**

`ClaudeHookSettingsMerge.swift`:

```swift
import Foundation

public enum ClaudeHookSettingsMerge {
    public enum Error: Swift.Error { case unsupportedSettings }

    public static func enable(settingsJSON: Data, command: String, timeoutSeconds: Int) throws -> Data {
        var root = try object(settingsJSON)
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        if root["hooks"] != nil, root["hooks"] is [String: Any] == false { throw Error.unsupportedSettings }
        var pre = groups(hooks["PreToolUse"])
        pre = stripped(pre)
        pre.append([
            "matcher": "AskUserQuestion",
            "hooks": [[
                "type": "command",
                "command": command,
                "timeout": timeoutSeconds
            ]]
        ])
        hooks["PreToolUse"] = pre
        root["hooks"] = hooks
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    }

    public static func disable(settingsJSON: Data) throws -> Data {
        var root = try object(settingsJSON)
        guard var hooks = root["hooks"] as? [String: Any] else { return settingsJSON }
        var pre = stripped(groups(hooks["PreToolUse"]))
        if pre.isEmpty { hooks.removeValue(forKey: "PreToolUse") } else { hooks["PreToolUse"] = pre }
        root["hooks"] = hooks
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    }

    private static func object(_ data: Data) throws -> [String: Any] {
        guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Error.unsupportedSettings
        }
        return parsed
    }

    private static func groups(_ value: Any?) -> [[String: Any]] {
        value as? [[String: Any]] ?? []
    }

    private static func stripped(_ groups: [[String: Any]]) -> [[String: Any]] {
        groups.compactMap { group in
            let hooks = (group["hooks"] as? [[String: Any]] ?? []).filter { hook in
                !isAgrypnos(hook["command"] as? String)
            }
            if hooks.isEmpty { return nil }
            var next = group
            next["hooks"] = hooks
            return next
        }
    }

    private static func isAgrypnos(_ command: String?) -> Bool {
        guard let command else { return false }
        return command.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            .contains(ClaudeAskUserQuestionPayload.flag)
    }
}
```

Empty groups after removing `--claude-question-hook` are dropped. A Bash (or any other) matcher group that still has commands is kept. Brainrot events are not in `PreToolUse`, so `stripped` never sees them.

`UserPreferences`: add `public var claudeQuestionHookEnabled: Bool` immediately after `openCodePluginEnabled`. Init parameter `claudeQuestionHookEnabled: Bool = false`. `CodingKeys.claudeQuestionHookEnabled`. Decode: `try container.decodeIfPresent(Bool.self, forKey: .claudeQuestionHookEnabled) ?? false`. Encode the new key.

`PopoverCard`: add `case claudeHook` after `pluginConnection`. Notif `cards`:

```swift
.questionRelay, .pluginConnection, .claudeHook, .openCodeQuestions, .notifSetup, .notifClear,
```

`PopoverStackLayout`: add `public let claudeHook: PopoverSlot?`, `case .claudeHook: return claudeHook`, `case .claudeHook: return QuestionSetupChrome.claudeCardHeight`, and pass `claudeHook: placed[.claudeHook]` into the `PopoverStackLayout(...)` initializer.

Update every test that lists the 10 notif cards to 11 with `.claudeHook` after `.pluginConnection`. Compact stacked-cards counts that skipped `.openCodeQuestions` go from 9 to 10 (`DiscordInboundPopoverChromeTests`: `XCTAssertEqual(layout.stackedCards.count, 10)`). `TelegramInboundPopoverChromeTests`: `XCTAssertEqual(PopoverSection.notif.cards.count, 11)`.

`QuestionRelayLayoutTests.testQuestionSetupFitsItsCardsAndAppearsOnlyInNotif` after insert:

```swift
XCTAssertEqual(layout.pluginConnection?.y, forwarding.maxY + 10)
XCTAssertEqual(layout.claudeHook?.y, layout.pluginConnection!.maxY + 10)
XCTAssertEqual(connection.y, layout.claudeHook!.maxY + 10)
XCTAssertEqual(layout.notifSetup?.y, connection.maxY + 10)
```

Notif / Telegram / Discord chrome tests that used `layout.notifSetup?.y == layout.pluginConnection!.maxY + cardGap` in the compact layout (manual OpenCode collapsed) must become `layout.notifSetup?.y == layout.claudeHook!.maxY + PopoverStackLayout.cardGap`. Pass `layout.claudeHook` into `compactYs(...)` after `pluginConnection`.

`PopoverController+ClaudeHook.swift` mirrors OpenCode's button construction, not the TUI plugin:

```swift
extension PopoverController {
    func addClaudeHookCard(_ card: CardView, ci: CGFloat, cw: CGFloat) {
        addPrefTitle("Claude Code forwarding", in: card, ci: ci, width: cw)
        _ = PopoverForm.help(QuestionSetupChrome.claudeHelp, in: card, y: 36, x: ci, width: cw, lines: 3)
        claudeEnableButton = setupClaudeButton(QuestionSetupChrome.claudeEnableTitle,
            action: #selector(enableClaudeHook), in: card, x: ci, y: 88)
        claudeDisableButton = setupClaudeButton("Disable", action: #selector(disableClaudeHook), in: card, x: ci, y: 116)
        claudeDisableButton.setAccessibilityLabel("Disable Claude Code forwarding")
        claudeEnableButton.setAccessibilityHelp(QuestionSetupChrome.claudeHelp)
        claudeHookStatus = PopoverForm.help("", in: card, y: 144, x: ci, width: cw, lines: 2)
    }
    private func setupClaudeButton(_ title: String, action: Selector, in card: CardView, x: CGFloat, y: CGFloat) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded; button.controlSize = .small; button.sizeToFit()
        button.frame.origin = NSPoint(x: x, y: y); card.addSubview(button); return button
    }
    @objc func enableClaudeHook() {
        stopRecordingIfNeeded(); commitNotifFields()
        Task { [weak self] in
            guard let self, let runtime else { return }
            _ = await runtime.enableClaudeQuestionHook(); refresh()
        }
    }
    @objc func disableClaudeHook() { runtime?.disableClaudeQuestionHook(); refresh() }
}
```

Do not add Remove integration or Manual server connection on this card.

`PopoverController.swift` stored properties, next to the OpenCode buttons:

```swift
    var claudeHookCard: CardView!
    var claudeEnableButton: NSButton!
    var claudeDisableButton: NSButton!
    var claudeHookStatus: NSTextField!
```

In `PopoverController+Canvas.swift`, immediately after `addOpenCodePluginCard(openCodePluginCard, ci: ci, cw: cw)`:

```swift
        claudeHookCard = PopoverForm.card(in: document, slot: notif.claudeHook!, pad: pad, width: contentW)
        addClaudeHookCard(claudeHookCard, ci: ci, cw: cw)
```

In `applyCardSlots`, immediately after the `openCodePluginCard` apply:

```swift
        PopoverForm.apply(claudeHookCard, slot: layout.claudeHook, pad: pad, width: width)
```

On `WatchRuntime` add only these stored properties (no merge logic in that file): `var claudeSetupFailure: String?`, `var claudeSettingsURLOverride: URL?`, `var claudeHookSocketURLOverride: URL?`. Add `claudeQuestionHookSource` in Task 5 when the type exists.

`WatchRuntime+ClaudeHook.swift` (merge + prefs now; listener start is Task 5):

```swift
extension WatchRuntime {
    var claudeSettingsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/settings.json")
    }
    var claudeQuestionCaption: String {
        if let failure = claudeSetupFailure { return failure }
        if !preferences.forwardAgentQuestions { return "Claude Code: forwarding off." }
        if !preferences.includedAgentKinds.contains(.claudeCode) { return "Claude Code: select it in Agents first." }
        let relay = questionRelaySettings()
        if relay.telegram?.isComplete != true && relay.discord?.isComplete != true {
            return "Claude Code: enable bot inbound and save its answering user ID."
        }
        if preferences.claudeQuestionHookEnabled {
            return "Claude Code: hook installed. Interactive sessions hold hooks until you trust the folder."
        }
        return "Claude Code: click Enable Claude Code forwarding."
    }
    private var claudeSetupPrerequisite: String? {
        if questionSourcesTerminated || questionSourcesSuspended { return "Claude Code: forwarding is paused." }
        if !preferences.includedAgentKinds.contains(.claudeCode) { return "Claude Code: select it in Agents first." }
        let relay = questionRelaySettings()
        if relay.telegram?.isComplete != true && relay.discord?.isComplete != true {
            return "Claude Code: enable bot inbound and save its answering user ID."
        }
        return nil
    }
    private func claudeSetupFailed(_ text: String) -> Bool {
        claudeSetupFailure = text; notify(text); delegate?.watchRuntimeDidChange(self); return false
    }
    private func writeClaudeSettings(_ data: Data, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let temp = directory.appendingPathComponent(url.lastPathComponent + ".tmp")
        try data.write(to: temp, options: .atomic)
        _ = try FileManager.default.replaceItemAt(url, withItemAt: temp)
    }
    func enableClaudeQuestionHook() async -> Bool {
        if let reason = claudeSetupPrerequisite { return claudeSetupFailed(reason) }
        do {
            let executable = Bundle.main.executableURL?.path ?? CommandLine.arguments[0]
            let quoted = executable.contains(" ") ? "\"\(executable)\"" : executable
            let command = quoted + " " + ClaudeAskUserQuestionPayload.flag
            let url = claudeSettingsURLOverride ?? claudeSettingsURL
            let existing = (try? Data(contentsOf: url)) ?? Data("{}".utf8)
            let merged = try ClaudeHookSettingsMerge.enable(settingsJSON: existing, command: command,
                timeoutSeconds: ClaudeAskUserQuestionPayload.commandTimeoutSeconds)
            try writeClaudeSettings(merged, to: url)
            engine.preferences.claudeQuestionHookEnabled = true
            engine.preferences.forwardAgentQuestions = true
            claudeSetupFailure = nil
            store.save(engine.preferences)
            questionRelay.refreshSettings()
            syncQuestionSources()
            delegate?.watchRuntimeDidChange(self)
            return true
        } catch {
            return claudeSetupFailed("Claude Code: couldn't merge ~/.claude/settings.json. Existing hooks were left as they were.")
        }
    }
    func disableClaudeQuestionHook() {
        let url = claudeSettingsURLOverride ?? claudeSettingsURL
        if let existing = try? Data(contentsOf: url),
           let stripped = try? ClaudeHookSettingsMerge.disable(settingsJSON: existing) {
            try? writeClaudeSettings(stripped, to: url)
        }
        engine.preferences.claudeQuestionHookEnabled = false
        claudeSetupFailure = nil
        store.save(engine.preferences)
        questionRelay.refreshSettings()
        syncQuestionSources()
        delegate?.watchRuntimeDidChange(self)
    }
}
```

If `enable` throws after a failed merge, `writeClaudeSettings` is not called, so the original file bytes stay. Disable does **not** call `setForwardAgentQuestions(false)` (that would also stop OpenCode). It removes only the Agrypnos hook entry. Do not call `stopClaudeQuestionHook()` until Task 5 creates that method.

`refreshQuestionChrome` additions:

```swift
        claudeHookStatus?.stringValue = runtime.claudeQuestionCaption
        let claudeOn = runtime.preferences.claudeQuestionHookEnabled && runtime.preferences.forwardAgentQuestions
        claudeEnableButton?.isEnabled = !claudeOn
        claudeDisableButton?.isEnabled = runtime.preferences.claudeQuestionHookEnabled
```

Insert this step in `BotGuide.questionSetup` after the OpenCode enable step (keep the OpenCode steps):

```swift
BotGuideStep("Enable Claude Code forwarding",
    "Select Claude Code in Agents, then click Enable Claude Code forwarding in Notif. Agrypnos merges a PreToolUse AskUserQuestion hook into ~/.claude/settings.json and keeps your other hooks, including UserPromptSubmit / Stop / StopFailure. Interactive sessions hold hooks until you trust the folder. Ask a structured choice in that same Claude Code session and answer on your bot."),
```

Insert this README section after the OpenCode forwarding section:

```markdown
## Claude Code question forwarding (test build)

One click merges a `PreToolUse` hook matching `AskUserQuestion` into
`~/.claude/settings.json`. It does not replace that file. Existing
`UserPromptSubmit` / `Stop` / `StopFailure` hooks (including
`~/.brainrot/brainrot-state.sh` on this Mac) stay. Interactive Claude Code
sessions hold hooks until you trust the folder.

1. Configure your own Telegram or Discord bot, turn its inbound switch on, and
   save your answering user ID under Notif → Forward agent questions.
2. Select **Claude Code** in Agents. Click **Enable Claude Code forwarding**.
3. In an already-trusted project, ask Claude Code a structured choice in the
   session you already started. Answer on your bot. That same session should
   continue with the chosen label.

Live AskUserQuestion round-trip on Claude Code 2.1.183 is not proven until
you run that check. Cursor and Codex question forwarding remain unavailable.
Disable removes only the Agrypnos `--claude-question-hook` entry.
```

Insert this SECURITY.md section after the OpenCode forwarding section (do not delete the OpenCode section; change “Only OpenCode 1.18.32 is enabled in this test build” there to “OpenCode 1.18.32 remains enabled in this test build. Claude Code question forwarding is the hook path below.”):

```markdown
## Opt-in Claude Code question forwarding (test build)

Enable Claude Code forwarding merges a command hook into
`~/.claude/settings.json`. It never replaces the file and never deletes
other hook events. The command is this app with `--claude-question-hook`.
The helper talks to the running menu-bar app on a Unix socket under
`~/Library/Application Support/Agrypnos/claude-question-hook/` (directory
0700, socket 0600, same-UID peer). It does not spawn a second Claude, open a
listen port, or set a Discord Interactions Endpoint URL. If Agrypnos is not
running, the helper returns empty JSON within two seconds and does not select
an answer. No new sudoers grant. The Discord webhook stays outbound-only.
```

Create `Tests/AgrypnosMacTests/ClaudeHookRuntimeTests.swift`:

```swift
import Foundation
import XCTest
import AgrypnosCore
@testable import AgrypnosMac

@MainActor
final class ClaudeHookRuntimeTests: XCTestCase {
    func testEnableMergesAskUserQuestionAndKeepsBrainrot() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let settings = root.appendingPathComponent("settings.json")
        let brainrot = Data(#"""
        {"hooks":{"UserPromptSubmit":[{"hooks":[{"type":"command","command":"/Users/test/.brainrot/brainrot-state.sh"}]}],"Stop":[{"hooks":[{"type":"command","command":"/Users/test/.brainrot/brainrot-state.sh"}]}],"StopFailure":[{"hooks":[{"type":"command","command":"/Users/test/.brainrot/brainrot-state.sh"}]}]}}
        """#.utf8)
        try brainrot.write(to: settings)
        let defaults = UserDefaults(suiteName: "ag-claude-hook-" + UUID().uuidString)!
        let runtime = WatchRuntime(store: PreferencesStore(defaults: defaults), readLid: { false },
            readKernel: { .clear }, setKernel: { _ in XCTFail("must not arm"); return .ok },
            runCommand: { _, _ in XCTFail("must not run power command"); return (0, "", "") },
            notify: { _ in },
            readNotifSecrets: {
                NotifSecrets(telegramBotToken: "fixture", telegramChatId: "9", telegramQuestionUserId: "42")
            })
        runtime.claudeSettingsURLOverride = settings
        runtime.engine.preferences.includedAgentKinds = [.claudeCode]
        runtime.engine.preferences.telegramInboundEnabled = true
        XCTAssertFalse(runtime.engaged)
        let enabled = await runtime.enableClaudeQuestionHook()
        XCTAssertTrue(enabled)
        XCTAssertTrue(runtime.preferences.claudeQuestionHookEnabled)
        XCTAssertTrue(runtime.preferences.forwardAgentQuestions)
        XCTAssertFalse(runtime.engaged)
        let merged = try JSONSerialization.jsonObject(with: Data(contentsOf: settings)) as! [String: Any]
        let hooks = merged["hooks"] as! [String: Any]
        XCTAssertEqual(((hooks["Stop"] as? [[String: Any]])?.first?["hooks"] as? [[String: Any]])?.first?["command"] as? String,
            "/Users/test/.brainrot/brainrot-state.sh")
        XCTAssertTrue(String(data: try Data(contentsOf: settings), encoding: .utf8)!.contains("--claude-question-hook"))
        runtime.disableClaudeQuestionHook()
        XCTAssertFalse(runtime.preferences.claudeQuestionHookEnabled)
        let disabled = String(data: try Data(contentsOf: settings), encoding: .utf8)!
        XCTAssertFalse(disabled.contains("--claude-question-hook"))
        XCTAssertTrue(disabled.contains("brainrot-state.sh"))
    }
}
```

This test uses `claudeSettingsURLOverride` and injected `NotifSecrets`. It must not read or write `~/.claude/settings.json` or Application Support `notif-secrets.json`.

pbxproj IDs:

- `E6C13029D4FA6B3C108E5D72` / `F7D2413AE50B7C4D219F6E83` — `WatchRuntime+ClaudeHook.swift` in Questions
- `2A05746D183EAF7054C291B6` / `3B16857E294FB08165D3A2C7` — `PopoverController+ClaudeHook.swift` in MenuBar

- [x] **Step 4: Run Linux tests**

Run: `swift test --filter ClaudeHookSettingsMergeTests`

Run: `swift test --filter QuestionRelayLayoutTests`

Run: `swift test --filter NotifPopoverChromeTests.testNotifSectionCardsAreEnableDiscordTelegramInboundSetupAndClear`

Run: `swift test --filter BotGuideCopyTests`

Expected: PASS. Add to `testEveryStepIsFilledAndImagesAndLinksAreWellFormed` or a new method:

```swift
    func testClaudeHookSetupNamesTrustAndKeepsBrainrotHonesty() {
        let text = BotGuide.allText
        XCTAssertTrue(text.contains("Enable Claude Code forwarding"))
        XCTAssertTrue(text.lowercased().contains("trust the folder"))
        XCTAssertTrue(text.contains("PreToolUse"))
        XCTAssertTrue(text.contains("AskUserQuestion"))
        XCTAssertTrue(text.contains("UserPromptSubmit"))
        XCTAssertTrue(text.contains("brainrot") || text.contains("other hooks"))
        XCTAssertTrue(text.contains("Enable OpenCode forwarding"))
    }
```

Run: `bash Scripts/check-file-sizes.sh`

Expected: PASS; all tracked files ≤ 600 lines

Then on Mac: `swift test --filter ClaudeHookRuntimeTests` with a temp settings JSON that already contains the three brainrot events. Assert they survive enable and disable. Assert the user's real `~/.claude/settings.json` is not opened (override URL only).

- [x] **Step 5: Commit**

```bash
git add Sources/AgrypnosCore/Questions/ClaudeHookSettingsMerge.swift \
  Tests/AgrypnosCoreTests/ClaudeHookSettingsMergeTests.swift \
  Sources/AgrypnosCore/Session/UserPreferences.swift \
  Sources/AgrypnosCore/Copy/QuestionSetupChrome.swift \
  Sources/AgrypnosCore/Copy/PopoverSection.swift \
  Sources/AgrypnosCore/Copy/PopoverStackLayout.swift \
  Sources/AgrypnosCore/Copy/BotGuideCopy.swift \
  Apps/Agrypnos/Sources/MenuBar/PopoverController+ClaudeHook.swift \
  Apps/Agrypnos/Sources/MenuBar/PopoverController.swift \
  Apps/Agrypnos/Sources/MenuBar/PopoverController+Canvas.swift \
  Apps/Agrypnos/Sources/MenuBar/PopoverController+Sections.swift \
  Apps/Agrypnos/Sources/MenuBar/PopoverController+Questions.swift \
  Apps/Agrypnos/Sources/Questions/WatchRuntime+ClaudeHook.swift \
  Apps/Agrypnos/Agrypnos.xcodeproj/project.pbxproj \
  Tests/AgrypnosCoreTests/NotifPopoverChromeTests.swift \
  Tests/AgrypnosCoreTests/TelegramInboundPopoverChromeTests.swift \
  Tests/AgrypnosCoreTests/DiscordInboundPopoverChromeTests.swift \
  Tests/AgrypnosCoreTests/PopoverSectionTests.swift \
  Tests/AgrypnosCoreTests/QuestionRelayLayoutTests.swift \
  Tests/AgrypnosMacTests/ClaudeHookRuntimeTests.swift \
  README.md SECURITY.md
git commit -m "$(cat <<'EOF'
Add a Claude forwarding button that merges settings without dropping other hooks.

EOF
)"
```

---

### Task 5: Wire receive() with .claudeCode and .returnedToHook

**Files:**
- Create: `Apps/Agrypnos/Sources/Questions/ClaudeQuestionHookSource.swift`
- Modify: `Apps/Agrypnos/Sources/Questions/WatchRuntime+ClaudeHook.swift`
- Modify: `Apps/Agrypnos/Sources/Questions/WatchRuntime+OpenCodeQuestions.swift`
- Modify: `Apps/Agrypnos/Agrypnos.xcodeproj/project.pbxproj` (`ClaudeQuestionHookSource.swift`, IDs `08E3524BF61C8D5E32A07F94` fileRef / `19F4635C072D9E6F43B180A5` build)
- Modify: `Tests/AgrypnosMacTests/ClaudeHookRuntimeTests.swift`

**Interfaces:**
- Consumes: `QuestionRelayCoordinator.receive(_ batch:submit:returnLocal:) -> Bool`, `ClaudeAskUserQuestionPayload.decode`, `stdout`, `nativeFallback`, `QuestionDelivery.returnedToHook`
- Produces: `ClaudeQuestionHookSource.start()/stop()` listening on `ClaudeAskUserQuestionPayload.defaultSocketURL()` (or the runtime override); `WatchRuntime.syncClaudeQuestionHook()`

Do not start a second Telegram poller or Discord Gateway. Do not call OpenCode HTTP or the TUI plugin from this source.

- [x] **Step 1: Write the failing Mac test for receive wiring**

Add to `ClaudeHookRuntimeTests.swift`:

```swift
    func testHookStdinReachesReceiveAsClaudeCodeAndSubmitReturnsReturnedToHook() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ag-claude-src-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let sock = dir.appendingPathComponent("hook.sock")
        defer { try? FileManager.default.removeItem(at: dir) }
        let stdin = Data(#"""
        {"session_id":"sess_live","cwd":"/Users/test/project","hook_event_name":"PreToolUse","tool_name":"AskUserQuestion","tool_use_id":"toolu_live","tool_input":{"questions":[{"question":"Pick B?","header":"Pick","options":[{"label":"A","description":"no"},{"label":"B","description":"yes"}],"multiSelect":false}]}}
        """#.utf8)
        let submitted = expectation(description: "returnedToHook")
        let source = ClaudeQuestionHookSource(socketURL: sock, uptime: { 1000 }, receive: { batch, submit, _ in
            XCTAssertEqual(batch.key.provider, .claudeCode)
            XCTAssertEqual(batch.questions[0].options.map(\.label), ["A", "B"])
            Task { @MainActor in
                let delivery = await submit(QuestionAnswer(key: batch.key, selections: [
                    QuestionSelection(questionID: "Pick B?", optionIDs: ["B"])
                ]))
                XCTAssertEqual(delivery, .returnedToHook)
                submitted.fulfill()
            }
            return true
        })
        try source.start()
        defer { source.stop() }
        let reply = try await Task.detached {
            try ClaudeQuestionHookProcess.exchange(stdin, socketURL: sock, connectTimeout: 2)
        }.value
        await fulfillment(of: [submitted], timeout: 5)
        XCTAssertTrue(ClaudeAskUserQuestionPayload.isSufficientAskUserQuestionOutput(reply))
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: reply) as? [String: Any])
        let answers = ((root["hookSpecificOutput"] as? [String: Any])?["updatedInput"] as? [String: Any])?["answers"] as? [String: String]
        XCTAssertEqual(answers, ["Pick B?": "B"])
    }

    func testMissingSocketIsNativeFallbackWithinTwoSeconds() {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("agrypnos-claude-missing.sock")
        let started = Date()
        XCTAssertThrowsError(try ClaudeQuestionHookProcess.exchange(Data("{}".utf8), socketURL: missing, connectTimeout: 2))
        XCTAssertLessThan(Date().timeIntervalSince(started), 3)
        let out = ClaudeAskUserQuestionPayload.helperStdout(stdin: Data(#"""
        {"session_id":"s","cwd":"/p","hook_event_name":"PreToolUse","tool_name":"AskUserQuestion","tool_use_id":"t","tool_input":{"questions":[{"question":"Q?","header":"Q","options":[{"label":"A","description":"a"},{"label":"B","description":"b"}],"multiSelect":false}]}}
        """#.utf8)) { _ in throw ClaudeAskUserQuestionPayload.Error.invalidRequest }
        XCTAssertEqual(out, ClaudeAskUserQuestionPayload.nativeFallback)
    }
```

`ClaudeQuestionHookSource` receive type: `@MainActor (QuestionBatch, @escaping @MainActor (QuestionAnswer) async -> QuestionDelivery, @escaping @MainActor () async -> Void) -> Bool`. Production `WatchRuntime.syncClaudeQuestionHook` passes `{ [weak self] batch, submit, local in self?.questionRelay.receive(batch, submit: submit, returnLocal: local) ?? false }`.

- [x] **Step 2: Run test to verify it fails**

Run: `swift test --filter ClaudeHookRuntimeTests.testHookStdinReachesReceiveAsClaudeCodeAndSubmitReturnsReturnedToHook`

Expected: FAIL (`ClaudeQuestionHookSource` not found, or `claudeQuestionHookSource` nil because Task 4 enable did not start a listener)

- [x] **Step 3: Implement the listener and split sync**

Add `var claudeQuestionHookSource: ClaudeQuestionHookSource?` on `WatchRuntime`.

`stopClaudeQuestionHook` and the disable call:

```swift
    func stopClaudeQuestionHook() {
        claudeQuestionHookSource?.stop()
        claudeQuestionHookSource = nil
    }
```

Call `stopClaudeQuestionHook()` at the start of `disableClaudeQuestionHook()` after the settings merge.

`ClaudeQuestionHookSource.swift`:

```swift
import Foundation
import Darwin
#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

@MainActor
final class ClaudeQuestionHookSource {
    typealias Submit = @MainActor (QuestionAnswer) async -> QuestionDelivery
    typealias ReturnLocal = @MainActor () async -> Void
    typealias Receive = @MainActor (QuestionBatch, @escaping Submit, @escaping ReturnLocal) -> Bool
    private let socketURL: URL
    private let uptime: () -> TimeInterval
    private let receive: Receive
    private var listener: DispatchSourceRead?
    private var bound = false
    init(socketURL: URL, uptime: @escaping () -> TimeInterval, receive: @escaping Receive) {
        self.socketURL = socketURL; self.uptime = uptime; self.receive = receive
    }
    func start() throws {
        close(try OpenCodePrivateFiles.directory(socketURL.deletingLastPathComponent(), privateOnly: true))
        var info = stat()
        if lstat(socketURL.path, &info) == 0 {
            guard (info.st_mode & S_IFMT) == S_IFSOCK, info.st_uid == getuid() else {
                throw ClaudeAskUserQuestionPayload.Error.invalidRequest
            }
            unlink(socketURL.path)
        }
        var address = sockaddr_un()
        let path = Array(socketURL.path.utf8) + [0]
        guard path.count <= MemoryLayout.size(ofValue: address.sun_path) else {
            throw ClaudeAskUserQuestionPayload.Error.invalidRequest
        }
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: path) }
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw ClaudeAskUserQuestionPayload.Error.invalidRequest }
        var ok = false
        defer { if !ok { close(fd); if bound { unlink(socketURL.path); bound = false } } }
        let bindOK = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindOK == 0 else { throw ClaudeAskUserQuestionPayload.Error.invalidRequest }
        bound = true
        guard chmod(socketURL.path, 0o600) == 0, listen(fd, 8) == 0 else {
            throw ClaudeAskUserQuestionPayload.Error.invalidRequest
        }
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .main)
        source.setEventHandler { [weak self] in self?.accept(fd) }
        source.setCancelHandler { close(fd) }
        listener = source; source.resume(); ok = true
    }
    private func accept(_ listenerFD: Int32) {
        let client = Darwin.accept(listenerFD, nil, nil)
        guard client >= 0 else { return }
        var uid = uid_t(), gid = gid_t()
        guard getpeereid(client, &uid, &gid) == 0, uid == getuid() else { close(client); return }
        Task { @MainActor in await self.serve(client) }
    }
    private func serve(_ fd: Int32) async {
        defer { close(fd) }
        var stdin = Data()
        var buffer = [UInt8](repeating: 0, count: 8192)
        while true {
            let n = Darwin.read(fd, &buffer, buffer.count)
            if n == 0 { break }
            guard n > 0 else { return }
            stdin.append(buffer, count: n)
            guard stdin.count <= 256 * 1024 else { return }
        }
        guard let batch = try? ClaudeAskUserQuestionPayload.decode(stdin, receivedUptime: uptime()) else {
            _ = Darwin.write(fd, (ClaudeAskUserQuestionPayload.nativeFallback as NSData).bytes,
                ClaudeAskUserQuestionPayload.nativeFallback.count)
            return
        }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            let submitted = receive(batch, { answer in
                let body = (try? ClaudeAskUserQuestionPayload.stdout(original: stdin, answer: answer))
                    ?? ClaudeAskUserQuestionPayload.nativeFallback
                _ = body.withUnsafeBytes { Darwin.write(fd, $0.baseAddress!, body.count) }
                cont.resume()
                return .returnedToHook
            }, {
                let body = ClaudeAskUserQuestionPayload.nativeFallback
                _ = body.withUnsafeBytes { Darwin.write(fd, $0.baseAddress!, body.count) }
                cont.resume()
            })
            if !submitted {
                let body = ClaudeAskUserQuestionPayload.nativeFallback
                _ = body.withUnsafeBytes { Darwin.write(fd, $0.baseAddress!, body.count) }
                cont.resume()
            }
        }
    }
    func stop() {
        listener?.cancel(); listener = nil
        if bound { unlink(socketURL.path); bound = false }
    }
}
```

Resume `serve` at most once (track a `Bool` if both submit and returnLocal could fire). `expireDueQuestions` calls `returnLocal` at 600 seconds; that writes `{}` and does not select an answer.

Keep this file under 250 lines. Do not copy `OpenCodeBridgeMessage` frames or tokens. Reuse `OpenCodePrivateFiles.directory` only for the 0700 parent.

`expireDueQuestions` already calls `returnLocal` at the 600-second deadline. That is the spec's unanswered path: native fallback, no selected answer. Do not add a second timer.

Replace `WatchRuntime.syncQuestionSources()` and the OpenCode stop path in `WatchRuntime+OpenCodeQuestions.swift` with:

```swift
    func syncQuestionSources() {
        guard !openCodeSetupInProgress else { return }
        syncOpenCodeQuestionSources()
        syncClaudeQuestionHook()
    }

    func syncOpenCodeQuestionSources() {
        let relay = questionRelaySettings()
        let settings = readNotifSecrets().openCodeQuestions
        guard !questionSourcesSuspended, !questionSourcesTerminated, relay.enabled,
              relay.includedKinds.contains(.openCode),
              relay.telegram?.isComplete == true || relay.discord?.isComplete == true else {
            stopOpenCodeQuestionSources(); return
        }
        if preferences.openCodePluginEnabled { syncOpenCodePlugin(relay: relay); return }
        guard let settings else { stopOpenCodeQuestionSources(); return }
        guard let configuration = try? OpenCodeQuestionConfiguration(settings) else {
            stopOpenCodeQuestionSources()
            openCodeQuestionState = .unavailable("Use http://127.0.0.1:PORT and an absolute project directory.")
            return
        }
        if openCodeSourceSettings == settings, openCodeRelaySettings == relay,
           openCodeQuestionSource != nil { return }
        stopOpenCodeQuestionSources()
        questionRelay.refreshSettings()
        openCodeSourceSettings = settings
        openCodeRelaySettings = relay
        let source = OpenCodeQuestionSource(configuration: configuration,
            exchange: openCodeQuestionExchange, streamSession: openCodeQuestionStreamSession,
            uptime: { [weak self] in self?.questionUptime() ?? 0 },
            receive: { [weak self] batch in
                guard let self, let source = self.openCodeQuestionSource else { return false }
                return self.questionRelay.receive(batch, submit: { [weak source] answer in
                    guard let source else { return .rejected }
                    return await source.submit(key: batch.key, answer: answer)
                }, returnLocal: { [weak source] in source?.returnToLocal(key: batch.key) })
            }, resolved: { [weak self] key in
                self?.questionRelay.cancel(key: key)
                self?.questionRelayDidChange(.cleared(key))
            }, stateChanged: { [weak self] state in
                self?.openCodeQuestionState = state
                if let self { self.delegate?.watchRuntimeDidChange(self) }
            })
        openCodeQuestionSource = source
        source.start()
    }

    func stopOpenCodeQuestionSources() {
        openCodeSetupRevision &+= 1
        stopOpenCodePlugin()
        let source = openCodeQuestionSource
        openCodeQuestionSource = nil
        openCodeSourceSettings = nil
        openCodeRelaySettings = nil
        source?.stop()
        openCodeQuestionState = .stopped
    }

    func stopQuestionSources() {
        stopOpenCodeQuestionSources()
        stopClaudeQuestionHook()
    }
```

When OpenCode is not selected, `stopOpenCodeQuestionSources()` runs. That must not stop the Claude listener. `stopQuestionSources()` still stops both (sleep, quit).

`syncClaudeQuestionHook()`:

```swift
    func syncClaudeQuestionHook() {
        let relay = questionRelaySettings()
        let want = !questionSourcesSuspended && !questionSourcesTerminated
            && relay.enabled
            && preferences.claudeQuestionHookEnabled
            && relay.includedKinds.contains(.claudeCode)
            && (relay.telegram?.isComplete == true || relay.discord?.isComplete == true)
        if !want {
            stopClaudeQuestionHook()
            return
        }
        if claudeQuestionHookSource != nil { return }
        let source = ClaudeQuestionHookSource(
            socketURL: claudeHookSocketURLOverride ?? ClaudeAskUserQuestionPayload.defaultSocketURL(),
            uptime: { [weak self] in self?.questionUptime() ?? 0 },
            receive: { [weak self] batch, submit, local in
                self?.questionRelay.receive(batch, submit: submit, returnLocal: local) ?? false
            })
        do { try source.start(); claudeQuestionHookSource = source }
        catch { claudeSetupFailure = "Claude Code: couldn't listen for the question hook." }
    }
```

`stopQuestionSources()` still stops both OpenCode and Claude (sleep, quit, invalidate). `stopClaudeQuestionHook()` is the Claude-only stop used when Claude is not wanted.

Do not extend `DiscordQuestionMessage.canRender` unless a test shows a Claude batch cannot publish in `.pending`. Initial publish uses `.pending`; `.returnedToHook` footer already exists on `QuestionMessageText.render`.

- [x] **Step 4: Run tests**

Run: `swift test --filter ClaudeAskUserQuestionPayloadTests`

Run: `swift test --filter ClaudeHookSettingsMergeTests`

Run: `swift test --filter ClaudeHookRuntimeTests`

Run: `bash Scripts/verify-linux.sh` (Linux: Core tests + file sizes)

Expected: PASS. `syncQuestionSources` still starts OpenCode when OpenCode is selected; it also starts the Claude listener when `claudeQuestionHookEnabled` and `.claudeCode` are on.

- [x] **Step 5: Commit**

```bash
git add Apps/Agrypnos/Sources/Questions/ClaudeQuestionHookSource.swift \
  Apps/Agrypnos/Sources/Questions/WatchRuntime+ClaudeHook.swift \
  Apps/Agrypnos/Sources/Questions/WatchRuntime+OpenCodeQuestions.swift \
  Apps/Agrypnos/Agrypnos.xcodeproj/project.pbxproj \
  Tests/AgrypnosMacTests/ClaudeHookRuntimeTests.swift
git commit -m "$(cat <<'EOF'
Forward Claude AskUserQuestion hooks through the existing question relay.

EOF
)"
```

---

### Task 6: Mac optical checklist (human; not Mac-proven)

**Files:**
- None. Do not add a fake XCTest that shells out to `claude` or writes the user's live `~/.claude/settings.json`.

**Interfaces:**
- Consumes: the Enable button, merged user settings, Telegram (or Discord) inbound, an already-trusted Claude Code project
- Produces: a human pass/fail. Until this runs, say **unproven**. Do not write “Mac-proven” in copy, commits, or AGENTS.md.

This Mac: `claude` **2.1.183**. No pending-question file exists. Interactive sessions hold hooks until the folder is trusted. Agrypnos has no `.claude/` project dir.

- [ ] **Step 1: Preconditions (human)**

1. Build and launch the menu-bar app from this branch (not a hook-only `--claude-question-hook` invocation).
2. Select **Claude Code** in Agents (≥1 tool remains selected).
3. Telegram or Discord inbound on, answering user ID saved, **Forward agent questions** will be turned on by Enable.
4. Open a project folder **already trusted** in Claude Code. If trust is pending, accept the workspace trust dialog first; hooks will not run until then.
5. Confirm `~/.claude/settings.json` still has the three brainrot commands (`UserPromptSubmit`, `Stop`, `StopFailure` → `~/.brainrot/brainrot-state.sh`) **before** clicking Enable. Copy the file aside if you want a manual diff.

- [ ] **Step 2: Arm the button**

Click **Enable Claude Code forwarding**. Confirm:

- A `PreToolUse` group with matcher `AskUserQuestion` and command containing `--claude-question-hook` and `"timeout": 630` is present.
- The three brainrot events are **unchanged**.
- Other top-level keys (`permissions`, `model`, plugins, theme) remain.
- Keep the watch did **not** arm.
- Status does not say Mac-proven.

- [ ] **Step 3: Same-session question**

In that already-open trusted Claude Code session (terminal, IDE, or Desktop — the session you started, not `claude -p`, not Agent SDK, not Channels), ask Claude Code to use `AskUserQuestion` with a harmless A/B choice whose B marker is unique (design: choose B through the bot, original session prints/writes that B marker once).

Expect the question on your bot (provider **Claude Code**, session id, full labels). Select B, review, **Send answers**. Footer may say answers were returned to the local hook; that is `.returnedToHook`, not “accepted”.

Expect **that same Claude session** to continue with label B. A new Claude process, a `-p --resume` chat, or a Channels thread is a fail.

- [ ] **Step 4: Native fallback and disable**

- **Answer on Mac** (or do not answer): the helper must not write `answers`; the native Claude card should remain available. Do not wait on a timeout you invented; the 600s batch deadline / 630s hook timeout are already specified.
- Click **Disable**. Forwarding for Claude stops. Only the Agrypnos `--claude-question-hook` entry is gone. Brainrot events remain. OpenCode forwarding is not required to turn off.
- Quit Agrypnos, ask another question: native Claude UI, no bot card (socket gone → helper `{}` within 2s).

- [ ] **Step 5: Record, do not claim**

Write a short human note (optional) of pass/fail and `claude --version`. Until that note exists, Core tests passing is **not** live proof. Do not commit a “Mac-proven” claim.

There is no automated expected output for this task. The implementer stops after providing the checklist; the human runs it.

---

## Self-review

**Spec / notes coverage**

| Requirement | Task |
| --- | --- |
| PreToolUse matcher AskUserQuestion, same session | 3–6 |
| allow + echoed questions + answers map (text → label) | 2, 5 |
| allow alone insufficient | 2, 3 |
| PermissionRequest / Notification / Stop / SDK / Channels / Remote Control not used | Global Constraints; Task 1 rejects PermissionRequest |
| `--claude-question-hook`, 630 / 600 / 2s, native fallback no answers | 3, 5 |
| Unix socket 0700/0600/same-UID, not OpenCodeBridge | 3, 5 |
| `receive` + `.claudeCode` + `.returnedToHook` | 5 |
| One Forward switch, reuse bots/registry/wait/secrets | 4, 5 |
| Merge settings, keep brainrot, disable removes only Agrypnos hook | 4 |
| Workspace trust caption | 4 (`claudeHelp`) |
| One Notif button, no settings window, no second poller | 4, 5 |
| OpenCode one-button meaning (same session) | 6 |
| Linux-testable parse/build/merge | 1, 2, 3 (`helperStdout`), 4 |
| Unproven until human optical | 6 |
| AGENTS.md Model sentence not lifted by this file | Global Constraints |
| Do not copy TUI plugin / HTTP / OpenCode IPC frames | File map |

**Placeholder scan:** no TBD, no “similar to task N”, no “add validation later”. Type names match source: `AgentKind.claudeCode`, `QuestionDelivery.returnedToHook`, `QuestionRelayCoordinator.receive(_ batch:submit:returnLocal:) -> Bool`, flag `--claude-question-hook`.

**Gaps closed inline:** unanswered path uses existing `expireDueQuestions` → `returnLocal` → `{}` (not a new timeout). OpenCode disable still flips the global Forward switch (pre-existing); Claude disable does not. `DiscordQuestionMessage.canRender` unchanged unless pending publish fails. `AGENTS.md` unchanged.
