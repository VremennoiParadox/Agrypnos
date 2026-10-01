# OpenCode test milestone — branch review and disposition

Fresh, read-only review: `review_opencode_milestone`, GPT-6 Astra Extra High.
Range: original branch base `e615e00761ece7bb09f37c354d2957bbd25a6777`
through committed HEAD `af72b98`, plus the milestone working changes.
Scope: an OpenCode-only test build, with no push, merge or release.
The reviewer found no Critical issues, four Important issues and two Minor
issues. The executor addressed these in one regression/fix pass; no second
review was requested.

## Findings and fixes

1. **Successful replies exhausted capacity after 32 questions.** Fixed.
   Complete payloads are retired after capturing their final message edit.
   Bounded key-only replay protection replaces indefinitely retained payloads.
   `testMoreThan32SequentialAnswersDoNotExhaustCapacityOrReplay` failed at
   question 33 before the fix. It now completes 35 original native replies,
   including duplicate events after native resolution and reconciliation.

2. **Failed bot edits stranded stale controls.** Fixed.
   Telegram/Discord edits now process outcomes, respect `retry_after`, and
   retry at most three times within the original deadline. One worker per
   message coalesces newer renderings. Permanent/exhausted pending-edit
   failures close remote controls and return the question locally. Native
   answer submission remains once-only and is never retried.
   Initial/selection-edit failure regressions failed before recovery existed;
   both bots now pass those tests. Additional tests cover deadline exhaustion,
   permanent failures and native cancellation while an older edit is in flight.

3. **An unsupported pending question blocked the SSE connection.** Fixed.
   Listing identity/structure validation stays strict. Individual questions
   outside relay content/choice limits stay local and do not reject the whole
   listing. A supported known question retains its original deadline, and
   newly observed questions can still arrive. The mixed-listing regression
   reproduced the thrown error before the fix, then passed.

4. **A local answer during disconnection left an expired shutdown decision.**
   Fixed. A retained inactive request definitively absent at reconciliation
   reports resolution too. Source and actual-runtime regressions failed
   before this change and now clear the deferred unanswered-watch decision.

5. **Native cancellation left stale-looking buttons.** Fixed, regraded as
   Important for this test milestone: the user must be able to tell the
   question is unavailable. Authorization is invalidated immediately;
   captured message references receive a best-effort terminal edit. Verified
   network reconnect can bind fresh controls for the original request and
   deadline. Source replay memory remains bounded and rejects resolved-event
   replays. Setup changes still invalidate controls even when an old message
   cannot be edited after its credentials are removed.

6. **Discord interpreted local question Markdown.** Fixed, regraded as
   Important because formatting can change the apparent choices. Initial,
   edited and notice text escapes Markdown, disables mentions and suppresses
   embeds. If escaping exceeds 2,000 UTF-16 units, that Discord delivery stays
   local rather than truncating a choice. The formatting/limit regressions
   failed before this change and passed after it.
   Protocol reference: [Discord message resource](https://github.com/discord/discord-api-docs/blob/main/developers/resources/message.mdx).

## Scope decisions and verification limits

- Keep only OpenCode enabled, on the existing feature branch, because the
  human requested this staged test. All-four release remains gated. If the
  assumption is wrong, the wiring must change after live feedback.
- Sleep/app restart leave old pending questions local; original deadlines
  cannot be recovered safely after restart. Network-only reconnect preserves
  verified original deadlines. Cost: a pre-existing question needs a local
  answer after sleep/restart.
- Live OpenCode → bot → original-chat acceptance and service timing remain
  for the human test. Fixtures establish routing/identity, not real service
  acceptance. Cost: a live integration failure may still require a fix.
- AppKit optical behavior, typing/reveal interactions and section animations
  remain for the human test. Layout/build checks pass. Cost: UI interaction
  or clipping issues may still require a fix.
- Actual Mac sleep/lid/screen-lock/safety behavior remains unproved by these
  fixtures. Existing paths are preserved and runtime tests pass. Cost: a
  hardware-specific defect may still require a fix.
- No energy/wattage claim; no measurements were taken. Cost: energy overhead
  remains unknown.
- Claude/Cursor/Codex remain unavailable; full release readiness is not
  granted. Cost: the staged build cannot forward those providers' questions.
- Only OpenCode 1.18.32 is enabled. Other versions fail closed until validated.
  Cost: newer/older versions cannot use this build's question forwarding.
- Preserve the original all-provider plan's ledger because its provider gates
  remain incomplete. Local milestone completion does not close that plan.

No deferred review findings remain within this OpenCode test-build scope.
Live evidence is explicitly pending. See the milestone verification record
for the final suite/build results and the human smoke test.
