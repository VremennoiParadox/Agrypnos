# Agent observation continuity — independent review

Date: 2026-09-28.
Base: `d34ff596dea47ecaa9d2deaa076e37f6404de49a`.
Final reviewed head: `a425fa0577e229f2daac3c3711f6af04ffa5813f`.

**Verdict: ready to merge as a bounded observation-continuity fix.** No unresolved critical, important, or minor findings. This verdict does not establish that the historical long-task incident is resolved or that native sleep/wake behavior is Mac-proven.

## Scope and method

Reviewed the source diff, investigation/spec, implementation plan, new continuity and probe-validity tests, changed existing test fixtures, actual Mac collector check, lifecycle wiring, outbound/hold coordination, and diagnostics. The user waived the repository's Grok model rule for this task.

The review was independent and performed without delegation. No application source was modified by the reviewer. No app was launched, Mac was locked or slept, power command was invoked, secret was read, or external message was sent. This review document is the only reviewer-authored file.

## Strengths

- `AgentSettleTracker` separates factual `lastBusyAt` from the quiet-wait baseline. Gaps over 15 seconds, backward time, and explicit interruption restart the wait while preserving busy history. Read-only status cannot extend observation continuity.
- `AgentProbeObservation` rejects delayed collection, stale delivery, and invalid timestamp ordering. Selected positive evidence remains useful even when another measurement is incomplete; incomplete negative evidence cannot advance settling.
- Process failures and malformed rows, filesystem failures, missing metadata, and traversal-budget exhaustion are distinguished from valid empty results. Missing optional roots remain normal absence.
- Cache validity is measured from collection completion and checks the selected tools, terminal preference, and backward time. The final patch safely caches timely partial positives while leaving incomplete negatives uncached.
- Sleep/wake callbacks invalidate the generation and cache and interrupt settling independently of inbound notification settings. Wake polls without arming an off watch. A new user arm and relevant preference changes invalidate old callbacks.
- Safety polling remains active during unavailable or pending observations. Manual/inbound off, the one-POST latch, release failure rollback, and the existing confirmed-lid sleep path remain intact.
- Changes preserve the selected-provider heuristics, 45-second freshness default, 2–15-minute idle wait, and terminal default OFF. No lock/security setting, display prevention, new busy provider, or network behavior was introduced.

## Findings resolved during review

### Important / P2: expiring positive shortcuts could become complete idle evidence

At the initial reviewed head, the walker could stop at a transcript fresh at collection start, skip another root with fresher activity, and still label the result complete. Reevaluation at collection completion could then expire the stopped-positive and accept idle evidence despite the incomplete traversal.

The reviewer reproduced this against the actual Core and Mac adapter sources using a stdin-only Swift harness: first transcript age 44 seconds at start, skipped transcript age 1 second, completion 2 seconds later. The initial result was `complete=true`, skipped root unvisited, and idle accepted.

Resolved in `a425fa0`: the root shortcut at `Apps/Agrypnos/Sources/Agent/AgentProbeService.swift:95` and traversal shortcut at line 176 mark the collection incomplete for negative inference. Timely selected positive evidence remains accepted. The actual adapter regression at `Scripts/check-agent-probe-macos.swift:47` covers an expiring shortcut with an unvisited fresh nested file.

The reviewer reran a full-collector harness at the final head. It exited 0 and verified both that the expired shortcut is unknown and that the same partial result remains busy while timely. `WatchRuntime+Poll.swift:125` caches only usable evidence; `AgentProbeObservation.settleBusy` prevents an incomplete negative from reaching that branch.

### Minor: observation-gap diagnostics were hidden by deduplication

A long observation gap while already settling could reset the quiet baseline without changing probe/status booleans, so transition deduplication omitted the gap itself.

Resolved in `a425fa0`: `WatchRuntime+Poll.swift:165` records a greater-than-15-second or backward gap before the tick. The event is emitted only at the discontinuity. `a3e44d6` also retains the pre-disengage tracker for end diagnostics instead of reporting the reset tracker.

## Verification and limits

The reviewer directly executed the failing initial reproduction and passing final reproduction against the actual sources, and ran `git diff --check` successfully. New and updated tests were inspected for meaningful continuity, busy-history, safety, timestamp, selected-positive, and once-only behavior.

The implementer reports final verification of all 592 Core tests, the actual Mac adapter script, the Debug app build, and file-size/whitespace checks. The reviewer did not independently rerun that full suite or app build. The implementer also reports a standalone actual Logger check; this is not running-app verification.

Still pending: actual running-app OSLog behavior, native sleep/wake callback ordering and late-result rejection, and a matching greater-than-one-hour workload while locked in Power A/B. These remain explicit optical/debugger checks. Complete continuous observations can still be quiet during unfinished work because the permitted heuristics do not detect thinking or task completion. The final documentation preserves this limitation and does not claim an anti-lock fix or a proven explanation for the September 27 incident.
