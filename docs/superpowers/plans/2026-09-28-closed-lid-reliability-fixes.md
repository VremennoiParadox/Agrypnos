# Closed-lid reliability fixes — execution plan

Authority: local reliability audit dated 2026-09-28, with S1 explicitly excluded by the user. Continue codex/agent-observation-continuity from 0b657a4; do not merge or install/restart the running app.

The original observation-continuity Tasks 1–4 are already committed. This plan implements the remaining audited defects. No changes to grace, freshness duration, provider CPU rules, password settings, or task-completion detection. Narrow Mac test seams and tests are permitted; real power commands, secrets and live bot operations are not part of automated verification.

1. Deferred POST sleep: add native runtime regressions for delayed completion/lid changes/manual off, watch them fail, cancel stale user-off continuations and revalidate the final sleep gate; retain once-only POST and confirmed-closed sleep.
2. Kernel truth/ownership: test invalid/nonzero pmset reads, inbound clear failures, reassertion failures, and competing cleanup owners. Introduce on/off/unknown truth, share checked disarm behavior, prevent hygiene after failed wake protection and serialize ownership through app/crash-helper lifetime.
3. Session evidence: verify exact supported WAL use with primary sources; test exact WAL sidecars and fresh-WAL/stale-main collection, plus future timestamps. Implement only supported paths and shared bounded-age freshness; unknown clock-skew evidence must not prove idle. Document GUI launch environment constraints; no new session-root UI.
4. Hygiene transitions: test A→B and disabling previously applied floor/keyboard effects, including nil captures. Restore actual applied captures before switching modes/preferences; preserve confirmed-lid gates and no floor under B/open lid.
5. Subprocess deadlines: test hung process and simultaneous stdout/stderr load with harmless fixture processes. Bound execution/pipe draining and surface timeout failures without changing the sudoers commands.
6. Verification and review: full Core + macOS adapter tests, Mac app build, changed-source line limits, one independent whole-branch review and a TDD fix pass for important findings. Record remaining hardware/provider limits. Commit local changes; no merge, publish, install, or live Mac sleep tests.

Each task's verification and deviations go in .superpowers/sdd/2026-09-28-closed-lid-reliability-fixes/progress.md. Scope decisions: S1 is documentation only; Discord replay-after-RESUMED was rejected; optical >1-hour A/B testing remains user verification, not an automated reliability claim.
