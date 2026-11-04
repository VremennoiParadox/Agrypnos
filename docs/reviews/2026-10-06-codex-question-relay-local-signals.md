# Codex local signals (question relay)

Inspection date: **2026-10-06**. Read-only observation on this Mac. No Codex config was changed, no JSON-RPC was sent, no question was forwarded, nothing was committed or pushed. Secrets (`auth.json`, tokens, API keys) were not printed.

This is **not** a live question round-trip.

## Finding

The `codex` command is **not on PATH**. The installed CLI is the OpenAI **Rust** binary bundled inside ChatGPT.app (bundle id `com.openai.codex`), version **`codex-cli 0.159.2`**. `codex app-server --help` exists (experimental). User hooks **already exist** in `~/.codex/hooks.json` (brainrot `UserPromptSubmit` / `Stop`). A later Agrypnos installer must **MERGE** those hooks and must not replace `hooks.json` or `config.toml`.

There is **no** separate Node `@openai/codex` global install. npm registry currently lists `@openai/codex` **0.160.1** (published 2026-10-05); that package is not installed here. Do not confuse the ChatGPT.app Rust CLI with a missing npm wrapper.

## Installed binary

`which -a codex` → `codex not found`.

Common paths checked (all missing):

- `/opt/homebrew/bin/codex`
- `~/.local/bin/codex`
- `/usr/local/bin/codex`
- `/Applications/Codex.app`

Real CLI:

| Path | Kind |
| --- | --- |
| `/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex` | Mach-O 64-bit executable **arm64**, 240 185 120 bytes, mtime 2026-09-30 11:04 |
| `/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex` | POSIX `sh` wrapper (328 bytes) that `exec`s the Mach-O above |
| `~/.codex/plugins/.plugin-appserver/codex-cli/` | Same layout / same `codex-package.json` version (plugin-appserver copy) |

Version from the Mach-O and from the wrapper:

```
codex-cli 0.159.2
```

`codex-package.json` (ChatGPT.app copy):

```json
{
  "layoutVersion": 1,
  "version": "0.159.2",
  "target": "aarch64-apple-darwin",
  "variant": "codex",
  "entrypoint": "bin/codex",
  "resourcesDir": "codex-resources",
  "pathDir": "codex-path"
}
```

Host app: `/Applications/ChatGPT.app`, `CFBundleName` ChatGPT, `CFBundleIdentifier` `com.openai.codex`, `CFBundleShortVersionString` **26.928.31416**. Nested Codex Framework helpers report version **154.0.8037.57**. `config.toml` `mcp_servers.node_repl.env.CODEX_CLI_PATH` points at the Mach-O above (key name only; value is that path).

Wrapper contents (entire file):

```sh
#!/bin/sh
set -eu
entry="$0"
while [ -L "$entry" ]; do
  parent=$(CDPATH= cd -P -- "$(dirname -- "$entry")" && pwd)
  entry=$(readlink "$entry")
  case "$entry" in /*) ;; *) entry="$parent/$entry" ;; esac
done
bin_dir=$(CDPATH= cd -P -- "$(dirname -- "$entry")" && pwd)
exec "$bin_dir/../CodexCLI.app/Contents/MacOS/codex" "$@"
```

Not present:

- Homebrew formula/cask named `codex` / `openai-codex` (no Cellar/Caskroom match)
- `~/.cargo/bin/codex`
- `/opt/homebrew/lib/node_modules/@openai`
- global npm `@openai/codex` (`npm ls -g @openai/codex` empty)

## User config (`~/.codex/`)

Config path: **`/Users/imightbeoufu/.codex/config.toml`** (mode `0600`, 2964 bytes, mtime 2026-10-06 12:27).

Filenames at `~/.codex/` (listing only; `auth.json` not read):

`.codex-global-state.json`, `.codex-global-state.json.bak`, `.personality_migration`, `.sandbox_migration`, `.tmp/`, `AGENTS.md`, `archived_sessions/`, `auth.json` (mode `0600`, not dumped), `cache/`, `code-review-plugin/`, `computer-use/`, `config.toml`, `external_agent_session_imports.json`, `generated_images/`, `goals_1.sqlite`, `hooks/`, `hooks.json`, `installation_id`, `ipc/`, `logs_2.sqlite` (+ shm/wal), `memories/`, `memories_1.sqlite`, `models_cache.json`, `node_repl/`, `pets/`, `plugins/`, `project-metadata-locks/`, `queue_1.sqlite` (+ shm/wal), `rollout-migrations/`, `session_index.jsonl`, `sessions/`, `shell_snapshots/`, `skills/`, `sqlite/`, `state_5.sqlite` (+ shm/wal), `thread-writer-locks/`, `thread_history_1.sqlite`, `tmp/`, `vendor_imports/`, `visualizations/`, `worktrees/`.

