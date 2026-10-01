# OpenCode question relay — testable milestone

The human authorized finishing OpenCode first on 2026-10-01, then testing
it before proceeding. Continue on `codex/agent-question-relay`; local commits
only. The existing native-question design remains authoritative. This is a
test build, not an all-provider release.

Status, 2026-10-01: the milestone is implemented; the user confirmed its
HTTP/OpenCode/Telegram/original-chat flow. The remaining Discord, recovery,
simultaneous-session, Mac safety/lid and energy matrix is open. See
[verification](../../reviews/2026-10-01-opencode-question-verification.md) and
the [current handoff](../../reviews/2026-10-01-opencode-one-button-handoff.md).

Update, 2026-10-01: **one-button OpenCode forwarding is also live verified by the user** after launching build `7e8661c`. See the [one-button verification record](../../reviews/2026-10-01-opencode-one-button-verification.md). The original HTTP route remains the manual fallback; the remaining acceptance matrix and other-provider gates stay open.

## Deliverable

OpenCode 1.18.32 on an explicitly configured loopback server and directory
forwards newly observed native questions to the existing Telegram/Discord
connections, with explicit answering-user IDs. Complete selections return
to the original request once. Other providers remain unavailable. Forwarding
defaults off and never arms the watch.

## Steps and evidence

1. Persist optional connection settings and password in the existing 0600
   secrets file without losing old fields. Add TDD coverage for migration,
   round trips, endpoint validation and malformed configuration.
2. Wire the source, real connection state and request closures into runtime.
   Test event-to-bot-to-native routing, local answer/fallback, destination
   changes, source disconnects, manual/safety end, sleep/wake and shutdown.
   Keep original monotonic deadlines; never reject a native question merely
   to relinquish remote answering.
3. Add a Notif forwarding card, bot answering-user fields and OpenCode
   connection fields with explicit Save/Remove. Display actual availability;
   keep the existing five-section popover and native size transitions. Add
   setup/help and a reproducible user smoke test.
4. Run the full Swift suite, Debug/Release builds, tracked file-size and
   whitespace checks. Request a fresh branch review and fix important
   findings with regressions. Prepare a local app and test instructions.

## Validation limits

The user confirmed the Telegram round trip after this milestone; that is
not proof of the remaining bot/Mac matrix. Record automated versus live
evidence separately. Do not enable Claude,
Cursor or Codex or push/merge/release as part of this work.
