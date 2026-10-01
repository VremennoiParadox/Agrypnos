# OpenCode server-plugin feasibility — historical FAIL

Date: 2026-10-01. Installed host: **OpenCode 1.18.32**. This is Task 1 of
the [one-button setup plan](../superpowers/plans/2026-10-01-opencode-one-button-setup.md).
The human authorized execution after planning and cleanup.

The external global `.js` probe loaded during ordinary TUI startup, but its
supplied public client had **no question reply or pending-list methods**.
No supported connection from an external plugin to the ordinary process's
in-process question API was established. The feasibility gate fails;
Tasks 2–6 were not started. The one-button feature is **not implemented**.
The existing HTTP source, settings, UI, and human-confirmed Telegram flow
remain unchanged.

## Observed runtime evidence

The disposable [probe](../../Scripts/probes/opencode-plugin-question.js)
was copied into an isolated XDG config root at
`config/opencode/plugins/agrypnos-probe.js`. Config, data, cache, state, and
project files were under `/private/tmp/agrypnos-plugin-feasibility-f1vwg8q_`.
The user's global plugin/config and bot credentials were not modified.
The host environment was cleared; no model prompt or bot request was sent.
The fixture still discovered user-level skills through OpenCode's normal
home-directory discovery; it was not a completely isolated home directory.

Command: `/opt/homebrew/bin/opencode <fixture>/project`, with no
`--hostname`, `--port`, `serve`, or replacement agent session. Environment:
isolated `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_CACHE_HOME`,
`XDG_STATE_HOME`; `OPENCODE_DISABLE_AUTOUPDATE=1`,
`OPENCODE_DISABLE_DEFAULT_PLUGINS=1`, `OPENCODE_DISABLE_MODELS_FETCH=1`,
and `AGRYPNOS_PROBE_OUTPUT=<fixture>/canonical-runtime.json`.
Default-plugin disabling is distinct from `--pure`, which disables external
plugins too. No user-managed listener was requested.

The first sandboxed startup waited on dependency initialization. An
unsandboxed startup loaded the probe; a further startup with the warmed
fixture reproduced the missing methods. Only fixture processes were stopped.
The final sanitized runtime report, after disposal, was:

```json
{
  "loaded": true,
  "hostVersion": "1.18.32",
  "questionReply": false,
  "questionList": false,
  "globalHealth": false,
  "publicRequest": false,
  "nodeNetAvailable": true,
  "directoryMatches": false,
  "disposed": true,
  "questionAskedObserved": false,
  "cases": {}
}
```

Host version came from executing the running host's `process.execPath`
with `--version`; it was not a compiled plugin constant. Independent
`/opt/homebrew/bin/opencode --version` also returned `1.18.32`.
Importing `node:net` succeeded. The returned `dispose` hook ran on shutdown.
The supported `input.client.path.get({ signal: AbortSignal.timeout(2000) })`
call completed, but did not establish matching directory scoping, even with
canonical path comparison. Directory/auth correctness is **unproved**.
No credential-bearing response or question content was logged.

## Public contract inspection