### `config.toml` keys (values redacted)

No `[hooks]` table. There **is** an `[mcp_servers]` table. Binary `ConfigToml` still knows a `hooks` key (see strings below); this file simply does not set it.

Structure (secret-looking / long strings redacted):

```toml
model = "<redacted>"
model_reasoning_effort = "<redacted>"
notify = ["<command path under ~/.codex/computer-use/, 146 chars>", "turn-ended"]
service_tier = "default"

[projects."<path>"]
trust_level = "trusted"
# two project tables; Agrypnos is one of them

[mcp_servers.codegraph]
command = "codegraph"
args = ["serve", "--mcp"]

[mcp_servers.node_repl]
args = []
command = "<ChatGPT.app cua_node node_repl>"
startup_timeout_sec = 120

[mcp_servers.node_repl.env]
NODE_REPL_NATIVE_PIPE_CONNECT_TIMEOUT_MS = "1000"
NODE_REPL_NODE_MODULE_DIRS = "<ChatGPT.app node_modules>"
NODE_REPL_NODE_PATH = "<ChatGPT.app node>"
NODE_REPL_TRUSTED_CODE_PATHS = "<redacted>"
CODEX_HOME = "/Users/imightbeoufu/.codex"
BROWSER_USE_AVAILABLE_BACKENDS = "chrome,iab,mcpapps"
BROWSER_USE_TINYSKY_ENABLED = "1"
NODE_REPL_INSTRUCTIONS_USE_CASE_BROWSER = ""
NODE_REPL_INSTRUCTIONS_USE_CASE_CHROME = ""
NODE_REPL_INSTRUCTIONS_USE_CASE_COMPUTER_USE = ""
BROWSER_USE_CODEX_APP_BUILD_FLAVOR = "prod"
BROWSER_USE_CODEX_APP_VERSION = "26.928.31416"
NODE_REPL_TRUSTED_SERVICES = "<redacted str len=143>"
SKY_CUA_SERVICE_PATH = "/Users/imightbeoufu/.codex/computer-use/Codex Computer Use.app"
CODEX_CLI_PATH = "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex"

[desktop]
followUpQueueMode = "steer"
external-agent-import-sync-item-types = "all"
external-agent-import-sync-enabled = true
conversationDetailMode = "STEPS_PROSE"
ambient-suggestions-enabled = true
selected-avatar-id = "null-signal"

[marketplaces.openai-bundled]
source_type = "local"
source = "/Users/imightbeoufu/.codex/.tmp/bundled-marketplaces/openai-bundled"

[marketplaces.openai-primary-runtime]
source_type = "local"
source = "<path>"

[plugins."<id>@openai-bundled"]
enabled = true
# plus several openai-primary-runtime plugin tables, all enabled = true
```

Top-level keys actually present: `model`, `model_reasoning_effort`, `notify`, `service_tier`, `projects`, `mcp_servers`, `desktop`, `marketplaces`, `plugins`. No `features` table.

### Existing hooks — MERGE, do not replace

Same lesson as Claude’s brainrot hooks.

`~/.codex/hooks.json` (420 bytes, 2026-09-24) — event names and command path only:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/Users/imightbeoufu/.brainrot/brainrot-state.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/Users/imightbeoufu/.brainrot/brainrot-state.sh"
          }
        ]
      }
    ]
  }
}
```

Also present: `~/.codex/hooks/brainrot-state.sh` (105 lines, 3063 bytes, same size as `~/.brainrot/brainrot-state.sh`). `hooks.json` points at **`~/.brainrot/brainrot-state.sh`**, not at the copy under `~/.codex/hooks/`.

The script comments that it is a Cursor / Claude Code hook → Brainrot multi-provider state file. Codex events `UserPromptSubmit` / `Stop` are among the names it already treats as Claude-style busy/idle. An Agrypnos installer that overwrites `hooks.json` would drop brainrot.

There is **no** `codex hooks` subcommand (`codex help hooks` → unrecognized). Hooks are config + `hooks.json`. Feature flag `hooks` is **stable / true** (`codex features list`, read-only).

## Help text (quoted)

Invoked as `/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex`.

### Top-level (`codex --help`)

Commands that matter for this check:

```
Commands:
  agents            Browse all agent sessions on the shared local app-server daemon
  exec              Run Codex non-interactively [aliases: e]
  review            Run a code review non-interactively
  mcp               Manage external MCP servers for Codex
  app-server        [experimental] Run the app server or related tooling
  remote-control    [experimental] Manage the app-server daemon with remote control enabled
  exec-server       [EXPERIMENTAL] Run the standalone exec-server service
  help              Print this message or the help of the given subcommand(s)
