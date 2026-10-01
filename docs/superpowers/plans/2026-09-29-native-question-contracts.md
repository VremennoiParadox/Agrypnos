# Native question contracts — blocked supplement

Status, 2026-10-01: **all-provider contracts remain incomplete**. The human authorized the [OpenCode-only milestone](2026-10-01-opencode-relay-milestone.md), which is wired into the test app; its HTTP/Telegram/original-chat flow is human-confirmed. This accompanies Task 1 of the [implementation plan](2026-09-29-native-agent-questions.md); see the [observed compatibility evidence](../../reviews/2026-09-29-native-question-compatibility.md) and [current handoff](../../reviews/2026-10-01-opencode-one-button-handoff.md).

OpenCode 1.18.32 has both the disposable native API proof below and the later human-confirmed Agrypnos/Telegram flow. The all-four gate remains open. Claude/Codex/Cursor contracts remain unresolved; the proposed OpenCode global plugin needs its own native feasibility proof.

| Adapter | Contract needed before implementation | Current gap |
| --- | --- | --- |
| Claude | Exact hook input/output on the installed terminal and desktop surface; original session/tool-use identity; selected-answer encoding; fallback/630s hook behavior; coexistence with denials; consumption evidence | Documented candidate only; no native live probe. Hook stdout alone must not become an acceptance claim. |
| OpenCode | Explicit active instance endpoint/auth/directory; pinned version and route family; request/session identity; SSE event and pending-list schemas; reply/cancel acknowledgment; reconnect behavior | HTTP source and Notif setup are wired; the user confirmed Telegram answers return to the original chat. Live Discord, reconnect, deadline and simultaneous-session coverage remain open. Plugin setup is a separate unproved candidate. |
| Codex desktop | Supported attachment to the original desktop server; initialization/subscription; original RPC ownership; request/resolved schemas; reply receipt versus actual acceptance; pending recovery | Default control socket absent; actual server has no observed named Unix endpoint. Another server's resumed history is insufficient. |
| Cursor desktop | Supported desktop event and answer interface; instance/conversation/generation/request IDs; full question/option fields; native cancellation/expiry; local-answer conflict resolution and recovery | Sonnet 5.5 High rendered a native question and consumed a local B answer; neither working pre/post tool hook observed it. Public hooks/ACP/SDK do not establish the required existing-desktop event/response path. |

For every row, the supplement must eventually include sanitized **observed** payloads, exact versions, callable signatures/configuration, fixture assertions and failure outcomes. A public example can guide a probe but cannot replace its result. Freeze/review this supplement only after all four same-conversation gates pass.

## Observed OpenCode 1.18.32 subset

The official release server and an ordinary TUI were attached to the same explicit `127.0.0.1:4096` endpoint and disposable directory. Basic auth was enabled. The version was `1.18.32`; no other version is covered. Source inspection of the matching local release and the live server yielded these shapes (opaque IDs and paths below are sanitized):

```json
{"id":"que_…","sessionID":"ses_…","questions":[{"question":"Which test letter?","header":"Test letter","options":[{"label":"A","description":"Choose A"},{"label":"B","description":"Choose B"}]}]}
```

`GET /question?directory=<encoded directory>` returned this pending record. `GET /global/event` emitted `{"directory":"<directory>","payload":{"type":"question.asked","properties":{"id":"que_…","sessionID":"ses_…","questions":[…],"tool":{"messageID":"msg_…","callID":"call_…"}}}}`. `POST /question/que_…/reply?directory=<encoded directory>` with `{"answers":[["B"]]}` returned JSON `true`, removed the pending record, and the original session produced `OPENCODE_QUESTION_TEST_B`. Answering a second question locally first made a later external reply return 404 `QuestionNotFoundError`; that session produced its local A continuation. A successful HTTP response supports `.accepted` for this observed request only after correlating the pending ID/session and the `true` result. Network loss after POST remains `.unconfirmed`, never an automatic retry.

This native API proof supplied the decoder/reply contract used by the subsequently authorized OpenCode-only test build. That build requires an explicitly configured endpoint and directory for the instance hosting the user's existing chat, rejects redirects, and reconciles known pending requests without extending deadlines. Cancellation and restart handling have automated coverage; the complete live matrix and all-four release gate remain open.

The branch contains `OpenCodeQuestionPayload` and `OpenCodeQuestionSource` with fixture tests for the observed request/event, label-based reply, local-answer race and ambiguous HTTP result. The source requires an explicit loopback endpoint and directory and checks the server version. Its byte-level SSE reader preserves blank event separators; an in-memory HTTP test exercises Foundation's actual byte stream. On stream loss it invalidates phone controls and retains original request timing. Reconciliation can reissue only an identical, previously observed, still-pending request before its original deadline. Unknown, changed, expired or previously attempted requests cannot be reissued; an uncertain send cannot be retried. Releasing the source cancels its background connection. These are automated fixture results, not live reconnect proof. The source is now wired into WatchRuntime and Notif setup. The user confirmed its Telegram round trip; Discord's live question round trip remains open.

Provider-independent Tasks 2–4 and 9 and the staged OpenCode source/setup have local implementations. Claude/Codex/Cursor adapters and Task 10's full release matrix remain incomplete. Preserve the approved 600-second policy, busy/unknown protection, original deadlines and no-skill requirement; none has been relaxed to work around these gaps.

OpenCode publishes a native resolution event before completing its reply handler. If that event arrives during Agrypnos's reserved POST, the source retains the in-flight response path and uses the POST outcome: JSON `true` with HTTP 200 is accepted, 404 is rejected, and a lost response remains unconfirmed. The event alone does not prove which responder won. A regression exercises both successful remote delivery and a local winner in that ordering.

## Shelved Claude codec candidate

The unused `ClaudeQuestionPayload` codec and its eight documentation-fixture tests were removed in the authorized 2026-10-01 cleanup. They remain recoverable from commit `499dcba`; no runtime caller or installed hook depended on them.

The candidate used the documented `PreToolUse` / `AskUserQuestion` shape: `session_id`/`tool_use_id`, original `tool_input.questions`, and an `answers` map in `hookSpecificOutput.updatedInput`. Prompt-key and comma-delimited mappings need ambiguity checks. These were documentation-based fixtures, not observed Claude payloads. No helper/socket or runtime adapter is enabled; timing, denial coexistence, cancellation and actual answer consumption remain unverified. Revisit the native gate before restoring code. [Official hook reference](https://code.claude.com/docs/en/hooks#pretooluse).
