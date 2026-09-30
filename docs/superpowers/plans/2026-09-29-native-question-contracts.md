# Native question contracts — blocked supplement

Status: **not frozen, not approved for implementation**, 2026-09-29. This accompanies Task 1 of the [implementation plan](2026-09-29-native-agent-questions.md); see the [observed compatibility evidence](../../reviews/2026-09-29-native-question-compatibility.md).

One disposable OpenCode 1.18.32 TUI/server same-session choice round trip has been verified. The all-four gate remains open. No production initializer or recovery algorithm is frozen for Tasks 5–8; inventing missing interfaces would hide the unresolved dependency.

| Adapter | Contract needed before implementation | Current gap |
| --- | --- | --- |
| Claude | Exact hook input/output on the installed terminal and desktop surface; original session/tool-use identity; selected-answer encoding; fallback/630s hook behavior; coexistence with denials; consumption evidence | Documented candidate only; no native live probe. Hook stdout alone must not become an acceptance claim. |
| OpenCode | Explicit active instance endpoint/auth/directory; pinned version and route family; request/session identity; SSE event and pending-list schemas; reply/cancel acknowledgment; reconnect behavior | Official 1.18.32 TUI/server proved same-session GET/POST and SSE; active user instance, reconnect, deadline, simultaneous-session and bot integration remain. |
| Codex desktop | Supported attachment to the original desktop server; initialization/subscription; original RPC ownership; request/resolved schemas; reply receipt versus actual acceptance; pending recovery | Default control socket absent; actual server has no observed named Unix endpoint. Another server's resumed history is insufficient. |
| Cursor desktop | Supported desktop event and answer interface; instance/conversation/generation/request IDs; full question/option fields; native cancellation/expiry; local-answer conflict resolution and recovery | Sonnet 5.5 High rendered a native question and consumed a local B answer; neither working pre/post tool hook observed it. Public hooks/ACP/SDK do not establish the required existing-desktop event/response path. |

For every row, the supplement must eventually include sanitized **observed** payloads, exact versions, callable signatures/configuration, fixture assertions and failure outcomes. A public example can guide a probe but cannot replace its result. Freeze/review this supplement only after all four same-conversation gates pass.

## Observed OpenCode 1.18.32 subset

The official release server and an ordinary TUI were attached to the same explicit `127.0.0.1:4096` endpoint and disposable directory. Basic auth was enabled. The version was `1.18.32`; no other version is covered. Source inspection of the matching local release and the live server yielded these shapes (opaque IDs and paths below are sanitized):

```json
{"id":"que_…","sessionID":"ses_…","questions":[{"question":"Which test letter?","header":"Test letter","options":[{"label":"A","description":"Choose A"},{"label":"B","description":"Choose B"}]}]}
```

`GET /question?directory=<encoded directory>` returned this pending record. `GET /global/event` emitted `{"directory":"<directory>","payload":{"type":"question.asked","properties":{"id":"que_…","sessionID":"ses_…","questions":[…],"tool":{"messageID":"msg_…","callID":"call_…"}}}}`. `POST /question/que_…/reply?directory=<encoded directory>` with `{"answers":[["B"]]}` returned JSON `true`, removed the pending record, and the original session produced `OPENCODE_QUESTION_TEST_B`. Answering a second question locally first made a later external reply return 404 `QuestionNotFoundError`; that session produced its local A continuation. A successful HTTP response supports `.accepted` for this observed request only after correlating the pending ID/session and the `true` result. Network loss after POST remains `.unconfirmed`, never an automatic retry.

This is enough to specify a prospective decoder and one reply encoder for OpenCode 1.18.32, but not to enable the adapter. The implementation must require an explicitly configured endpoint and directory for the instance hosting the user's existing chat, reject origin-changing redirects, reconcile pending requests on reconnect without extending deadlines, and prove cancellation and restart handling. The all-four release gate remains unchanged.

The branch now contains `OpenCodeQuestionPayload` and `OpenCodeQuestionSource` with fixture tests for the observed request/event, label-based reply, local-answer race and ambiguous HTTP result. The source requires an explicit loopback endpoint and directory and checks the server version. Its byte-level SSE reader preserves blank event separators; an in-memory HTTP test exercises Foundation's actual byte stream. On stream loss it invalidates phone controls and retains original request timing. Reconciliation can reissue only an identical, previously observed, still-pending request before its original deadline. Unknown, changed, expired or previously attempted requests cannot be reissued; an uncertain send cannot be retried. Releasing the source cancels its background connection. These are automated fixture results, not live reconnect or bot proof. It is **not wired into WatchRuntime**, has no settings UI and has not delivered a bot answer from Agrypnos. It is an isolated integration component, not OpenCode support in the running app.

Provider-independent Tasks 2–4 and 9 have local implementations, but Tasks 5–8 and the setup/optical gate in Task 10 remain incomplete. Preserve the approved 600-second policy, busy/unknown protection, original deadlines and no-skill requirement; none has been relaxed to work around these gaps.

OpenCode publishes a native resolution event before completing its reply handler. If that event arrives during Agrypnos's reserved POST, the source retains the in-flight response path and uses the POST outcome: JSON `true` with HTTP 200 is accepted, 404 is rejected, and a lost response remains unconfirmed. The event alone does not prove which responder won. A regression exercises both successful remote delivery and a local winner in that ordering.

## Documented Claude codec subset

`ClaudeQuestionPayload` now parses and encodes only the officially documented `PreToolUse` / `AskUserQuestion` shape. Input identity comes from `session_id` and `tool_use_id`; `tool_input.questions` supplies text, options and `multiSelect`. Output preserves the entire original `tool_input` and adds `answers` keyed by exact question text, then wraps it in `hookSpecificOutput` with `hookEventName: PreToolUse`, `permissionDecision: allow` and `updatedInput`. It cannot approve another tool or hook event, overwrite an existing answers field, submit a partial selection or silently truncate a frame. Duplicate question text and comma-containing multi-select labels are rejected because the documented answer map/join has no escape convention.

These are **documentation-based fixtures**, not observed Claude payloads. No Claude hook has been installed, no helper/socket or runtime adapter is enabled, and stdout encoding is not acceptance evidence. Original-hook timing, denial coexistence, cancellation and actual answer consumption remain unverified on the installed CLI/desktop surface. This isolated codec advances Task 5's data handling without closing its native gate. [Official hook reference](https://code.claude.com/docs/en/hooks#pretooluse).
