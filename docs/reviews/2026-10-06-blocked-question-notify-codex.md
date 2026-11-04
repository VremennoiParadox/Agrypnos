# Codex blocked-question notify (hooks as a local signal)

Inspection date: **2026-10-06**. Official pages opened in the browser. Installed CLI is **codex-cli 0.159.2** (ChatGPT.app bundle). Answer-path is **closed** — this note does not reopen JSON-RPC attach, `app-server --listen`, or returning a selected option. `~/.codex/hooks.json` was **not** edited. No secrets printed.

## Finding

**Feasible as a positive local notice, not as an answer.** A trusted command hook can tell Agrypnos that Codex is about to show a **native question** (`PreToolUse` + `tool_name: "request_user_input"`) or a **native approval** (`PermissionRequest`), then exit 0 with empty stdout so the on-screen picker stays. That is a named event, not “files went quiet.”

**Not feasible:** treating `Stop`, `notify` / `agent-turn-complete`, `Interrupt`, `SessionEnd`, or idle session files as “a question is on screen.” Those fire when a turn **ended**, was interrupted, or the session closed. Quiet is a different Agrypnos feature.

Live ChatGPT.app optical of the hook firing was **not** run this round. The claim below is docs + this Mac’s 0.159.2 source/binary. Hook **trust** still gates whether the command actually runs.

## Sources opened

| URL | What it is |
| --- | --- |
| https://learn.chatgpt.com/docs/hooks (Markdown twin: https://learn.chatgpt.com/docs/hooks.md) | Lifecycle events, stdin/stdout, matchers, merge, `/hooks` trust |
| https://learn.chatgpt.com/docs/app-server (Markdown twin: https://learn.chatgpt.com/docs/app-server.md) | Named pauses: `item/tool/requestUserInput`, command/file/permissions approvals, MCP elicitation |
| https://learn.chatgpt.com/docs/config-file/config-advanced | `notify` is **only** `agent-turn-complete`; TUI `approval-requested` is TUI-only |
| https://learn.chatgpt.com/docs/config-file/config-reference | `notify` = command + JSON payload; `tui.notifications` |
| https://learn.chatgpt.com/docs/developer-settings | CLI/IDE share `~/.codex/config.toml`; no desktop `/hooks` screen named |
| https://learn.chatgpt.com/docs/app | ChatGPT desktop product page; no hooks section |
| GitHub `openai/codex` tag `rust-v0.159.2` | Same version as this Mac: `RequestUserInputHandler` does **not** opt out of `PreToolUse`; `Session::request_approval` runs `PermissionRequest` hooks **before** the native UI |
| This Mac binary | `/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex` — `codex-cli 0.159.2`; `hooks` **stable true** |

Prior closed notes (do not reopen the answer path): `docs/reviews/2026-10-06-codex-question-relay-codex-docs.md`, `docs/reviews/2026-10-06-codex-question-relay-local-signals.md`.

## 1. `PreToolUse` and `request_user_input`

Official hooks page: `PreToolUse` runs **before** a supported tool. Coverage table lists shell (`Bash`), `apply_patch`, MCP names, and **“other local function tools”** (example: `update_plan`). Hosted tools such as `WebSearch` are No. **“Some specialized tool paths can opt out.”** The page **does not name** `request_user_input`.

This Mac’s 0.159.2 source does **not** opt out:

- Default `CoreToolRuntime::pre_tool_use_payload` emits a `PreToolUse` payload for any `ToolPayload::Function` (`codex-rs/core/src/tools/registry.rs` on tag `rust-v0.159.2`). Dispatch runs `run_pre_tool_use_hooks` **before** `handle()`.
- Known opt-outs in that tag: `write_stdin` (transport for an already-hooked exec) and code-mode `wait`. `RequestUserInputHandler` only sets `is_builtin_control_tool() -> true`. It does **not** override `pre_tool_use_payload`.
- After a continuing `PreToolUse`, the handler calls `session.request_user_input(...)` — that is when the native picker appears.

So: **yes**, on 0.159.2, `PreToolUse` runs for builtin `request_user_input` **before** the native picker. Official docs still omit the name; treat the binary/source as the version truth.

### Empty stdout, exit 0, keep the picker

Official common rule: **exit 0 with no output = success, Codex continues.** For `PreToolUse`, **plain text on stdout is ignored.** JSON `permissionDecision: "deny"` (or exit 2) **blocks** the tool — that is not a notify. `permissionDecision: "ask"` / `continue: false` are **unsupported**; Codex marks the hook failed, reports the error, **and continues the tool call**. Managed-hooks note: a `PreToolUse` **error, timeout, or malformed response can fail the hook without blocking the tool**.

