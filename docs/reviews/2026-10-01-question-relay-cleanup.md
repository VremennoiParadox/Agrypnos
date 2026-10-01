# Question relay branch cleanup

Authorized on 2026-10-01 after the human read the one-button setup plan and
asked to start the cleanup, then stop. Branch: `codex/agent-question-relay`;
starting HEAD `5b50efd177985143a5e0c668a0e28020c931a23d`.

## Changes

- Removed the unused `ClaudeQuestionPayload.swift` (88 lines) and
  `ClaudeQuestionPayloadTests.swift` (115 lines): **203 source/test lines**.
  Reference inspection found no app caller, package special registration,
  or Xcode membership. Only its eight documentation-fixture tests used it.
- Keep its contract investigation and original implementation in Git.
  Commit `499dcba` contains both files if Claude integration resumes; prove
  that provider's native contract before restoring implementation.
- Reconciled active contract/compatibility/milestone/review/design status:
  the HTTP OpenCode source and Notif setup are wired, and the user confirmed
  Telegram answers return to the original question. Historical probe/build
  evidence remains identified as historical; no new live proof is claimed.
- Updated the current handoff and saved one-button plan to reflect this
  authorized cleanup. The older untracked handoff remains a historical
  snapshot superseded by the current handoff.

## Preserved scope

The working HTTP source, manual connection UI/settings, bot credentials,
both bot relay paths, authorization, once-only submission, expiry/recovery,
watch/safety/lid policy and their tests remain intact. No extra deletion
candidate was identified by the reference check; the shared relay is used.

The proposed global plugin is still unimplemented and unproved. Removing
the current manual connection before that proof would remove working
behavior. Other providers and the full release remain gated; no branch
creation, global installation, push, merge or release is part of cleanup.
Existing untracked/ignored build artifacts and the all-provider progress
ledger are preserved.

## Verification

Baseline full Swift suite: **743 tests, zero failures**. The initial command
could not write the default compiler cache under the filesystem sandbox;
redirecting Swift/Clang module caches to `/private/tmp` and disabling the
SwiftPM manifest sandbox allowed the complete baseline to pass. Log:
`/private/tmp/agrypnos-cleanup-baseline.log`.

Post-cleanup full Swift suite: **735 tests, zero failures**. The eight removed
tests exercised only the shelved Claude codec. Log:
`/private/tmp/agrypnos-cleanup-tests.log`.

Fresh Debug and Release Xcode builds both **BUILD SUCCEEDED**, with
`codesign --verify --deep --strict` passing for each temporary app bundle.
Xcode needed reviewed access to its package/compiler caches outside the
workspace after the sandboxed attempts failed. Logs:
`/private/tmp/agrypnos-cleanup-debug.log` and
`/private/tmp/agrypnos-cleanup-release.log`. No test app was launched or
installed as part of this cleanup.

`git diff --check`, tracked source/doc **600-line** checks, changed Markdown
link/whitespace checks, absent-code-reference checks, and exact recovery
comparison against `499dcba` passed. Product/test changes are exactly the
two deletions; the ignored all-provider progress ledger remains present.

Fresh read-only review found no Critical or Important issue and no further
production deletion candidate in the focused relay pass. Two Minor notes
were addressed: launch/test chronology in the milestone verification and
completion of this evidence record. Manual HTTP removal, plugin work,
other-provider adapters and broad refactoring remain outside this cleanup.

No runtime behavior was added; deletion is checked against the existing
suite and app builds rather than adding tests that merely assert file absence.
