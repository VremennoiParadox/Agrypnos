# Native question contracts — blocked supplement

Status: **not frozen, not approved for implementation**, 2026-09-29. This accompanies Task 1 of the [implementation plan](2026-09-29-native-agent-questions.md); see the [observed compatibility evidence](../../reviews/2026-09-29-native-question-compatibility.md).

There are no verified installed-version round-trip fixtures. Consequently no concrete production initializer, native decoder/reply encoder, acknowledgment classification or recovery algorithm is approved for Tasks 5–8. Inventing those interfaces would hide the unresolved dependency.

| Adapter | Contract needed before implementation | Current gap |
| --- | --- | --- |
| Claude | Exact hook input/output on the installed terminal and desktop surface; original session/tool-use identity; selected-answer encoding; fallback/630s hook behavior; coexistence with denials; consumption evidence | Documented candidate only; no native live probe. Hook stdout alone must not become an acceptance claim. |
| OpenCode | Explicit active instance endpoint/auth/directory; pinned version and route family; request/session identity; SSE event and pending-list schemas; reply/cancel acknowledgment; reconnect behavior | Active instance/version unidentified; dev schema is not a release fixture. |
| Codex desktop | Supported attachment to the original desktop server; initialization/subscription; original RPC ownership; request/resolved schemas; reply receipt versus actual acceptance; pending recovery | Default control socket absent; actual server has no observed named Unix endpoint. Another server's resumed history is insufficient. |
| Cursor desktop | Supported desktop event and answer interface; instance/conversation/generation/request IDs; full question/option fields; native cancellation/expiry; local-answer conflict resolution and recovery | Public hooks/ACP/SDK do not establish the required desktop response path; attempted UI inspection unavailable. |

For every row, the supplement must eventually include sanitized **observed** payloads, exact versions, callable signatures/configuration, fixture assertions and failure outcomes. A public example can guide a probe but cannot replace its result. Freeze/review this supplement only after all four same-conversation gates pass.

Provider-independent Tasks 2–4 and 9 have local implementations, but Tasks 5–8 and the setup/optical gate in Task 10 remain incomplete. Preserve the approved 600-second policy, busy/unknown protection, original deadlines and no-skill requirement; none has been relaxed to work around these gaps.
