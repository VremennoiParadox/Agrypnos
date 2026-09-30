# Native question compatibility — execution evidence

Status: **Task 1 blocked; no provider has passed the release gate.** Checked on 2026-09-29 and revalidated on 2026-09-30 on the user's Mac. The user authorized execution and local commits, but no push. Provider-independent relay, bot and watch components (Tasks 2–4 and 9) have since been implemented and tested locally. No native provider adapter or question setup UI is enabled.

This is a capability check, not a finding that native forwarding is impossible in every version. The approved [plan](../superpowers/plans/2026-09-29-native-agent-questions.md) requires access to existing desktop/local conversations for all four providers. An API that creates a separate agent does not meet that gate.

## Installed surfaces and results

| Surface | Observed version | Result |
| --- | --- | --- |
| Cursor desktop | 3.22.12 (Sonnet 5.5 High probe) | BLOCKED ON QUESTION HOOK. A disposable desktop chat rendered a native structured question and consumed a local B answer, but its working project `preToolUse` and `postToolUse` hooks did not fire for that question. No supported answer route was observed. |
| Claude Code CLI | 2.1.183 | BLOCKED ON SIGN-IN. The user has no Claude subscription. A disposable interactive probe reached "Not logged in" before any question or hook event. |
| Claude desktop | 2.7032.0 | NOT TESTED. Desktop hook behavior must be proved separately from a CLI-owned run. |
| Codex desktop surface (now in ChatGPT.app) | 26.928.21956, build 12404 (latest check) | BLOCKED ON ATTACHMENT. Current app-server explicitly uses `--listen stdio://`; canonical control socket candidates remain absent and no TCP listener was found. |
| Bundled Codex CLI | 0.159.2 (latest check) | `app-server proxy` exists and requires a Unix socket; no attachment to the current desktop server was established. |
| OpenCode TUI and official server | 1.18.32 | SAME-CHAT CHOICE PROVEN in a disposable ordinary TUI attached to its own official loopback server. A pending native A/B question was read through `GET /question`, and `POST /question/:id/reply` with B resumed that exact session to `OPENCODE_QUESTION_TEST_B`. SSE emitted a second `question.asked` event. No Agrypnos or bot round trip yet. |

Versions came from bundle `Info.plist`, `claude --version`, `codex --version` and Cursor CLI help. No credentials or unrelated conversation contents were read.

## Codex: actual server transport check

`codex app-server proxy --help` describes a stdio proxy to a running control socket. `codex app-server daemon version` is read-only; on this Mac it exited 1 with:

```text
failed to connect to /Users/imightbeoufu/.codex/app-server-control/app-server-control.sock
No such file or directory (os error 2)
```

A narrowly filtered process check identified the desktop's bundled `codex app-server` process with no explicit `--listen` flag. Checking only its Unix descriptors with `lsof -a -p <pid> -U -Fn` returned unnamed peer connections (`n->0x…`), with no pathname endpoint. `lsof -a -p <pid> -iTCP -sTCP:LISTEN -Fn` returned no listener (exit 1). These observations establish that the default proxy path is unavailable here; they do not prove that every possible desktop transport is unavailable.

**2026-09-30 revalidation after app update:** The earlier app was 26.924.22138/build 11645 with CLI 0.158.0-alpha.2.1. The running desktop is now ChatGPT.app 26.928.21956/build 12404 with bundled CLI 0.159.2. Its current app-server process explicitly has `--listen stdio://`, and a listener check on that process found no TCP listener. Neither `~/.codex/app-server-control/app-server-control.sock` nor the checked app-server-daemon socket candidate exists. Current CLI help still describes `proxy` as attaching through a Unix socket; stdio belongs to the process's existing host, not an independently attachable endpoint. No listener was opened, server restarted or undocumented setting enabled.

The public app-server protocol supports native `item/tool/requestUserInput` responses, but a schema alone does not grant access to the instance holding that pending request. `thread/read` does not subscribe, and resuming stored history on another server is not proof of controlling the desktop's original request. The app-server command also carries experimental maturity. No server was started, restarted, replaced or reconfigured during this check. [Official protocol](https://learn.chatgpt.com/docs/app-server), [command maturity](https://learn.chatgpt.com/docs/developer-commands).

**Remaining proof:** a supported desktop attachment/setup procedure, request ownership, cancellation/local-answer races and recovery of pending input on that same instance. Starting a new server would not resolve this gate.

