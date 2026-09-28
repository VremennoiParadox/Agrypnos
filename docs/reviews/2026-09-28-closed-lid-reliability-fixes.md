# Closed-lid reliability fixes — execution report

Date: 2026-09-28. Branch: `codex/agent-observation-continuity`.
Implementation base: `0b657a487640331524366105cf504f131578c353`.
Plan: [remaining reliability fixes](../superpowers/plans/2026-09-28-closed-lid-reliability-fixes.md).

The remaining audit fixes are implemented locally. The branch stays unmerged and unpublished for this round; the running app has not been replaced or launched. These changes address reproducible software defects. They do not establish the cause of the user's historical lock-screen incident.

## Result

- Delayed idle notifications no longer preserve stale permission to sleep. Successful manual off cancels the pending continuation; the runtime keeps observing the lid during the hold. An observed open invalidates confirmation, and a reclose must be confirmed again. Sleep is vetoed at the command boundary if the lid is open.
- Kernel reads distinguish held, clear and unknown. Disarm verifies release through the same path for local controls and Telegram/Discord. Failed reassertion stops hygiene and records a real wake-protection failure. Background reassertions do not open an authorization prompt.
- Main app and cleanup helper retain independent ownership of the same per-user lock. A competing cooperating instance cannot acquire ownership until both release it, including either lifetime order.
- Exact `opencode.db-wal` writes count alongside the main database. Future timestamps cannot count as fresh activity or establish reliable idle. No generic WAL/SHM matching, provider CPU changes or freshness-duration changes were added.
- Switching A→B or disabling a previously applied floor/backlight restores captured values before changing the preference. Captures and applied effects are tracked separately; nil captures skip writes. Power B enforces armed, confirmed-closed and current raw-lid gates.
- Native commands drain stdout and stderr concurrently and have a default three-second deadline with TERM/KILL cancellation. Verified private process groups are killed even when the leader has already exited; explicit authorization commands retain a 120-second timeout.

OpenCode's [upstream database implementation](https://raw.githubusercontent.com/anomalyco/opencode/dev/packages/core/src/database/database.ts) names `opencode.db` and enables WAL. The regression uses a temporary real SQLite WAL database; installed provider versions were not inspected. GUI environment constraints are documented in README.

## Independent review and final fix pass

One independent review covered `0b657a4` through `b85c371`, before the final fix pass. It identified six Important findings and no Critical findings. Each reproduction was adopted into native tests and failed before the repair. The reviewer did not perform a second review of the final patch; the executor verified the fixes with the full suite and app build.

| Reproduced finding | Applied fix |
| --- | --- |
| Disarm could reassert the hold while confirming a pending close | Off-path lid sampling observes state without applying close commands |
| Lid could open during blocking kernel clear/readback | Recheck after release and immediately before sleep; restore based on actual command outcome |
| POST completion could reuse confirmation from before an observed open/reclose | Preserve live confirmation during the hold and keep lid sampling active |
| Power B could sleep an open panel after blocking reassertion | Enforce armed and current confirmed-lid gates at execution |
| Main ownership could disappear when helper exited early | Retain the main ownership handle independently of Foundation Process |
| A TERM-ignoring descendant could survive its exiting leader | Escalate against the verified private group even after leader exit |

The remaining unknown-state quit message now says release could not be verified. Disabled inbound lid predicates now check preferences before loading saved secrets; earlier native fixture runs reached the old predicates indirectly. No secret values were printed, and no live bot operations were performed.

The former Core assertion that lid confirmation resets during a pending POST was updated to expect preserved live confirmation. Open-lid and confirmed-closed off/sleep assertions remain, with native open/reclose regressions covering invalidation.

## Verification on final sources

- `swift test`: **617 tests passed, zero failures**, including Core and macOS native runtime/adapters. Power, lid, notification, POST and device operations use injected boundaries; fixture subprocesses and temporary SQLite exercise actual local behavior.
- `xcodebuild`, Agrypnos Debug, ad-hoc signing: **BUILD SUCCEEDED**. The temporary bundle was registered by the normal build step; it was not opened or installed over the running app.
- Actual Mac collector check: process-table failures, missing/error roots, metadata errors, traversal budgets, expired positive evidence and real temporary subagent files passed.
- `Scripts/check-file-sizes.sh`: tracked files within 600 lines. `git diff --check`: clean.

Local evidence: `/tmp/agrypnos-final-fix-red.log`, `/tmp/agrypnos-final-green.log`, `/tmp/agrypnos-reliability-app-build.log`, and `/tmp/agrypnos-reliability-audit/final-mac-collector/checks.log`. The original independent review is `/tmp/agrypnos-reliability-audit/reliability-implementation-review.md`.

## Scope and remaining checks

**S1 quiet-but-unfinished workloads remain excluded at the user's request.** No longer idle wait, infinity workaround, task-completion inference or think-detection was implemented. The earlier continuity plan was corrected to remove that mitigation recommendation. Notification means local signals stayed idle through the existing wait; it does not mean the task finished.

Real closed-lid wake, screen/password behavior, brightness/backlight restoration, panel sleep and more-than-one-hour A/B runs still require Mac optical verification. A locked screen alone does not establish system sleep or universal agent interruption; these tests make no hardware longevity claim.

Live provider-version paths, sleep/wake callback delivery and Telegram/Discord transport were not exercised. The Discord replay-after-RESUMED hypothesis remains rejected, with no new protocol workaround. Ownership is per user and requires participating builds; cross-user and pre-fix binaries are not covered. A speculative ProcessOutput read/close race was not independently established and was not expanded into another fix.

Commits before the final pass: `7831221`, `ef43766`, `93ac70f`, `47a9483`, `b85c371`. The final review repairs, regressions and this report are saved in the next local commit. Keep the worktree and branch for the user's hardware testing; do not merge or deploy.