The pinned [plugin input](https://github.com/anomalyco/opencode/blob/v1.18.32/packages/plugin/src/index.ts)
types `client` using the legacy SDK, and the
[plugin implementation](https://github.com/anomalyco/opencode/blob/v1.18.32/packages/opencode/src/plugin/index.ts)
creates that client with directory/auth and an in-process fetch fallback.
Runtime absence of `client.question.reply`, `client.question.list`,
`client.global.health`, and `client.request` agrees with the inspected
[legacy SDK](https://github.com/anomalyco/opencode/blob/v1.18.32/packages/sdk/js/src/gen/sdk.gen.ts).
Its underlying `_client` is protected; the probe never accessed it.

The public [v2 SDK](https://github.com/anomalyco/opencode/blob/v1.18.32/packages/sdk/js/src/v2/gen/sdk.gen.ts)
does expose `question.list(parameters?, options?)` and
`question.reply({ requestID, directory?, workspace?, answers? }, options?)`.
That alone does not connect it to the original process: the supplied legacy
client provides no proved public way to obtain its in-process fetch/auth
transport. Creating a separate v2 network client was not used as a substitute.

Pinned [ordinary TUI startup](https://github.com/anomalyco/opencode/blob/v1.18.32/packages/opencode/src/cli/cmd/tui.ts)
selects a worker/in-process transport unless explicit port/hostname or mDNS
arguments request an external server. The plugin's default URL can therefore
name `localhost:4096` without identifying a listening instance. The probe did
not contact that URL, scan ports, or start a server. No socket-level audit of
all OpenCode network exposure was performed.

The pinned [global loader](https://github.com/anomalyco/opencode/blob/v1.18.32/packages/opencode/src/config/plugin.ts)
scans `{plugin,plugins}/*.{ts,js}`. XDG `.js` discovery was observed; normal
user-root discovery, custom roots and external-plugin-disabled startup were
not separately exercised after the reply/list gate failed.

The [question service](https://github.com/anomalyco/opencode/blob/v1.18.32/packages/opencode/src/question/index.ts)
removes the pending request and publishes `question.replied` before completing
its deferred answer. Missing requests raise `Question.NotFoundError`.
These are source observations, **not live plugin acceptance/race proof**.
No original-question reply expression, native payload, or acknowledgment
contract was validated for this plugin.

## Acceptance results and verification

The six acceptance checks were written and run before the runtime probe.
An empty evidence report produced six expected failures. The actual runtime
report also produced exit **1**, with **native case not observed** for each:

| Case | Native evidence |
| --- | --- |
| `ordinaryStartupOriginalReply` | Unproved: no original B continuation/reply |
| `localAnswerWins` | Unproved: no local-versus-remote race |
| `resolvedBeforeAcknowledgment` | Unproved: no live acknowledgment race |
| `twoProjectsAndProcesses` | Unproved: no two-conversation routing |
| `appUnavailableLeavesLocal` | Unproved: no pending prompt/IPC failure experiment |
| `publicContractOnly` | Failed prerequisite: supplied client lacks reply/list |

These are six failed **evidence checks**, not six completed native experiments.
The probe does not fabricate session/request identities or continuation counts.
No new Telegram/Discord, Mac optical, recovery, safety, or energy proof exists.

Re-run the evidence checker against a captured probe report:

```sh
node Scripts/probes/opencode-plugin-question.js --verify /path/to/runtime.json
```

Expected for this captured report: exit 1, six failures. `node --check` passed.
The unchanged Swift baseline passed **735 tests, zero failures**.
No app source/resource changed, so new Debug/Release app builds were not run.

## Required design revision

Proceed only after proving a supported original-process reply/list transport
for external plugins in the permitted version, or reviewing a different
connection design/version with the human. Automatic port discovery, accessing
`_client`, private imports, and starting a replacement server/conversation
were not substituted for the missing capability. The working explicit HTTP
integration remains the available setup.

## Review disposition

A fresh reviewer checked the two local probe/evidence commits and captured
runtime against the plan: no Critical or Important findings; the failed gate
was upheld. One minor is deferred: the probe's CLI usage string spells the
tracked `Scripts/` directory as lowercase `scripts/`, which fails on a
case-sensitive filesystem. The reproducible command above uses the correct
spelling. No product implementation or new live acceptance was reviewed.

## Authorized terminal-plugin revision — native gate PASS

The human approved the terminal-plugin proposal and implementation after this
server-plugin failure. Its separate public surface is available in 1.18.32:
[terminal plugin input](https://github.com/anomalyco/opencode/blob/v1.18.32/packages/plugin/src/tui.ts).
A default-exported `{ id, tui }` module registered in global `tui.json` receives
`api.app.version`, `api.client` (SDK v2), `api.event.on` and
`api.lifecycle.onDispose`. Dropping a file in plugins/ alone is insufficient.

The reproducible `Scripts/probes/opencode-tui-fixture.py` uses normal TUI
startup with `--prompt` solely to create the harmless test conversation,
no OpenCode listener flags, and a deterministic local OpenAI-compatible model.
The fixture emulates model output only; the actual installed OpenCode question
tool, registry, TUI, SDK transport, replies and persisted conversation are real.
It uses no paid provider, bot credentials or existing user conversation.
The model's title-generation request has no question tool; the actual session
request does. The original session alone continues after the native answer.

Public expressions successfully exercised:
`api.client.question.list({ directory })`,
`api.client.question.reply({ requestID, directory, answers: [["B"]] })`,
`api.client.session.messages({ sessionID, directory })`;
`api.event.on("question.asked", ...)`, `question.replied`, `session.idle`.
Version came from `api.app.version`, not a compiled constant.
Reply acceptance was HTTP 200 plus JSON true. The supplied client handled the
original worker transport without exposing an OpenCode network listener or
extracting protected fields/authentication. `node:net` import and disposal
worked. Initial pending lists were empty; the actual asked ID/session then
appeared in the native list before submission.

Two simultaneous fixture processes/projects independently resumed their
original sessions, each with one B marker and one remote reply attempt.
Both observed question.replied before reply acknowledgment; neither claimed
acceptance from that event. An independent native API answer won another
fixture request, yielding one original B continuation and zero remote attempts.
That is an automated competing-native-API characterization, not a physical
local keyboard-click proof. With an absent Unix socket, the native question
remained in the TUI state and pending list, with zero replies and no continuation.
All six evidence checks passed against these captured native results.

Global registration was exercised in isolated XDG tui.json roots. Real user
config installation, alternate/custom-root overrides, disabled-plugin startup,
live Telegram/Discord, physical Mac/local-answer races, and energy remain
separate unperformed acceptance categories. Product runtime must fail visibly
when overridden/disabled rather than claiming an installed plugin is connected.
The server-plugin failure above remains valid for that older client surface.