A notify command should: ping Agrypnos, print **nothing**, exit **0**, finish **quickly**. Then the native picker still appears.

`async: true` is the documented way to run a command hook **without delaying** the triggering operation. Background hooks **cannot** block/approve/rewrite. For notice-only, that is the right shape. A slow **synchronous** hook delays the picker (default timeout **600s**).

### Stdin fields that mean “question,” not “some tool”

Shared: `session_id`, `transcript_path` (nullable; **not a stable interface**), `cwd`, `hook_event_name`, `model`. Turn-scoped: `turn_id`. `PreToolUse` also:

| Field | Meaning for this event |
| --- | --- |
| `hook_event_name` | `"PreToolUse"` |
| `tool_name` | Canonical name. For the native question this is `"request_user_input"`. Matcher is a regex on this name. |
| `tool_use_id` | This invocation’s tool-call id |
| `tool_input` | Tool arguments as JSON. Docs: MCP and other local function tools send their arguments. |

0.159.2 parses `tool_input` from the model’s function arguments (`function_hook_tool_input`). The tool schema (`request_user_input_spec.rs`) requires:

```json
{
  "tool_name": "request_user_input",
  "tool_input": {
    "questions": [
      {
        "id": "snake_case_id",
        "header": "short header",
        "question": "single-sentence prompt",
        "options": [
          { "label": "A", "description": "tradeoff" }
        ]
      }
    ]
  }
}
```

Protocol fields `isOther` / `isSecret` exist on `RequestUserInputQuestion` (default false). `isBlocking` is set **inside the handler after** `PreToolUse` (`is_blocking: mode == Plan`), so hook stdin may **omit** it. Do not wait for `isBlocking` to decide “this is a question.”

**Matcher:** `"request_user_input"` (or `^request_user_input$`). `"*"`, `""`, or omit matcher = **every** `PreToolUse` (Bash, patches, MCP, `update_plan`, …) — too noisy to label “question.”

**Honesty if `question` text is missing:** `tool_name == "request_user_input"` is enough to say **“Codex is waiting on you”** / **“Codex asked a question.”** If `tool_input.questions[].question` is present, you may quote it. If it is absent or unreadable, **do not invent** the prompt or the option labels.

This Mac: `default_mode_request_user_input` is **under development / false**. The tool is still a real builtin; 0.159.2 strings include “unavailable in {mode}” and “not supported in exec mode.” A `PreToolUse` matcher only fires when the model **actually calls** the tool.

## 2. `PermissionRequest` — shell / network approval

Official: `PermissionRequest` runs **when Codex is about to ask for approval**, “such as a shell escalation or managed-network approval.” It can **allow**, **deny**, or **decline to decide** and let the **normal approval prompt continue**. **It does not run for commands that don’t need approval.**

Matcher: `tool_name` — docs name `Bash`, `apply_patch` (`Edit`/`Write` aliases), MCP names. Plain text on stdout is **ignored**.

**Stdout that keeps the native approval on screen:** do **not** return `hookSpecificOutput.decision.behavior: "allow"` (that **skips** the prompt) or `"deny"` (blocks). Official: if **no matching hook decides**, Codex uses the **normal approval flow**. Exit **0** with **empty stdout** is the documented success/continue path and is the decline-to-decide shape. Do **not** return `updatedInput` / `updatedPermissions` / `interrupt` (fail closed).

0.159.2 core (`Session::request_approval` in `tools/approvals.rs`): **hooks first**; `None` → Guardian/user UI. That is the same core path ChatGPT.app uses (`codex app-server` on stdio). This is **not** “CLI TUI only.” It **is** gated by whether an approval is actually required (`permission_mode` on stdin: `default`, `acceptEdits`, `plan`, `dontAsk`, `bypassPermissions`). `dontAsk` / `bypassPermissions` / already-cached approve-for-session → **no** `PermissionRequest`.

On this Mac, `exec_permission_approvals` and `request_permissions_tool` are **under development / false**. That does **not** erase the documented `PermissionRequest` event. Do not claim those flags from `features list` without a live approval optical.

0.159.2 `ApprovalAction` payloads that feed `PermissionRequest` (source, not the hooks page):

| Action | Hook `tool_name` | `tool_input` shape |
| --- | --- | --- |
| Exec / execve / network-access | `Bash` | `{ "command": "…" }` ; network may set `description` like `network-access {target}` |
| `apply_patch` | `apply_patch` | `{ "command": "<patch>" }` |
| MCP tool | MCP hook name | tool arguments |
| `write_stdin` | `write_stdin` | session/chars/approval ids |
| `request_permissions` | `request_permissions` | `{ "reason", "permissions" }` |

Docs: `tool_input.description` is a **human-readable approval reason when Codex has one** — **do not rely on it for every tool.**