The public hook reference describes tool observation/input rewriting, with specialized-path exceptions; it does not establish a native question response contract. [Hooks](https://learn.chatgpt.com/docs/hooks). Fresh review also identified a [reported shared-daemon setup](https://github.com/openai/codex/issues/31991) using `CODEX_APP_SERVER_USE_LOCAL_DAEMON`; the report calls the flag undocumented. It requires desktop reconfiguration/restart and supplies no question-race proof. It was not enabled and does not meet this plan's supported-interface requirement.

## Cursor: separate native and SDK contracts

The public hook response can allow/deny execution or modify input; it does not document a native question-answer result. Generic hook delivery must still be tested for the installed desktop build. A February support report acknowledges missing AskQuestion hooks, but that older report is not evidence of the current build's behavior. [Hook contract](https://cursor.com/docs/hooks), [dated staff report](https://forum.cursor.com/t/askquestion-tool-does-not-trigger-cursor-hooks/152230/5).

ACP documents `cursor/ask_question` and a reply containing question/option IDs on the CLI's stdio connection. It does not document attachment to the desktop's pending call. [ACP](https://cursor.com/docs/cli/acp).

The SDK Bridge wraps the SDK and owns a separate local process/state root. Its resume support concerns that agent store; the inspected service contract does not establish a live desktop question response method. Connecting to an existing SDK bridge is distinct from connecting to the IDE. [Bridge lifecycle](https://github.com/cursor/sdk-bridge/blob/main/docs/protocol.md), [services](https://github.com/cursor/sdk-bridge/blob/main/docs/services.md), [local persistence](https://cursor.com/docs/sdk/python).

An additional read-only check of installed application JavaScript found native AskQuestion types and the generic hook machinery. Internal type presence is not a supported external integration API and was not used to intercept or answer anything.

**Scoped experiment:** created an isolated folder under `/private/tmp/agrypnos-question-probe-4xt0fsga` with project hooks that return `{}` and retain only hook identity fields; only an AskQuestion input from this synthetic probe would be retained. No global/project Agrypnos hook settings were changed. Opening it with Cursor's `--new-window` returned exit 0. Computer Use initially reported pending permissions, then `noWindowsAvailable`/`timeoutReached`; selecting by bundle ID also timed out. No prompt was submitted, no native question observed and no answer sent. Therefore this experiment supplies **no** hook-delivery or round-trip proof. The temporary observer script/configuration was removed after the failed inspection, so it will not log later questions. The folder/window may remain open; no user Cursor process was terminated.

`cursor agent --help` unexpectedly tried the vendor installer because `cursor-agent` was missing. DNS failed before download; there was no successful installation. A separately installed CLI would not prove desktop attachment, so it was not pursued.

**Remaining proof:** inspect an actual native desktop choice request and establish a supported answer path. UI clicks, private database/socket manipulation and transcript edits remain excluded from the product design.

**2026-09-30 desktop probe (3.22.12):** In a disposable `/private/tmp/agrypnos-cursor-question-*` workspace, a project `.cursor/hooks.json` registered a `preToolUse` hook that wrote only tool names, and would include input only for `AskQuestion`. A new ordinary Cursor Agents desktop chat was prompted to ask the native A/B question “Which test letter?” The native questionnaire appeared with A/B options. Selecting B in Cursor continued that same chat to the unique marker `CURSOR_QUESTION_TEST_B`. The hook event file did not exist after the question. A follow-up `pwd` shell command in that same chat generated one `Shell` event in the file, proving this scoped hook was loaded and functional for ordinary tools. Thus the question was not delivered through the generic hook in this installed build. The local B click was a control test, not a remote-answer round trip; no bot was involved. The disposable hook does not alter Agrypnos's settings or any pre-existing chat.

The user subsequently specified **Sonnet 5.5** for Cursor question testing because Grok does not produce the proper questionnaire in their experience. The earlier probe did display a native questionnaire, but its model was not retained in the evidence. Repeat with the explicitly requested model before generalizing that hook result. The attempt to inspect Cursor for this repeat on 2026-09-30 was blocked by the locked Mac; no new prompt was sent.

**Sonnet repeat after unlock:** In a new ordinary desktop chat on the same disposable workspace, explicitly selected **Claude Sonnet 5.5 High**. Registered project `preToolUse` and `postToolUse` observers. Sonnet displayed the native question “Sonnet relay test: which letter?” with A/B and Other, and the local B selection continued that original chat to `SONNET_RELAY_TEST_B`. No hook event file existed through that question/answer. A subsequent single `pwd` command emitted both hook events with `tool_name: Shell` and `model: claude-sonnet-5-5`, proving both observers worked in that same chat. Therefore this installed desktop build's native Sonnet question bypassed both tested hooks. No remote answer or bot was involved. Both temporary hook files were removed after the completed control test; no persistent question logger is left installed.

Fresh official-interface check: [SDK Bridge](https://cursor.com/docs/sdk/bridge) embeds the SDK agent runtime; [SDK resume](https://cursor.com/docs/sdk/typescript#resuming-agents) loads local conversation checkpoints or reattaches to cloud agents. These documents do not provide a response handle to a currently pending question in an existing IDE chat. A bridge endpoint belonging to another SDK process is not proof of IDE attachment. The current [Codex daemon lifecycle](https://github.com/openai/codex/blob/main/codex-rs/app-server-daemon/README.md) remains experimental and describes managed server startup; starting it does not establish ownership of the already observed desktop's private stdio server. Neither was substituted for the user's existing chats.

## Claude and OpenCode: candidates, not passes

Claude's current documentation describes a synchronous `PreToolUse` hook with original questions and an answers map in `updatedInput`. Headless `-p` additionally needs a permission host; simply launching it with a hook is not a valid native question probe. The installed 2.1.183 build still needs interactive/desktop validation, denial coexistence and near-600-second tests. The user has confirmed that they have no Claude subscription, so further live Claude Code prompts are not available for this task. A signed-in Claude Desktop chat is a different surface and cannot substitute for Claude Code evidence. [Claude hooks](https://code.claude.com/docs/en/hooks).

On 2026-09-30, a temporary CLI-only `--settings` hook was scoped to a disposable folder and configured to answer a synthetic A/B `AskUserQuestion` with B. The interactive CLI opened, but the first prompt returned `Not logged in · Please run /login` before any native question or hook callback. The CLI was exited and the temporary hook files were removed. This establishes no round trip and did not affect existing Claude settings or sessions.

OpenCode's [server documentation](https://opencode.ai/docs/server/) describes the TUI/server architecture and password-protected loopback access. A clean checkout of the 1.18.32 source was present locally; the official `opencode-ai@1.18.32` package was installed only in a disposable `/private/tmp` directory. No user configuration, existing session or global install was changed. The official server was started on `127.0.0.1:4096` with temporary XDG directories and Basic authentication, and a normal TUI was attached to that same endpoint and disposable project directory. The source checkout's unbranded dev server could not use its free model, so its failed model request was not treated as an API result.

In the attached TUI, a synthetic prompt invoked the native question tool. `GET /question?directory=<probe-directory>` on the exact same server returned a pending record with `id`, `sessionID`, and ordered `questions` containing `question`, `header`, and `options` (`label`, `description`). External `POST /question/<id>/reply?directory=<probe-directory>` with `{"answers":[["B"]]}` returned JSON `true`. The pending list became empty; `GET /session/<sessionID>/message?directory=<probe-directory>` contained exactly `OPENCODE_QUESTION_TEST_B` in the original assistant response. No separate agent session was created.

A second native question in that same TUI was captured on `GET /global/event` as a `question.asked` payload with `directory`, `properties.id`, `properties.sessionID`, `properties.questions`, and `properties.tool.messageID`/`callID`. After a local A answer in the TUI, the pending list was empty and the original session replied `SECOND_OPENCODE_TEST_A`; a stale external B submission returned HTTP 404 `QuestionNotFoundError` and did not replace the local answer. This establishes an event and pending-list candidate plus one local-first race. It does not establish reconnect recovery, multiple sessions, near-600-second behavior, destination delivery, or the user's actual OpenCode instance configuration.

## Required experiments still outstanding

For **each** provider: native A/B request → B returned through the original response path → unique B continuation exactly once; near-600-second answer and expiry; two simultaneous sessions; local answer/cancel first; disconnect before/after submission; pending recovery; existing hook denials where applicable. OpenCode alone has a synthetic A/B round trip and a sanitized event shape above; the rest of its matrix remains. Neither Telegram nor Discord received a test message.

The [contract supplement](../superpowers/plans/2026-09-29-native-question-contracts.md) is deliberately blocked. Task 1 is not complete. Provider adapters and the user-facing setup must wait for the missing native desktop contracts and the all-four experiments, or an explicit user-approved change to the requirements. The shared code remains off by default and cannot forward a real agent question on its own. No silent two-provider implementation or skill fallback is authorized.

The initial read-only feasibility review found no supported desktop attachment overlooked in its source check. Later shared-code review and local tests cover simulated relay, bot and watch behavior; live provider round trips, bot delivery, locked-screen operation and power impact remain untested. This is not a release review.
