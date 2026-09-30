# Native question compatibility — execution evidence

Status: **Task 1 blocked; no provider has passed the release gate.** Checked on 2026-09-29 on the user's Mac. The user authorized execution and local commits, but no push. Provider-independent relay, bot and watch components (Tasks 2–4 and 9) have since been implemented and tested locally. No native provider adapter or question setup UI is enabled.

This is a capability check, not a finding that native forwarding is impossible in every version. The approved [plan](../superpowers/plans/2026-09-29-native-agent-questions.md) requires access to existing desktop/local conversations for all four providers. An API that creates a separate agent does not meet that gate.

## Installed surfaces and results

| Surface | Observed version | Result |
| --- | --- | --- |
| Cursor desktop | 3.22.7 | NOT PROVEN. Public hooks/ACP/SDK contracts do not establish an answer route into its live desktop question. The scoped desktop experiment could not be inspected. |
| Claude Code CLI | 2.1.183 | BLOCKED ON SIGN-IN. Native question hook is a documented candidate; a disposable interactive probe reached "Not logged in" before any question or hook event. |
| Claude desktop | 2.7032.0 | NOT TESTED. Desktop hook behavior must be proved separately from a CLI-owned run. |
| Codex desktop (`com.openai.codex`) | 26.924.22138, build 11645 | BLOCKED ON ATTACHMENT. The running desktop server has no observed named Unix endpoint; the documented default control socket is absent. |
| Bundled Codex CLI | 0.158.0-alpha.2.1 | `app-server proxy` exists, but cannot attach without the original server's control socket. |
| OpenCode | Not found on PATH or in inspected standard app/bin locations | NOT TESTED. An active instance and its endpoint/version have not been identified. This does not establish that OpenCode is absent from the entire Mac. |

Versions came from bundle `Info.plist`, `claude --version`, `codex --version` and Cursor CLI help. No credentials or unrelated conversation contents were read.

## Codex: actual server transport check

`codex app-server proxy --help` describes a stdio proxy to a running control socket. `codex app-server daemon version` is read-only; on this Mac it exited 1 with:

```text
failed to connect to /Users/imightbeoufu/.codex/app-server-control/app-server-control.sock
No such file or directory (os error 2)
```

A narrowly filtered process check identified the desktop's bundled `codex app-server` process with no explicit `--listen` flag. Checking only its Unix descriptors with `lsof -a -p <pid> -U -Fn` returned unnamed peer connections (`n->0x…`), with no pathname endpoint. `lsof -a -p <pid> -iTCP -sTCP:LISTEN -Fn` returned no listener (exit 1). These observations establish that the default proxy path is unavailable here; they do not prove that every possible desktop transport is unavailable.

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

## Claude and OpenCode: candidates, not passes

Claude's current documentation describes a synchronous `PreToolUse` hook with original questions and an answers map in `updatedInput`. Headless `-p` additionally needs a permission host; simply launching it with a hook is not a valid native question probe. The installed 2.1.183 build still needs interactive/desktop validation, denial coexistence and near-600-second tests. [Claude hooks](https://code.claude.com/docs/en/hooks).

On 2026-09-30, a temporary CLI-only `--settings` hook was scoped to a disposable folder and configured to answer a synthetic A/B `AskUserQuestion` with B. The interactive CLI opened, but the first prompt returned `Not logged in · Please run /login` before any native question or hook callback. The CLI was exited and the temporary hook files were removed. This establishes no round trip and did not affect existing Claude settings or sessions.

OpenCode documents a server/event architecture. Its candidate question API must be matched to a pinned installed version and the server actually hosting the user's conversation. No active endpoint was available for a round trip; no replacement server or port scan was started. [OpenCode server](https://opencode.ai/docs/server/).

## Required experiments still outstanding

For **each** provider: native A/B request → B returned through the original response path → unique B continuation exactly once; near-600-second answer and expiry; two simultaneous sessions; local answer/cancel first; disconnect before/after submission; pending recovery; existing hook denials. No sanitized question fixtures were captured because no question was observed. Neither Telegram nor Discord received a test message.

The [contract supplement](../superpowers/plans/2026-09-29-native-question-contracts.md) is deliberately blocked. Task 1 is not complete. Provider adapters and the user-facing setup must wait for the missing native desktop contracts and the all-four experiments, or an explicit user-approved change to the requirements. The shared code remains off by default and cannot forward a real agent question on its own. No silent two-provider implementation or skill fallback is authorized.

The initial read-only feasibility review found no supported desktop attachment overlooked in its source check. Later shared-code review and local tests cover simulated relay, bot and watch behavior; live provider round trips, bot delivery, locked-screen operation and power impact remain untested. This is not a release review.