Label from `tool_name` + event: **“a shell approval is on screen”** (`Bash`), **“a file approval is on screen”** (`apply_patch`), **“a network approval is on screen”** (Bash + network description). Never call this a structured **question**.

## 3. `Stop` is turn ended — not “waiting on a question”

Official intro: hooks include “Run a custom validation check **when a chat turn stops**.” Timing table lists `Stop` under “During a turn” next to `UserPromptSubmit`, but the **Stop section** is the turn-stop contract:

Stdin extras: `turn_id`, `stop_hook_active` (whether this turn was **already continued by Stop**), `last_assistant_message`. Matcher is **ignored**. Exit 0 expects **JSON**; plain text is **invalid**. `decision: "block"` here means **continue the model** with `reason` as a new user prompt — not “a question is showing.” `continue: false` wins over continuation.

0.159.2: `run_turn_stop_hooks` — root turns run `Stop`; thread-spawned children run `SubagentStop`. That is **after the turn is stopping**, not while `request_user_input` is blocking inside `handle()`.

The user’s existing brainrot `Stop` hook is an **idle/turn-ended** signal. **Do not label it “waiting on a question.”**

`UserPromptSubmit` is the user **sending** a prompt. `Interrupt` is the user **interrupting** an active turn (1s default, 3s max; cannot prevent interrupt). `SessionEnd` is the **main thread ending** (archive/delete/normal close/idle), not a picker.

## 4. ChatGPT.app vs terminal CLI; `/hooks` trust

Official discovery: `~/.codex/hooks.json` next to user config. ChatGPT.app on this Mac already runs the bundled CLI as `app-server` and already has user `~/.codex/hooks.json` (brainrot `UserPromptSubmit` / `Stop`). Core dispatch is the same crate. **User-level hooks are not documented as “CLI-only.”** Project-local hooks still need a **trusted** project layer; user/system hooks still load when the project is untrusted.

Official trust: **non-managed hooks must be reviewed and trusted** against the current **hash**. Changed definitions are **skipped until trusted**. Named UI: **`/hooks` in the CLI**. Startup warning tells you to open `/hooks`. `--dangerously-bypass-hook-trust` is for already-vetted automation only.

Docs **do not** describe a ChatGPT.app settings pane that reviews hooks the same way. Developer-settings: CLI and IDE share `config.toml`; they do not name desktop `/hooks`. App-server/TUI source has `hooks/list` (TUI tests). **Do not invent** a desktop slash command. A **new** `PreToolUse` / `PermissionRequest` matcher group is a **new hash** even if brainrot `Stop` is already trusted.

This round did **not** prove the notify command actually ran inside a ChatGPT.app Codex thread. Implementers must expect: merge → user trusts the new hook (`/hooks` in CLI, or whatever host actually shows) → then the command can fire.

`features.hooks = false` turns hooks off. This Mac: `hooks` **stable true**.

## 5. One-button merge into `~/.codex/hooks.json`

Official: if more than one hook **source** exists, Codex **loads all matching hooks**. Higher-precedence layers **do not replace** lower-precedence hooks. Same layer `hooks.json` + inline `[hooks]` → **merge + startup warning**; prefer one representation per layer.

This user already has `~/.codex/hooks.json` with `UserPromptSubmit` and `Stop` (brainrot). There is **no** `[hooks]` table in `config.toml`.

**Merge rule:** append matcher groups under `hooks.PreToolUse` and/or `hooks.PermissionRequest`. **Do not replace** the file. **Do not delete** `UserPromptSubmit` or `Stop`. **Do not rewrite** `config.toml` (would risk model, MCP, `notify`, desktop keys). Do not add a second `[hooks]` table in the same user layer.

Shape (illustrative — not installed):

