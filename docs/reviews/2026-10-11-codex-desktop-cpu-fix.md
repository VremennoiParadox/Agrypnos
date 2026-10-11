# Codex desktop CPU idle fix — 11 October 2026

## Confirmed cause and correction

The classifier recognized Codex desktop renderers/services as Codex agent processes and allowed their CPU activity to count as work. At or above the 5% CPU threshold, desktop activity alone could continually reset the Agents quiet wait, even after the last Cursor subagent transcript write became stale. With Agents duration there is no fixed deadline; the watch can therefore remain armed.

The correction excludes recognized Codex desktop executable paths from CPU-only busy evidence. Fresh desktop transcripts still count. Real CLI processes, bundled CLI executables, Node wrappers, and positional prompts retain CPU evidence. Bare names without a desktop executable path remain CPU eligible because an agent prompt can contain the same words as a helper name.

Cursor connection loss can leave the job unfinished, but a surviving Cursor process alone is not busy: its transcript writes must also remain fresh. The reproduced cross-provider CPU defect is the strongest identified explanation for this incident. Missing historical CPU and per-provider watch decisions mean the actual overnight blocker is not conclusively proven, and the original connectivity failure remains unexplained.

Dim panel and Sleep panel both leave the watch active. Neither independently puts the Mac to sleep. Panel behavior, sleep paths, networking, preferences, notifications, and the running application were not changed.

## Verification

- Before implementation: four regression tests, 18 failed assertions demonstrating false busy and missed settlement.
- After implementation: original four tests pass.
- Independent review: one Important finding, valid CLI positional prompts were suppressed. One new test first failed three assertions; the guard was narrowed to executable paths; all five regression tests now pass.
- Final regression proves a final Cursor subagent write expires through 45-second freshness and 120-second settle grace, producing disengage and sleep-request commands at 165 seconds in both panel modes. This is command-level proof, not physical sleep or overnight battery proof.
- Final suite: 801 tests pass, zero failures, with OpenCodePluginNativeTests excluded.
- Full unfiltered baseline and implementation suites both failed in the same test: OpenCodePluginNativeTests.testProductionPluginRepliesThroughRealSocketToOriginalOpenCodeChat. Its real OpenCode socket fixture timed out at 65 seconds. This unrelated integration was not modified.
- Final isolated macOS Release app build succeeds; whitespace check passes.

The fix is saved on local branch `codex/ignore-desktop-agent-cpu`, based on `discord-bot-outbound` commit `ec3adb9`. The original checkout and its unrelated edits are preserved. The fixed build is in this worktree's `dist/Agrypnos.app`; it has not replaced or restarted the running app.

## Rulings I made

- Ruling: Continue the previously proposed correction under the human's request to fix and report — the design was already presented in the investigation — cost if wrong: desktop transcript detection must remain intact.
- Ruling: Use an isolated worktree of discord-bot-outbound HEAD — unrelated dirty edits are not required by the unchanged classifier — cost if wrong: final patch also needs verification against the dirty working copy.
- Ruling: Exclude desktop UI CPU only; preserve classification for fresh transcript evidence — avoids reducing Codex support — cost if wrong: genuine UI-only work without transcript writes remains unobservable.
- Ruling: Continue the independent classifier fix despite the pre-existing OpenCode native integration timeout; retain and report the full-suite failure rather than editing question relay code — cost if wrong: the unrelated relay still needs its own validation.
- Final: Ruling: preserve CPU evidence for ambiguous bare names; suppress desktop CPU only with a matching executable path — native probe uses ps args with observed full desktop paths — cost if wrong: a desktop process reporting only an ambiguous bare name can still hold wake.
- Final: Ruling: inherited installation-directory spaces classification remains out of scope; remove its vacuous test row — no recognition change is necessary for this CPU fix — cost if wrong: fresh transcript activity under that unusual installation path can remain unrecognized.
- Final: Ruling: unsupported alternative bundle layouts remain outside this observed executable-path correction — no established supported installation was identified — cost if wrong: those desktop layouts could still produce false busy.
- Final: Ruling: physical sleep and exact overnight attribution remain unverified; report command-level proof only — missing historical CPU decisions and no overnight test — cost if wrong: the original overnight blocker could be different.
- Final: Ruling: unchanged OpenCode relay timeout remains separate from this fix — reproduced before implementation — cost if wrong: that integration remains unvalidated in this environment.

No deferred minor findings. The independent reviewer identified only the corrected Important finding.
