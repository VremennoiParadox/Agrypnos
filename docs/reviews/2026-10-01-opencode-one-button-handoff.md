# OpenCode one-button setup — next-chat handoff

Snapshot: 2026-10-01. Repository `/Users/imightbeoufu/Developer/Agrypnos`.
Branch `codex/agent-question-relay`; product checkpoint
`0f8d3f2b777b443ef771ee31ff7cbdfd1c27e981`.
This document is newer than the earlier question-relay handoff and supersedes
its implementation/live-test status. Check current Git state before continuing.

## Later verification update — 2026-10-01

The one-button terminal plugin is implemented and **live verified by the user** in launched build `7e8661c`: “opencode is working.” See the [verification record](2026-10-01-opencode-one-button-verification.md) for current evidence and remaining acceptance categories. The sections below preserve the pre-implementation snapshot; their unpassed-gate and unimplemented-plugin statements are historical.

## Start here

1. Read `AGENTS.md`, the [OpenCode milestone](../superpowers/plans/2026-10-01-opencode-relay-milestone.md),
   and the [native-question design](../superpowers/specs/2026-09-29-native-agent-questions-design.md).
   The earlier [handoff](2026-10-01-question-relay-handoff.md) contains provider
   investigation details, but its statement that OpenCode is unwired is stale.
2. Follow `superpowers:using-superpowers`. Use brainstorming/writing-plans
   for the new integration design; TDD, systematic debugging, verification,
   and review for subsequent implementation as applicable.
3. Read the saved [one-button integration plan](../superpowers/plans/2026-10-01-opencode-one-button-setup.md).
   Its native feasibility gate remains unpassed; do not promise that the
   plugin eliminates manual server setup before proving that gate.
4. Read the [authorized cleanup record](2026-10-01-question-relay-cleanup.md).
   Preserve the working HTTP integration until its replacement is proved.
   Review the concrete feature plan with the human before executing it and
   validating the new real bot round trip.

The original request was **write this handoff**. The human subsequently
requested the one-button plan, then authorized cleanup of the unused work.
The plan is saved; the unused Claude codec/tests are shelved and stale
status notes are reconciled. No plugin implementation or branch creation
has started. This does not authorize global installation or removal of
working HTTP behavior.

The human previously waived the Grok-only rule for this task: “ignore the
grok rule, you can continue as chatgpt for this task.” Preserve that waiver.
Local commits are authorized; push, merge, and release need further approval.
Keep changes inline unless a user instruction or applicable skill calls for
delegation. CodeGraph tools were unavailable in this chat; `.codegraph/`
exists. Prefer CodeGraph if callable in the next chat.

## What the human confirmed

The user tested OpenCode → Agrypnos → Telegram → original OpenCode question
and said: **“The feature works as I intended and is what I wanted.”**
Treat this as human-confirmed live acceptance of that tested flow, not proof
of the whole release matrix. Discord's live question round trip, simultaneous
sessions, recovery, Mac safety/lid behavior, and energy overhead remain open.

The apparent Telegram button failure did not produce a code fix. Inspection
showed the latest question had **✓2** selected. Number buttons select;
**Review / next** then **Send answers** submits. Earlier buttons were stale.
No production source changed during that investigation or the later discussion.

## Intended next experience

The human wants to keep the feature but eliminate tedious repeated setup:

- Connect their own Telegram/Discord bot once.
- Click **Enable OpenCode forwarding** once in Agrypnos.
- Possibly restart OpenCode once after installation.
- Work normally across local projects and sessions, without entering a
  server address, directory, port, or password each time.
- No per-prompt or per-session slash command, skill invocation, or instruction
  to the model. Detect native structured questions automatically.
- Continue answering the original conversation, rather than launching a
  replacement agent session.

The current implementation is **not limited to one session**. It routes by
native instance/session/request identity and accepts sessions on the configured
server/directory. One explicit server/project connection is the setup limit.

## Proposed approach and unresolved proof