```

Relevant flags:

```
      --remote <ADDR>
          Connect the TUI to a remote app server endpoint.

          Accepted forms: `ws://host:port`, `wss://host:port`, `unix://`, or `unix://PATH`.

      --dangerously-bypass-hook-trust
          Run enabled hooks without requiring persisted hook trust for this invocation. DANGEROUS.
          Intended only for automation that already vets hook sources

      --no-daemon
          Run without the shared background server, even if it is already running
```

**`proto` is gone.** `codex help proto` → `error: unrecognized subcommand 'proto'`.

### `app-server` — help exists

```
[experimental] Run the app server or related tooling

Usage: codex app-server [OPTIONS] [COMMAND]

Commands:
  daemon                Manage the local app-server daemon
  proxy                 Proxy stdio bytes to the running app-server control socket
  generate-ts           [experimental] Generate TypeScript bindings for the app server protocol
  generate-json-schema  [experimental] Generate JSON Schema for the app server protocol
  help                  Print this message or the help of the given subcommand(s)

      --listen <URL>
          Transport endpoint URL. Supported values: `stdio://` (default), `unix://`, `unix://PATH`,
          `ws://IP:PORT`, `off`

          [default: stdio://]

      --stdio
          Use stdio as the transport (equivalent to `--listen stdio://`)
```

`codex app-server daemon`: `bootstrap`, `start`, `restart`, `update`, `enable-remote-control`, `disable-remote-control`, `stop`, `version`.

`codex app-server proxy`: `--sock <SOCKET_PATH>` — “Path to the app-server Unix domain socket to connect to”.

JSON schema / TS generators were **not** run (they write files). `--experimental` on those generators “Include experimental methods and fields”.

### `exec`

```
Run Codex non-interactively

Usage: codex exec [OPTIONS] [PROMPT]
       codex exec [OPTIONS] <COMMAND> [ARGS]

Commands:
  resume  Resume a previous session by id or pick the most recent with --last
  fork    Fork a previous session by id into a new session
  review  Run a code review against the current repository
```

Also has `--dangerously-bypass-hook-trust` and `--json`. Binary strings say `request_user_input is not supported in exec mode` (see below).

### `mcp`

```
Manage external MCP servers for Codex

Usage: codex mcp [OPTIONS] <COMMAND>

Commands:
  list
  get
  add
  remove
  login
  logout
```

### `review`

```
Run a code review non-interactively

Usage: codex review [OPTIONS] [PROMPT]
```

(`--uncommitted`, `--base`, `--commit`, `--title`.)

### `hooks`

No subcommand. Only `--dangerously-bypass-hook-trust` plus config/`hooks.json`.

## Binary strings (read-only; install not modified)

Searched the Mach-O with `strings`. `AskUser` / `AskUserQuestion` (Claude names) were **not** found. Codex’s own question path is `request_user_input` / `item/tool/requestUserInput`.

### App-server method names (concatenated table; split for reading)

Present in the same blob, including:

- `item/tool/requestUserInput`
- `item/commandExecution/requestApproval`
- `item/fileChange/requestApproval`
- `item/permissions/requestApproval`
- `mcpServer/elicitation/request`
- `serverRequest/resolved`
- `hook/started`, `hook/completed`
- `hooks/list`

Also: `thread/start`, `thread/read`, `turn/start`, `turn/steer`, `turn/interrupt`.

Wire / tool types (adjacent rustc field names):

- `ToolRequestUserInput`, `ToolRequestUserInputQuestion` (`header`, `question`, `isOther`, `isSecret`, `options` with `label` / `description`)
- `ToolRequestUserInputAnswer` (`answers`)
- `RequestUserInputEvent` (`call_id`, `questions`, `is_blocking` / `isBlocking`, `auto_resolution_ms` / `autoResolutionMs`)
- `WireRequestUserInputEvent` (`call_id`, `turn_id`, `questions`, `isBlocking`)
- `WireToolRequestUserInputParams` (`threadId`, `turnId`, `itemId`, `questions`, `isBlocking`, `autoResolutionMs`)
- config: `ToolsToml` includes `experimental_request_user_input`; `ConfigToml` includes `hooks`, `mcp_servers`, `plugins`

Quoted tool-policy strings:

```
request_user_input is not supported in exec mode for thread `
request_user_input requires an interactive stdin terminal
This request is non-blocking.
## request_user_input availability
Use the `request_user_input` tool only when it is listed in the available tools for this turn.
If `request_user_input` returns no answers, continue with best judgment instead of asking again or treating the turn as blocked.
Never use the `request_user_input` tool for permission requests or permission-related escalations.
```

Source-path strings still in the binary: `core/src/tools/handlers/request_user_input.rs`, `request_user_input_async.rs`, `tui/src/bottom_pane/request_user_input/`.

### Hook event names

JSON schema `"const"` values in the binary:

`PreToolUse`, `PermissionRequest`, `PostToolUse`, `PreCompact`, `PostCompact`, `SessionStart`, `SessionEnd`, `UserPromptSubmit`, `SubagentStart`, `SubagentStop`, `Stop`, `Interrupt`

Adjacent: `HookEventsToml`, `config.toml`, `hooks.json` (`failed to serialize hooks.json:`), `hooks/hooks.json`.

`codex features list` (read-only): `hooks` **stable true**; `default_mode_request_user_input` **under development false**; `plugin_hooks` **removed false**.

## Running processes / sockets

Did **not** attach. Did **not** send JSON-RPC.

No `codex` TCP `LISTEN` sockets. Unix sockets in use:

- `~/.codex/ipc/ipc.sock` — held by ChatGPT pid **651** (`/Applications/ChatGPT.app/Contents/MacOS/ChatGPT`)
- `/tmp/com.openai.codex.*/SingletonSocket` — ChatGPT 651
- `/tmp/codex-browser-use/<uuid>.sock` — ChatGPT 651 (browser-use, not app-server JSON-RPC)

Codex CLI pids (command line only; cloud environment id omitted):

| pid | ppid | command |
| --- | --- | --- |
| 1489 | 651 | `…/CodexCLI.app/Contents/MacOS/codex -c features.code_mode_host=true app-server --analytics-default-enabled -c plugins.codex-app-tools@openai-bundled.mcp_servers.codex_app.enabled=true -c plugins.code-review@openai-bundled.mcp_servers.code-review.enabled=true` |
| 36160 | 12393 | `…/codex app-server --listen stdio://` |
| 12252 | 651 | `…/codex exec-server --remote https://codex-cloud-environments.chatgpt.com/api --environment-id <redacted>` |
| 12555 | — | `…/codex-cli/bin/codex-code-mode-host` |

Pid 1489 is the desktop app-server (stdio pipes to ChatGPT, no `--listen` TCP). Pid 36160 is a second stdio app-server for a Computer Use / node_repl session. Neither is a TCP listener. `app-server proxy --sock` is the documented way to attach to a unix control socket; that was not used.

Also running: Codex Framework Renderer/Service helpers under ChatGPT.app (Electron-style, user-data-dir `~/Library/Application Support/Codex`), plus `~/.codex/computer-use/Codex Computer Use.app` (`SkyComputerUseService`). Those are the GUI, not the CLI JSON-RPC server.

## Node vs Rust

This Mac’s CLI is the **Rust** OpenAI Codex CLI (`codex-cli 0.159.2`, Mach-O, `variant: "codex"`), shipped inside ChatGPT.app. It is the same product family as npm `@openai/codex`, but **0.159.2 is not installed via npm here**. A later installer that `npm i -g @openai/codex` would be a second copy, currently newer on the registry (0.160.1), and would still not be on PATH unless a shim is added.

## What was not done

- No `app-server generate-json-schema` / `generate-ts` (would write files).
- No `app-server proxy`, no unix attach, no WebSocket, no JSON-RPC.
- No `auth.json` read.
- **No question was forwarded.** Observation only.