```json
{
  "hooks": {
    "UserPromptSubmit": [ { "hooks": [ { "type": "command", "command": "/Users/imightbeoufu/.brainrot/brainrot-state.sh" } ] } ],
    "Stop": [ { "hooks": [ { "type": "command", "command": "/Users/imightbeoufu/.brainrot/brainrot-state.sh" } ] } ],
    "PreToolUse": [
      {
        "matcher": "^request_user_input$",
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/agrypnos-codex-notice",
            "async": true,
            "timeout": 5,
            "statusMessage": "Notifying Agrypnos"
          }
        ]
      }
    ],
    "PermissionRequest": [
      {
        "matcher": "Bash|apply_patch|^request_permissions$",
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/agrypnos-codex-notice",
            "async": true,
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

The notice command must ignore stdout contract (print nothing) and exit 0. Matching command hooks for the same event run **concurrently** — brainrot `Stop` and a new `PreToolUse` are different events and do not collide.

## 6. Other named pauses vs error/exit (cited only)

**Named pauses (user still needs to act; turn not finished):**

| Name | Where cited | Hook Agrypnos can use without attach? |
| --- | --- | --- |
| Native structured question | App-server `item/tool/requestUserInput` / `tool/requestUserInput`; builtin `request_user_input` | **`PreToolUse` matcher `request_user_input`** (0.159.2; docs omit the name) |
| Shell / command approval | App-server `item/commandExecution/requestApproval`; hooks `PermissionRequest` “shell escalation” | **`PermissionRequest`** (`Bash`) |
| Managed network approval | Same command-approval RPC with `networkApprovalContext`; hooks “managed-network” | **`PermissionRequest`** (`Bash` + optional description) |
| File-change approval | App-server `item/fileChange/requestApproval` | **`PermissionRequest`** (`apply_patch`) in 0.159.2 approval routing |
| `request_permissions` | App-server `item/permissions/requestApproval`; builtin tool | **`PermissionRequest`** (`request_permissions`) if that tool runs |
| MCP / app-connector approval | App-server: app tools may elicit via `tool/requestUserInput` Accept/Decline/Cancel; also MCP approval in core `ApprovalAction::McpToolCall` | Question-shaped: `PreToolUse` `request_user_input`. Tool-approval-shaped: `PermissionRequest` MCP name |
| MCP elicitation | App-server `mcpServer/elicitation/request` (`form` / `openai/form` / `url`) | **No** dedicated hook event on the hooks page |

App-server JSON-RPC (`item/tool/requestUserInput`, `serverRequest/resolved`, `hook/started`) is a **client of the already-running server**. That attach path is **closed** on this Mac (stdio app-server, no `app-server-control.sock`). Do not use it for notify.

**Turn ended / not a question:**

| Name | Cite |
| --- | --- |
| `Stop` / `SubagentStop` | Hooks page; 0.159.2 `run_turn_stop_hooks` |
| `notify` command | Config-advanced: **currently only** `type: "agent-turn-complete"` (`thread-id`, `turn-id`, `cwd`, `input-messages`, `last-assistant-message`) |
| `tui.notifications` | TUI-only; may filter `agent-turn-complete` and `approval-requested`. Not ChatGPT.app; not a command Agrypnos owns |
| `Interrupt` | User interrupted the turn |
| `SessionEnd` | Thread ended (`reason` currently `other`) |
| `turn/completed` | App-server lifecycle |

This user’s `config.toml` `notify = [command, …]` is the **turn-complete** program. Extra argv on that array is the user’s script, not a documented “question” event. Do not retarget `notify` as question-detect.

**Errors / exits (not a pause to answer):** `StreamError`; `TurnAborted`; `request_user_input` cancelled before a response (model-visible error in 0.159.2 handler); exec-mode “`request_user_input` is not supported”; PreToolUse **deny** (blocked tool, no picker).

## 7. Honest copy without the question text

If the hook runs and `tool_name` is `request_user_input`, Agrypnos **may** notify **“Codex is waiting on you”** / **“Codex asked a question.”** That does not invent the prompt.

If `tool_input.questions[].question` (and option labels) are present, they may be shown. If missing, truncated, or `isSecret` is true, **omit the body** — still a positive “waiting on you,” not a guessed question.

If the hook is `PermissionRequest`, say **approval** (shell / file / network), never “question.”

Never: “files went quiet,” “agent finished,” “still thinking,” or labeling `Stop` / `agent-turn-complete` as a blocked question.

## What an implementer must not invent

- That this path **answers** the picker (closed). Empty stdout does **not** submit options.
- A hook event named `AskUser`, `RequestUserInput`, or `Question`. The events are `PreToolUse` and `PermissionRequest`.
- That official hooks docs **name** `request_user_input` in the coverage table (they don’t; 0.159.2 source still runs default `PreToolUse`).
- That `PermissionRequest` is the structured question, or that `allow` keeps the approval on screen (`allow` **skips** it).
- That `Stop`, `notify` / `agent-turn-complete`, `UserPromptSubmit`, `Interrupt`, or quiet files mean “a question is on screen.”
- That `tui.notifications` `approval-requested` fires inside ChatGPT.app.
- That ChatGPT.app documents a `/hooks` review screen identical to the CLI. New matcher groups still need **trust** or they are skipped.
- That a live ChatGPT.app optical was done this round.
- JSON-RPC attach / starting `codex app-server` / touching `~/.codex` except a future **merge** of `hooks.json`.
- Replacing `hooks.json` or deleting brainrot `UserPromptSubmit` / `Stop`.
- Inventing question text, option labels, watt numbers, competitor names, or think-detection.