A global OpenCode plugin is the preferred **candidate**, not implemented or
validated. OpenCode documents global plugins loaded automatically at startup,
with events, directory/project context, and a supplied client. A proposed
plugin could communicate with Agrypnos through authenticated local IPC and
route replies back to its own original native request.

Before writing the implementation around this idea, prove that the installed
OpenCode 1.18.32 plugin receives `question.asked` with original identity and can
answer that request through supported interfaces in an ordinary existing chat.
Also prove resolution/local-answer races and whether normal OpenCode startup
can support this without the user explicitly exposing a network listener.

Important uncertainty: the inspected 1.18.32 plugin receives an SDK client;
its implementation can use an in-process HTTP handler when no server URL is
present. The inspected legacy generated SDK did not show a question API.
Supplying a client does **not** alone prove a supported question reply method
is available to external plugins. Validate the exact public route/client path;
avoid private imports, protected client internals, or invented hook contracts.
Do not promise “no server required” before this is established.

References checked during discussion:

- [OpenCode plugin loading](https://opencode.ai/docs/plugins/)
- [OpenCode server architecture/authentication](https://opencode.ai/docs/server/)
- [1.18.32 plugin implementation](https://github.com/anomalyco/opencode/blob/v1.18.32/packages/opencode/src/plugin/index.ts)
- [1.18.32 plugin interface](https://github.com/anomalyco/opencode/blob/v1.18.32/packages/plugin/src/index.ts)
- [1.18.32 legacy SDK](https://github.com/anomalyco/opencode/blob/v1.18.32/packages/sdk/js/src/gen/sdk.gen.ts)

An alternative discussed was automatic connection to existing HTTP instances.
Discovery/authentication and multiple-instance ownership would still need a
design. The current approved design requires explicit endpoints and prohibits
port scanning/replacement servers; revise the design explicitly if changing
that contract rather than silently bypassing it.

## Keep the useful work; scope cleanup

The human asked whether brainstorming left enough junk to justify starting
over. The assessment favored preserving this checkpoint and optionally starting
a new `codex/` branch **from it** for simpler setup, rather than rebuilding from
main. No new branch name was chosen or branch created.

Keep the shared registry, sender authorization, complete-answer review,
once-only delivery, Telegram/Discord controls, expiry/recovery handling, watch
policy, and their tests. A plugin changes the native connection, not all of this.
Discord code is wired and tested, though live question validation is pending.
Cursor/Codex native source adapters were never implemented; there are no
abandoned adapters for those providers to remove.

The subsequent cleanup request authorized shelving
`Sources/AgrypnosCore/Questions/ClaudeQuestionPayload.swift` (88 lines with
no app caller) and its 115-line test file: **203 removed lines**. Both remain
recoverable from commit `499dcba`. The codec used documentation-based
fixtures and had no live native validation; revisit the native contract
before restoring it.

Manual connection UI/settings may become unnecessary after the plugin works.
Consolidate stale planning status then; preserve meaningful contract/review
evidence. Avoid rewriting the working relay just to obtain a shorter diff.

The assessment compared against local `origin/main` without fetching:
75 files changed, 5,690 insertions, 37 deletions. Added lines comprise
2,527 production code, 2,233 tests, 894 documentation, and 36 build configuration.
This was a targeted diff/wiring assessment, not an exhaustive new code review.

## Other providers remain separate

- **Claude Code:** documented global `PreToolUse`/`AskUserQuestion` candidate
  remains; the unused codec/tests are shelved. Helper/socket/runtime integration
  and live answer consumption
  are unfinished. The user has no Claude subscription; avoid paid live probes.
- **Cursor desktop:** a Sonnet 5.5 High native A/B test resumed correctly after
  a local click, but functioning pre/post tool hooks did not observe that question.
  A plugin wrapping those hooks does not fix the missing native event/answer path.
- **Codex desktop:** supported attachment/response ownership for the existing
  desktop chat's pending question remains unresolved. A new app-server or SDK
  conversation is not a substitute.

Each tool needs its own supported adapter. Shared bot/watch logic can stay the
same. OpenCode's plugin cannot automatically solve all four. The staged build
enables only OpenCode; the original all-four release gate has not been waived.
See [native contracts](../superpowers/plans/2026-09-29-native-question-contracts.md)
and [compatibility evidence](2026-09-29-native-question-compatibility.md) for detail.

## Security and product constraints

The current server uses HTTP loopback `127.0.0.1:4096`. This is not directly
exposed to the LAN/internet, but unauthenticated local processes can access it;
OpenCode's API has capabilities beyond question answering. Basic authentication
is supported. A local socket is a candidate narrower interface, not a guarantee
of protection from compromised processes running as the same user.

Design authenticated IPC, restrictive file/socket permissions, original-request
ownership, bounded inputs, and safe fallback. Keep bot credentials in Agrypnos;
agent integrations should receive only what their question channel needs.
Question content reaches the user's opted-in Telegram/Discord service. Keep it
out of logs and persistent history. Preserve the user's own bot, explicit
answering-user authorization, and one-time opt-in; no shared hosted bot.

Preserve the existing 600-second monotonic policy while armed, original deadlines,
manual/safety overrides, and once-only native submission with no ambiguous retry.
Forwarding never arms the watch. Free text and permission approvals stay local.
Keep the menu-bar-only five-section UI, existing wake/sleep gates, no third-party
dependency without justification, and the 600-line limit. No wattage claims.

## Local checkpoint and verification

- Latest test app: `dist/opencode-question-test-2026-10-01/Agrypnos.app`.
  It was launched for the user and reads existing preferences/secrets.
- `/opt/homebrew/bin/opencode` was installed from official npm as
  `opencode-ai@1.18.32`; command/version were verified. No global plugin is installed.
- The user started ordinary OpenCode with hostname `127.0.0.1`, port `4096`,
  and `OPENCODE_DISABLE_AUTOUPDATE=1` in this repository. That server hosted
  the tested original conversation. Recheck liveness rather than reusing old PIDs.
- Telegram inbound, forwarding, and OpenCode inclusion were enabled during the
  successful test. The saved Telegram owner matched the private chat. Credentials
  live in `~/Library/Application Support/Agrypnos/notif-secrets.json` (0600).
- Fresh branch-assessment `swift test`: **743/743 passed**, 2026-10-01 10:08 local.
  Log: `/private/tmp/agrypnos-branch-assessment-tests.log`.
- Prior milestone Debug/Release builds and strict bundle signing verification
  passed at product checkpoint `0f8d3f2`; they were not rerun for this handoff.
  [Verification](2026-10-01-opencode-question-verification.md) and
  [review dispositions](2026-10-01-opencode-question-review.md) retain that evidence.
  Their live-test-pending wording predates the human confirmation recorded here.

Tracked product files were clean before this handoff. Preserve pre-existing
untracked `.codegraph/`, `.cursor/`, `.derivedData/`, `dist/`, earlier review docs,
the older handoff, and `2026-09-21-subagent-busy-signals.md`. Preserve the ignored
`.superpowers/sdd/2026-09-29-native-agent-questions/progress.md` ledger because
the all-provider plan remains incomplete. The stock file-size checker scans
untracked artifacts too; earlier failures there were not tracked source failures.

Credential hygiene: a broad process-argument query earlier in the chat exposed
an unrelated worker credential in tool output. The user was informed. Use narrow
or sanitized process queries; never copy that output/key into documents or a
new chat. Avoid printing secrets, credential-bearing URLs, or bot API errors
containing those URLs. Avoid competing Telegram `getUpdates` consumers.

## Suggested opening message for the next chat

“Read `docs/reviews/2026-10-01-opencode-one-button-handoff.md` first. Write the
plan for one-button OpenCode forwarding, including proof of the global plugin's
native question-and-answer path. Keep the current working relay until its
replacement is verified. Review cleanup scope with me before deleting code.”
