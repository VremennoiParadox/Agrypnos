# Question notifications UI fixes

Date: **2026-10-06**. Branch `codex-question-sup`. Uncommitted. No `~/.codex` / `~/.claude` edits.

## 1. Scroll

Opening or closing **Question notifications** called `applySection(.notif)`, which always did `documentView?.scroll(.zero)` (again in the height-animation completion). That jumped the Notif popover to the top.

Same-section relayout now uses `PopoverScrollIntent.preserve`: keep the current document origin and clamp it. Section switches still `resetToTop`. Height motion is unchanged (0.25s ease-in-out; Reduce Motion skips it).

## 2. Two windows

Two read-only `BotGuideWindow` instances, same class, no third window, no controls.

| Button | Window title | Tabs |
| --- | --- | --- |
| Setup instructions… (first Notif card) | Bot setup | Telegram, Discord |
| Info-circle on OpenCode / Claude Code / Codex | Question setup | OpenCode, Claude Code, Codex, Cursor (opens on the clicked tool) |

Cursor still has no info button. Telegram/Discord are not on the tool window; the four tools are not on Bot setup.

The four-tab control is pinned to the 520pt window with `fillEqually`, so the leftover bar before OpenCode (six tabs overflowing) is gone.

## 3. Clipping — height bug, fixed

Not a new information architecture. The Codex card reused `claudeCardHeight` (188) with 4-line help overlapping the Enable button. The Cursor note used `loginCardHeight` (44) and measured wrap *before* `preferredMaxLayoutWidth`, so the sentence clipped.

After hug (conservative 36-column wrap):

| Slot | Height (pt) |
| --- | ---: |
| Codex alerts | **232** (help 6×16, then Enable, Disable, status) |
| Cursor note | **72** (3 lines) |
| Closed Notif content | 1054 |
| Open Notif content | 2088 |
| Popover clip | 720 (`maxVisibleHeight`) |

Closed Notif already needed scroll. Open Notif still fits the 720pt window and scrolls. Did not stop for a too-long page.

## 4. `/hooks` fact (copy unchanged)

This Mac’s ChatGPT.app bundle is **codex-cli 0.159.2**. `hooks` feature **stable true**.

- `codex help hooks` → `unrecognized subcommand 'hooks'`. There is **no** shell subcommand `codex hooks`.
- The binary *does* contain the interactive TUI slash command `/hooks` (`Use **/hooks** to view and manage lifecycle hooks.`, `tui/src/bottom_pane/hooks_browser_view.rs`, startup “Review hooks”).
- Official / prior note: `/hooks` is named for the **CLI TUI**. Docs do **not** describe a ChatGPT.app pane that reviews hooks the same way. This round did not find a desktop menu path.

Popover sentence left as-is: “Trust the new hook with `/hooks` in the Codex CLI.” It is true for an interactive CLI session and misleading if someone types `/hooks` in ChatGPT.app or `codex hooks` in a shell. Accurate replacement *if* we change it later: “In an interactive Codex CLI session, type `/hooks` and trust the new hook. There is no `codex hooks` shell command. ChatGPT.app is not documented to show that screen.” Not applied — no proven ChatGPT.app tap path.
