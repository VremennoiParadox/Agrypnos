# OpenCode relay test milestone — verification

Authorization: finish OpenCode first, then wait for the human's test feedback.
Branch: `codex/agent-question-relay`. Local work only; no push/merge/release.

## Implemented

- Optional server endpoint/directory/username/password preserved alongside
  existing bot secrets in the existing 0600 file; no global OpenCode change.
- Opt-in OpenCode source wired into runtime, with actual health/version/SSE
  connection state. Exact tested version remains 1.18.32.
- Existing Telegram/Discord bot connections and explicit answering-user IDs
  route complete selections to the captured original request once.
- Native fallback does not call question reject or submit a default.
- Source recreation has a distinct identity. Disconnect reconciliation keeps
  the original deadline. Sleep/app restart leaves pre-existing questions local.
- Notif forwarding and connection cards, explicit Save/Remove, read-only bot
  instructions and README smoke test. Five-section popover stays unchanged.

## Automated evidence

Settings/source/runtime/layout regressions were written and run before the
corresponding implementation. Logs are under `/private/tmp/agrypnos-opencode-*`.
The first integrated suite passed 725 tests; the extended runtime tests cover
Foundation byte-stream ingestion, both bots' controls, manual off, selection/
authorization gates, unchanged/changed setup and native answer after expiry.
Final suite/build/review evidence will be recorded below after verification.

## Human smoke test

1. Open the prepared app after quitting your currently running Agrypnos.
2. Configure the bot and answering user ID, explicit OpenCode endpoint and
   absolute directory, then enable forwarding. Expect the connected caption.
3. In the ordinary chat on that same OpenCode server, trigger a new native
   A/B question with the README marker prompt. Choose B on the bot, review,
   Send answers. The original chat must print OPENCODE_RELAY_TEST_B once.
4. Repeat on the other bot if configured, then answer another question locally
   first and confirm its old phone buttons cannot answer a later question.
5. Check setup fields, Save/Remove, reveal/clear and Notif scrolling/section
   swaps. No outgoing cards should remain painted over another section.
6. With the watch already armed, leave a question unanswered for ten minutes.
   Idle may end the watch; busy/unknown must defer. Manual off and safety
   must invalidate phone controls. Screen lock alone must preserve the wait.

Record exact OpenCode/app/bot versions and any failed step. Live bot round
trips, Mac optical and energy measurements remain unverified until performed.
No all-provider support or measured-wattage claim follows from unit tests.

Final automated result: full Swift suite **743/743 PASS**; app **Debug and
Release BUILD SUCCEEDED**. The fresh branch review found four Important
issues; these and two smaller findings were fixed with regressions. See
[review dispositions](2026-10-01-opencode-question-review.md).

Tracked files plus milestone additions pass the 600-line cap. The stock
checker also scans pre-existing untracked build binaries and two earlier
untracked docs, which exceed that limit and were preserved unchanged.
`git diff --check` passes. No real bot message, user session change or running
app replacement was performed.

Prepared Release app:
`dist/opencode-question-test-2026-10-01/Agrypnos.app`.
The bundle uses ad-hoc signing for this local test; `codesign --verify --deep
--strict` passes. Quit the currently running Agrypnos before opening it.
It reads your existing preferences; forwarding still defaults off. The app
has not been launched by the executor. Live proof remains the next step.
