# Agrypnos V1 design

Overnight foundation. User was asleep; this records the choices.

## Approach

Split **decision** (`AgrypnosCore`, Linux-testable) from **execution** (AppKit / IOKit / `pmset` on macOS). One menu-bar extra. No Dock.

Lid-close keep-awake uses `pmset disablesleep` (kernel `SleepDisabled`). IOKit idle assertions do not survive lid close; they are not the lid story. Display sleep is `pmset displaysleepnow`, not brightness 0. Keyboard backlight is IORegistry. Brightness floor clamps restore brightness so 0% is never the sleep trick.

Agent watch is local heuristics for Cursor, Claude Code, and Codex: process list + session-file mtimes. Busy holds the watch. After a busy period, idle for 90s allows sleep.

## Layout

See `AGENTS.md` and `prd/v1-scope.md`. Files stay well under 600 lines.

## Not chosen

- Cloning Sleepless’s one-file AppKit app (god object, coffee cup). Layout rhythm (cards, timer, battery slider) is the reference; code and personality are original.
- Claiming watt numbers.
- Every agent provider.
- Sandboxed App Store build (process scan + IOKit + home-directory session files).
